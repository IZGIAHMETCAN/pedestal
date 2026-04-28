use std::{
    collections::HashMap,
    time::{Duration, Instant},
};

use tokio::sync::RwLock;

use crate::models::PedestalResponse;

#[derive(Clone)]
struct CachedStationsEntry {
    expires_at: Instant,
    data: Vec<PedestalResponse>,
}

pub struct StationsCache {
    ttl: Duration,
    entries: RwLock<HashMap<String, CachedStationsEntry>>,
}

impl StationsCache {
    pub fn new(ttl: Duration) -> Self {
        Self {
            ttl,
            entries: RwLock::new(HashMap::new()),
        }
    }

    pub async fn get(&self, cache_key: &str) -> Option<Vec<PedestalResponse>> {
        let entries = self.entries.read().await;
        let entry = entries.get(cache_key)?;

        if Instant::now() >= entry.expires_at {
            return None;
        }

        Some(entry.data.clone())
    }

    pub async fn put(&self, cache_key: String, data: Vec<PedestalResponse>) {
        let mut entries = self.entries.write().await;
        entries.insert(
            cache_key,
            CachedStationsEntry {
                expires_at: Instant::now() + self.ttl,
                data,
            },
        );
    }

    pub async fn invalidate_all(&self) {
        self.entries.write().await.clear();
    }
}
