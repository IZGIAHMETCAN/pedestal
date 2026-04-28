use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use thiserror::Error;

use crate::models::ErrorResponse;

#[derive(Debug, Error)]
pub enum AppError {
    #[error("Geçersiz sunucu yanıtı")]
    InvalidResponse,

    #[error("Yetkisiz erişim. Token geçersiz veya süresi dolmuş.")]
    Unauthorized,

    #[error("Bağlantı hatası: {0}")]
    Network(#[from] reqwest::Error),

    #[error("Veri işleme hatası: {0}")]
    Decode(String),

    #[error("Sunucu hatası: {0}")]
    Server(String),

    #[error("Hatalı istek: {0}")]
    BadRequest(String),

    #[error("Rate limit aşıldı. Lütfen bekleyin.")]
    RateLimited,

    #[error("Upstream sunucu zaman aşımına uğradı.")]
    GatewayTimeout,

    #[error("Upstream sunucuya erişilemiyor: {0}")]
    UpstreamUnavailable(String),
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let status = match &self {
            AppError::Unauthorized => StatusCode::UNAUTHORIZED,
            AppError::BadRequest(_) => StatusCode::BAD_REQUEST,
            AppError::RateLimited => StatusCode::TOO_MANY_REQUESTS,
            AppError::Network(_) | AppError::UpstreamUnavailable(_) => StatusCode::BAD_GATEWAY,
            AppError::GatewayTimeout => StatusCode::GATEWAY_TIMEOUT,
            _ => StatusCode::INTERNAL_SERVER_ERROR,
        };

        let body = ErrorResponse {
            success: false,
            error: true,
            message: self.to_string(),
            code: status.as_u16(),
        };

        (status, Json(body)).into_response()
    }
}

pub type AppResult<T> = Result<T, AppError>;
