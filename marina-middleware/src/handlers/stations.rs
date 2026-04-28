use axum::{extract::State, Json};
use reqwest::Method;

use crate::{
    error::{AppError, AppResult},
    models::{
        BakiyeIadeRequest, ElektrikSuKontrolRequest, IstasyonDurumResponse,
        PedestalResponse, RawIstasyonBilgi, RawPedestalResponse, TuketimRaporuRequest,
    },
    state::AppState,
};

/// GET /stations/active
/// Kullanıcının kullandığı pedestalları döndürür
pub async fn get_kullanilan_pedestaller(
    State(state): State<AppState>,
    axum_extra::TypedHeader(auth): axum_extra::TypedHeader<headers::Authorization<headers::authorization::Bearer>>,
) -> AppResult<Json<Vec<PedestalResponse>>> {
    let token = auth.token();
    let raw: Vec<RawPedestalResponse> = state
        .backend
        .request_json(
            Method::GET,
            "api/Customer/GetKullanilanPedestal",
            Some(token),
            None::<&()>,
        )
        .await?;

    let result: Vec<PedestalResponse> = raw.into_iter().map(Into::into).collect();
    Ok(Json(result))
}

/// GET /stations/available
/// Boş istasyonları döndürür
pub async fn get_bos_istasyonlar(
    State(state): State<AppState>,
    axum_extra::TypedHeader(auth): axum_extra::TypedHeader<headers::Authorization<headers::authorization::Bearer>>,
) -> AppResult<Json<Vec<PedestalResponse>>> {
    let token = auth.token();
    let cache_key = format!("available-stations:{token}");

    if let Some(cached) = state.stations_cache.get(&cache_key).await {
        return Ok(Json(cached));
    }

    let raw: Vec<RawPedestalResponse> = state
        .backend
        .request_json(
            Method::GET,
            "api/Customer/GetBosIstasyonlar",
            Some(token),
            None::<&()>,
        )
        .await?;

    let result: Vec<PedestalResponse> = raw.into_iter().map(Into::into).collect();
    state.stations_cache.put(cache_key, result.clone()).await;

    Ok(Json(result))
}

/// POST /stations/status
/// İstasyon son durumunu döndürür
pub async fn get_istasyon_durum(
    State(state): State<AppState>,
    axum_extra::TypedHeader(auth): axum_extra::TypedHeader<headers::Authorization<headers::authorization::Bearer>>,
    Json(istasyon_id): Json<i64>, // Swift ham i64 (JSON number) gönderiyor
) -> AppResult<Json<IstasyonDurumResponse>> {
    let token = auth.token();
    let raw: RawIstasyonBilgi = state
        .backend
        .request_json(
            Method::POST,
            "api/Customer/PostIstasyonSonKayit",
            Some(token),
            Some(&istasyon_id),
        )
        .await?;

    Ok(Json(IstasyonDurumResponse::from(raw)))
}

/// POST /stations/control
/// Su veya elektriği açar/kapatır
pub async fn post_elektrik_su_kontrol(
    State(state): State<AppState>,
    axum_extra::TypedHeader(auth): axum_extra::TypedHeader<headers::Authorization<headers::authorization::Bearer>>,
    Json(body): Json<ElektrikSuKontrolRequest>,
) -> AppResult<String> {
    if body.islem != 0 && body.islem != 1 {
        return Err(AppError::BadRequest("islem 0 veya 1 olmalı".into()));
    }

    let token = auth.token();
    state
        .backend
        .request_tamam(
            Method::POST,
            "api/Customer/PostElektrikSuAc",
            Some(token),
            Some(&body),
        )
        .await?;

    state.stations_cache.invalidate_all().await;

    Ok("Tamam".into())
}

/// POST /stations/refund
/// İstasyon bakiyesini iade alır
pub async fn post_bakiye_iade(
    State(state): State<AppState>,
    axum_extra::TypedHeader(auth): axum_extra::TypedHeader<headers::Authorization<headers::authorization::Bearer>>,
    Json(body): Json<BakiyeIadeRequest>,
) -> AppResult<String> {
    let token = auth.token();
    state
        .backend
        .request_tamam(
            Method::POST,
            "api/Customer/PostBakiyeIade",
            Some(token),
            Some(&body),
        )
        .await?;

    state.stations_cache.invalidate_all().await;

    Ok("Tamam".into())
}

/// POST /stations/consumption
/// Kullanıcı tüketim raporunu döndürür
pub async fn get_tuketim_raporu(
    State(state): State<AppState>,
    axum_extra::TypedHeader(auth): axum_extra::TypedHeader<headers::Authorization<headers::authorization::Bearer>>,
    Json(body): Json<TuketimRaporuRequest>,
) -> AppResult<Json<Vec<IstasyonDurumResponse>>> {
    let token = auth.token();
    let raw: Vec<RawIstasyonBilgi> = state
        .backend
        .request_json(
            Method::GET,
            "api/Customer/GetKullaniciTuketimler",
            Some(token),
            Some(&body),
        )
        .await?;

    let result: Vec<IstasyonDurumResponse> = raw.into_iter().map(Into::into).collect();
    Ok(Json(result))
}
