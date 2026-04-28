use axum::{extract::State, Json};
use reqwest::Method;

use crate::{
    error::AppResult,
    models::{KartResponse, OkResponse, RawAboneKart},
    state::AppState,
};

/// GET /cards
/// Kullanıcının kartlarını döndürür (temizlenmiş format)
pub async fn get_kartlar(
    State(state): State<AppState>,
    axum_extra::TypedHeader(auth): axum_extra::TypedHeader<headers::Authorization<headers::authorization::Bearer>>,
) -> AppResult<Json<Vec<KartResponse>>> {
    let token = auth.token();
    let raw: Vec<RawAboneKart> = state
        .backend
        .request_json(
            Method::GET,
            "api/Customer/GetAboneKartlari",
            Some(token),
            None::<&()>,
        )
        .await?;

    let kartlar: Vec<KartResponse> = raw.into_iter().map(Into::into).collect();
    Ok(Json(kartlar))
}

/// POST /cards/virtual
/// Sanal kart oluşturur
pub async fn post_sanal_kart(
    State(state): State<AppState>,
    axum_extra::TypedHeader(auth): axum_extra::TypedHeader<headers::Authorization<headers::authorization::Bearer>>,
) -> AppResult<Json<OkResponse>> {
    let token = auth.token();
    state
        .backend
        .request_string(
            Method::GET,
            "api/Customer/GetSanalKartOlustur",
            Some(token),
            None::<&()>,
        )
        .await?;

    Ok(Json(OkResponse::ok()))
}
