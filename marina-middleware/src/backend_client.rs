use std::time::Duration;

use reqwest::{Client, Method, StatusCode};
use serde::de::DeserializeOwned;
use serde::Serialize;

use crate::error::{AppError, AppResult};

/// Backend ile iletişimi sağlayan istemci
#[derive(Clone)]
pub struct BackendClient {
    pub client: Client,
    pub base_url: String,
}

impl BackendClient {
    pub fn new(base_url: String) -> Self {
        let client = Client::builder()
            .connect_timeout(Duration::from_secs(5))
            .timeout(Duration::from_secs(30))
            .pool_idle_timeout(Duration::from_secs(90))
            .pool_max_idle_per_host(20)
            .tcp_keepalive(Duration::from_secs(60))
            .user_agent("marina-middleware/0.1")
            .build()
            .expect("HTTP client oluşturulamadı");

        Self { client, base_url }
    }

    /// JSON body ile istek at, JSON response bekle
    pub async fn request_json<B, R>(
        &self,
        method: Method,
        endpoint: &str,
        token: Option<&str>,
        body: Option<&B>,
    ) -> AppResult<R>
    where
        B: Serialize,
        R: DeserializeOwned,
    {
        let url = format!("{}/{}", self.base_url, endpoint);
        let mut req = self.client.request(method, &url);

        req = req.header("Content-Type", "application/json");

        if let Some(t) = token {
            req = req.header("Authorization", format!("Bearer {}", t));
        }

        if let Some(b) = body {
            req = req.json(b);
        }

        let resp = req.send().await.map_err(AppError::Network)?;
        let status = resp.status();

        if status == StatusCode::UNAUTHORIZED {
            return Err(AppError::Unauthorized);
        }

        if !status.is_success() {
            let msg = resp
                .text()
                .await
                .unwrap_or_else(|_| format!("HTTP {}", status.as_u16()));
            return Err(AppError::Server(msg));
        }

        let data = resp
            .json::<R>()
            .await
            .map_err(|e| AppError::Decode(e.to_string()))?;
        Ok(data)
    }

    /// Düz string response bekle (Backend "Tamam" gibi string döndürüyor)
    pub async fn request_string<B>(
        &self,
        method: Method,
        endpoint: &str,
        token: Option<&str>,
        body: Option<&B>,
    ) -> AppResult<String>
    where
        B: Serialize,
    {
        let url = format!("{}/{}", self.base_url, endpoint);
        let mut req = self.client.request(method, &url);

        req = req.header("Content-Type", "application/json");

        if let Some(t) = token {
            req = req.header("Authorization", format!("Bearer {}", t));
        }

        if let Some(b) = body {
            req = req.json(b);
        }

        let resp = req.send().await.map_err(AppError::Network)?;
        let status = resp.status();

        if status == StatusCode::UNAUTHORIZED {
            return Err(AppError::Unauthorized);
        }

        if !status.is_success() {
            return Err(AppError::Server(format!("HTTP {}", status.as_u16())));
        }

        let text = resp.text().await.map_err(AppError::Network)?;
        Ok(text.trim().trim_matches('"').to_string())
    }

    /// "Tamam" kontrolü yapan helper
    pub async fn request_tamam<B>(
        &self,
        method: Method,
        endpoint: &str,
        token: Option<&str>,
        body: Option<&B>,
    ) -> AppResult<()>
    where
        B: Serialize,
    {
        let text = self.request_string(method, endpoint, token, body).await?;

        if text == "Tamam" || text == "true" {
            Ok(())
        } else {
            Err(AppError::Server(text))
        }
    }
}
