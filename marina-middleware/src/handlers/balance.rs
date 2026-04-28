use axum::{extract::State, Json};
use reqwest::Method;

use crate::{
    error::AppResult,
    models::{
        BakiyeHareketleriRequest, BakiyeHareketResponse, BakiyeIstasyonRequest,
        BakiyeYukleRequest, OkResponse, RawBakiyeHareket,
    },
    state::AppState,
};

/// GET /balance
/// Kullanıcının mevcut bakiyesini döndürür
pub async fn get_balance(
    State(state): State<AppState>,
    axum_extra::TypedHeader(auth): axum_extra::TypedHeader<headers::Authorization<headers::authorization::Bearer>>,
) -> AppResult<Json<f64>> {
    let token = auth.token();
    let balance: f64 = state
        .backend
        .request_json(Method::GET, "api/Customer/GetMevcutBakiye", Some(token), None::<&()>)
        .await?;

    Ok(Json(balance))
}

/// POST /balance/load
/// Kullanıcı hesabına bakiye yükler
pub async fn post_bakiye_yukle(
    State(state): State<AppState>,
    axum_extra::TypedHeader(auth): axum_extra::TypedHeader<headers::Authorization<headers::authorization::Bearer>>,
    Json(body): Json<BakiyeYukleRequest>,
) -> AppResult<Json<OkResponse>> {
    let token = auth.token();
    state
        .backend
        .request_tamam(
            Method::POST,
            "api/Customer/PostBakiyeYukle",
            Some(token),
            Some(&body),
        )
        .await?;

    Ok(Json(OkResponse::ok()))
}

/// POST /balance/station
/// İstasyona bakiye yükler
pub async fn post_bakiye_istasyon(
    State(state): State<AppState>,
    axum_extra::TypedHeader(auth): axum_extra::TypedHeader<headers::Authorization<headers::authorization::Bearer>>,
    Json(body): Json<BakiyeIstasyonRequest>,
) -> AppResult<String> {
    let token = auth.token();
    state
        .backend
        .request_tamam(
            Method::POST,
            "api/Customer/PostBakiyeIstasyon",
            Some(token),
            Some(&body),
        )
        .await?;

    state.stations_cache.invalidate_all().await;

    Ok("Tamam".into())
}

/// GET /balance/transactions
/// Bakiye hareketlerini döndürür (tarih aralığı ile)
pub async fn get_bakiye_hareketleri(
    State(state): State<AppState>,
    axum_extra::TypedHeader(auth): axum_extra::TypedHeader<headers::Authorization<headers::authorization::Bearer>>,
    Json(body): Json<BakiyeHareketleriRequest>,
) -> AppResult<Json<Vec<BakiyeHareketResponse>>> {
    let token = auth.token();
    let raw: Vec<RawBakiyeHareket> = state
        .backend
        .request_json(
            Method::GET,
            "api/Customer/GetBakiyeListDate",
            Some(token),
            Some(&body),
        )
        .await?;

    let transformed: Vec<BakiyeHareketResponse> = raw.into_iter().map(Into::into).collect();
    Ok(Json(transformed))
}
