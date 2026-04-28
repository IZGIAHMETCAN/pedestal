mod backend_client;
mod cache;
mod error;
mod handlers;
mod middleware;
mod models;
mod rate_limiter;
mod state;

use std::{net::SocketAddr, sync::Arc, time::Duration};

use axum::{
    error_handling::HandleErrorLayer,
    middleware as axum_middleware,
    routing::{get, post},
    Extension, Router,
};
use tower::{BoxError, ServiceBuilder, timeout::TimeoutLayer};
use tower_http::{
    cors::{Any, CorsLayer},
    limit::RequestBodyLimitLayer,
    trace::TraceLayer,
};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

use handlers::{auth, balance, cards, stations, users};
use state::AppState;

#[tokio::main]
async fn main() {
    dotenv::dotenv().ok();

    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "marina_middleware=info,tower_http=info".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    let backend_url =
        std::env::var("BACKEND_URL").unwrap_or_else(|_| "http://localhost:5000".to_string());
    let request_timeout_secs = std::env::var("REQUEST_TIMEOUT_SECS")
        .ok()
        .and_then(|value| value.parse::<u64>().ok())
        .unwrap_or(30);
    let stations_cache_ttl_secs = std::env::var("STATIONS_CACHE_TTL_SECS")
        .ok()
        .and_then(|value| value.parse::<u64>().ok())
        .unwrap_or(15);

    tracing::info!("Backend URL: {}", backend_url);
    tracing::info!("Request timeout: {}s", request_timeout_secs);
    tracing::info!("Stations cache TTL: {}s", stations_cache_ttl_secs);

    let state = AppState::new(backend_url, Duration::from_secs(stations_cache_ttl_secs));
    let rate_limiter = Arc::clone(&state.rate_limiter);

    let app = Router::new()
        .route("/api/Token/Authenticate", post(auth::login))
        .route("/api/Customer/GetMevcutBakiye", get(balance::get_balance))
        .route("/api/Customer/PostBakiyeYukle", post(balance::post_bakiye_yukle))
        .route("/api/Customer/GetBakiyeListDate", get(balance::get_bakiye_hareketleri))
        .route("/api/Customer/GetAboneKartlari", get(cards::get_kartlar))
        .route("/api/Customer/GetSanalKartOlustur", get(cards::post_sanal_kart))
        .route("/api/Customer/GetKullanilanPedestal", get(stations::get_kullanilan_pedestaller))
        .route("/api/Customer/GetBosIstasyonlar", get(stations::get_bos_istasyonlar))
        .route("/api/Customer/PostIstasyonSonKayit", post(stations::get_istasyon_durum))
        .route("/api/Customer/PostBakiyeIstasyon", post(balance::post_bakiye_istasyon))
        .route("/api/Customer/PostElektrikSuAc", post(stations::post_elektrik_su_kontrol))
        .route("/api/Customer/PostBakiyeIade", post(stations::post_bakiye_iade))
        .route("/api/Customer/GetKullaniciTuketimler", get(stations::get_tuketim_raporu))
        .route("/api/Customer/PostMailControl", post(users::post_mail_kontrol))
        .route("/api/Customer/PostTCNumara", post(users::post_tc_kontrol))
        .route("/api/Customer/GetMailGonder", post(users::post_mail_gonder))
        .route("/auth/login", post(auth::login))
        .route("/auth/logout", post(auth::logout))
        .route("/balance", get(balance::get_balance))
        .route("/balance/load", post(balance::post_bakiye_yukle))
        .route("/balance/station", post(balance::post_bakiye_istasyon))
        .route("/balance/transactions", get(balance::get_bakiye_hareketleri))
        .route("/cards", get(cards::get_kartlar))
        .route("/cards/virtual", get(cards::post_sanal_kart))
        .route("/stations/active", get(stations::get_kullanilan_pedestaller))
        .route("/stations/available", get(stations::get_bos_istasyonlar))
        .route("/stations/status", post(stations::get_istasyon_durum))
        .route("/stations/control", post(stations::post_elektrik_su_kontrol))
        .route("/stations/refund", post(stations::post_bakiye_iade))
        .route("/stations/consumption", get(stations::get_tuketim_raporu))
        .route("/user/check-email", post(users::post_mail_kontrol))
        .route("/user/check-tc", post(users::post_tc_kontrol))
        .route("/user/send-mail", post(users::post_mail_gonder))
        .layer(axum_middleware::from_fn(middleware::rate_limit_middleware))
        .layer(Extension(rate_limiter))
        .layer(TraceLayer::new_for_http())
        .layer(
            ServiceBuilder::new()
                .layer(HandleErrorLayer::new(|error: BoxError| async move {
                    if error.is::<tower::timeout::error::Elapsed>() {
                        error::AppError::GatewayTimeout
                    } else {
                        error::AppError::UpstreamUnavailable(error.to_string())
                    }
                }))
                .layer(TimeoutLayer::new(Duration::from_secs(request_timeout_secs))),
        )
        .layer(
            CorsLayer::new()
                .allow_origin(Any)
                .allow_methods(Any)
                .allow_headers(Any),
        )
        .layer(RequestBodyLimitLayer::new(1024 * 1024))
        .with_state(state);

    let port: u16 = std::env::var("PORT")
        .unwrap_or_else(|_| "3000".to_string())
        .parse()
        .unwrap_or(3000);

    let addr = SocketAddr::from(([0, 0, 0, 0], port));
    tracing::info!("Marina middleware başlatıldı: http://{}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(
        listener,
        app.into_make_service_with_connect_info::<SocketAddr>(),
    )
    .await
    .unwrap();
}
