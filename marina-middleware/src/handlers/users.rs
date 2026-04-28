use axum::{extract::State, Json};
use reqwest::Method;
use serde::{Deserialize, Serialize};

use crate::{
    error::AppResult,
    models::{MesajRequest, OkResponse},
    state::AppState,
};

#[derive(Deserialize)]
pub struct EmailCheckBody {
    pub email: String,
}

#[derive(Deserialize)]
pub struct TcCheckBody {
    pub tc_no: String,
}

#[derive(Serialize)]
pub struct BoolResponse {
    pub exists: bool,
}

/// POST /user/check-email
/// Email'in kayıtlı olup olmadığını kontrol eder
pub async fn post_mail_kontrol(
    State(state): State<AppState>,
    Json(body): Json<MesajRequest>,
) -> AppResult<Json<BoolResponse>> {
    let text = state
        .backend
        .request_string(Method::POST, "api/Customer/PostMailControl", None, Some(&body))
        .await?;

    Ok(Json(BoolResponse { exists: text == "true" }))
}

/// POST /user/check-tc
/// TC kimlik numarasının kayıtlı olup olmadığını kontrol eder
pub async fn post_tc_kontrol(
    State(state): State<AppState>,
    Json(body): Json<MesajRequest>,
) -> AppResult<Json<BoolResponse>> {
    let text = state
        .backend
        .request_string(Method::POST, "api/Customer/PostTCNumara", None, Some(&body))
        .await?;

    Ok(Json(BoolResponse { exists: text == "true" }))
}

#[derive(Deserialize)]
pub struct MailGonderBody {
    pub mesaj: String,
}

/// POST /user/send-mail
/// Email gönderir
pub async fn post_mail_gonder(
    State(state): State<AppState>,
    axum_extra::TypedHeader(auth): axum_extra::TypedHeader<headers::Authorization<headers::authorization::Bearer>>,
    Json(body): Json<MesajRequest>, // Swift MesajRequest gönderiyor
) -> AppResult<Json<OkResponse>> {
    let token = auth.token();
    state
        .backend
        .request_string(Method::POST, "api/Customer/GetMailGonder", Some(token), Some(&body))
        .await?;

    Ok(Json(OkResponse::ok()))
}
