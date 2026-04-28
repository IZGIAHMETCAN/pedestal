use std::{sync::Arc, time::Duration};

use crate::{
    backend_client::BackendClient,
    cache::StationsCache,
    rate_limiter::RateLimiter,
};

/// Tüm handler'lar arasında paylaşılan uygulama durumu
#[derive(Clone)]
pub struct AppState {
    pub backend: Arc<BackendClient>,
    pub rate_limiter: Arc<RateLimiter>,
    pub stations_cache: Arc<StationsCache>,
}

impl AppState {
    pub fn new(base_url: String, stations_cache_ttl: Duration) -> Self {
        Self {
            backend: Arc::new(BackendClient::new(base_url)),
            // Dakikada 60 istek / IP
            rate_limiter: Arc::new(RateLimiter::new(60, Duration::from_secs(60))),
            stations_cache: Arc::new(StationsCache::new(stations_cache_ttl)),
        }
    }
}
