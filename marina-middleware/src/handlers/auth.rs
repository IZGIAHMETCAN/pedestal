use axum::{extract::State, Json};
use reqwest::Method;

use crate::{
    error::{AppError, AppResult},
    models::{LoginRequest, OkResponse, RawTokenResponse, TokenResponse},
    state::AppState,
};

/// POST /auth/login
/// Mobile'dan email+password alır, backend token'ı dönüştürüp gönderir
pub async fn login(
    State(state): State<AppState>,
    Json(body): Json<LoginRequest>,
) -> AppResult<Json<TokenResponse>> {
    if body.email.is_empty() || body.password.is_empty() {
        return Err(AppError::BadRequest("Email ve şifre zorunlu".into()));
    }

    let raw: RawTokenResponse = state
        .backend
        .request_json(
            Method::POST,
            "api/Token/Authenticate",
            None,
            Some(&body),
        )
        .await?;

    Ok(Json(TokenResponse::from(raw)))
}

/// POST /auth/logout
/// Sadece mobile tarafında token temizlenir; backend logout endpoint'i yok
pub async fn logout() -> Json<OkResponse> {
    Json(OkResponse::ok())
}
