use std::{
    collections::HashMap,
    net::IpAddr,
    sync::{Arc, Mutex},
    time::{Duration, Instant},
};

/// Basit token bucket rate limiter (IP başına)
#[derive(Clone)]
pub struct RateLimiter {
    inner: Arc<Mutex<HashMap<IpAddr, BucketState>>>,
    /// Pencere süresi
    window: Duration,
    /// Pencere başına maksimum istek
    max_requests: u32,
}

struct BucketState {
    count: u32,
    window_start: Instant,
}

impl RateLimiter {
    pub fn new(max_requests: u32, window: Duration) -> Self {
        Self {
            inner: Arc::new(Mutex::new(HashMap::new())),
            window,
            max_requests,
        }
    }

    /// IP'nin istek yapmasına izin var mı?
    pub fn check(&self, ip: IpAddr) -> bool {
        let mut map = self.inner.lock().unwrap();
        let now = Instant::now();

        let entry = map.entry(ip).or_insert(BucketState {
            count: 0,
            window_start: now,
        });

        // Pencere süresi geçtiyse sıfırla
        if now.duration_since(entry.window_start) >= self.window {
            entry.count = 0;
            entry.window_start = now;
        }

        if entry.count >= self.max_requests {
            return false;
        }

        entry.count += 1;
        true
    }
}
