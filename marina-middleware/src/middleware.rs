use axum::{
    body::Body,
    extract::ConnectInfo,
    http::{Request, StatusCode},
    middleware::Next,
    response::{IntoResponse, Response},
    Json,
};
use serde_json::json;
use std::{net::SocketAddr, sync::Arc};

use crate::rate_limiter::RateLimiter;

pub async fn rate_limit_middleware(
    ConnectInfo(addr): ConnectInfo<SocketAddr>,
    axum::extract::Extension(limiter): axum::extract::Extension<Arc<RateLimiter>>,
    req: Request<Body>,
    next: Next,
) -> Response {
    if !limiter.check(addr.ip()) {
        let body = json!({
            "success": false,
            "error": "Rate limit aşıldı. Lütfen bekleyin.",
            "code": 429
        });
        return (StatusCode::TOO_MANY_REQUESTS, Json(body)).into_response();
    }

    next.run(req).await
}
