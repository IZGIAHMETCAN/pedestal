use serde::{Deserialize, Serialize};

// ─────────────────────────────────────────────
// REQUEST MODELS (Backend'e giden)
// ─────────────────────────────────────────────

#[derive(Debug, Serialize, Deserialize)]
pub struct LoginRequest {
    pub email: String,
    pub password: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct BakiyeYukleRequest {
    #[serde(rename = "kartId")]
    pub kart_id: Option<String>,
    pub tutar: f64,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct BakiyeIstasyonRequest {
    #[serde(rename = "istasyonId")]
    pub istasyon_id: i64,
    #[serde(rename = "kartId")]
    pub kart_id: String,
    pub amount: f64,
    pub currency: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ElektrikSuKontrolRequest {
    #[serde(rename = "istasyonId")]
    pub istasyon_id: i64,
    #[serde(rename = "kartId")]
    pub kart_id: String,
    /// true: Su, false: Elektrik
    #[serde(rename = "suElektrik")]
    pub su_elektrik: bool,
    /// 1: Aç, 0: Kapat
    pub islem: i32,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct BakiyeIadeRequest {
    #[serde(rename = "istasyonId")]
    pub istasyon_id: i64,
    #[serde(rename = "kartId")]
    pub kart_id: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct BakiyeHareketleriRequest {
    #[serde(rename = "kartId")]
    pub kart_id: String,
    #[serde(rename = "firstDate")]
    pub first_date: String,
    #[serde(rename = "secondDate")]
    pub second_date: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct TuketimRaporuRequest {
    #[serde(rename = "KartID")]
    pub kart_id: String,
    #[serde(rename = "FirstDate")]
    pub first_date: String,
    #[serde(rename = "SecondDate")]
    pub second_date: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct MesajRequest {
    #[serde(rename = "mesajGelen")]
    pub mesaj_gelen: String,
}

// ─────────────────────────────────────────────
// BACKEND RAW RESPONSE MODELS (Backend'den gelen ham hali)
// ─────────────────────────────────────────────

/// Backend'den gelen ham token response
#[derive(Debug, Deserialize)]
pub struct RawTokenResponse {
    #[serde(rename = "Token")]
    pub token: String,
    #[serde(rename = "Email")]
    pub email: String,
    #[serde(rename = "UserFullName")]
    pub user_full_name: Option<String>,
    #[serde(rename = "UserId")]
    pub user_id: Option<i64>,
    #[serde(rename = "WebApiUrl")]
    pub web_api_url: Option<String>,
    #[serde(rename = "UserProfileImageUrl")]
    pub user_profile_image_url: Option<String>,
}

/// Backend'den gelen ham kart verisi
#[derive(Debug, Deserialize)]
pub struct RawAboneKart {
    #[serde(rename = "RecId")]
    pub rec_id: i64,
    #[serde(rename = "MarinaNo")]
    pub marina_no: i64,
    #[serde(rename = "AboneNo")]
    pub abone_no: String,
    #[serde(rename = "KartId")]
    pub kart_id: String,
    #[serde(rename = "KartSahibi")]
    pub kart_sahibi: String,
    // silTarih, silKim: mobile'a gönderilmiyor (temizlik)
}

/// Backend'den gelen ham pedestal verisi
#[derive(Debug, Deserialize)]
pub struct RawPedestalResponse {
    #[serde(rename = "RecId")]
    pub rec_id: i64,
    #[serde(rename = "MarinaNo")]
    pub marina_no: i64,
    #[serde(rename = "PortAdi")]
    pub port_adi: String,
    #[serde(rename = "IstasyonAdi")]
    pub istasyon_adi: String,
    #[serde(rename = "IstasyonId")]
    pub istasyon_id: i64,
    #[serde(rename = "PrizNo")]
    pub priz_no: i64,
    #[serde(rename = "Aciklama")]
    pub aciklama: Option<String>,
    #[serde(rename = "Aktif")]
    pub aktif: bool,
    // silTarih, silKim: mobile'a gönderilmiyor
}

/// Backend'den gelen ham istasyon bilgisi
#[derive(Debug, Deserialize)]
pub struct RawIstasyonBilgi {
    #[serde(rename = "RecId")]
    pub rec_id: i64,
    #[serde(rename = "Tarih")]
    pub tarih: String,
    #[serde(rename = "MarinaNo")]
    pub marina_no: i64,
    #[serde(rename = "IstasyonId")]
    pub istasyon_id: i64,
    #[serde(rename = "AboneNo")]
    pub abone_no: Option<String>,
    #[serde(rename = "KartId")]
    pub kart_id: Option<String>,
    #[serde(rename = "Bakiye")]
    pub bakiye: Option<f64>,
    #[serde(rename = "BakiyeKart")]
    pub bakiye_kart: Option<f64>,
    #[serde(rename = "Su")]
    pub su: Option<bool>,
    #[serde(rename = "Elektrik")]
    pub elektrik: Option<bool>,
    #[serde(rename = "ElektrikTuketim")]
    pub elektrik_tuketim: Option<f64>,
    #[serde(rename = "LitreTuketim")]
    pub litre_tuketim: Option<f64>,
    #[serde(rename = "Kapali")]
    pub kapali: Option<bool>,
    #[serde(rename = "Yil")]
    pub yil: Option<i32>,
}

#[derive(Debug, Deserialize)]
pub struct RawBakiyeHareket {
    #[serde(rename = "MarinaNo")]
    pub marina_no: Option<i64>,
    #[serde(rename = "AboneNo")]
    pub abone_no: Option<String>,
    #[serde(rename = "IstasyonId")]
    pub istasyon_id: Option<i64>,
    #[serde(rename = "Tarih")]
    pub tarih: Option<String>,
    #[serde(rename = "Tutar")]
    pub tutar: Option<f64>,
    #[serde(rename = "TutarIade")]
    pub tutar_iade: Option<f64>,
    #[serde(rename = "Bakiye")]
    pub bakiye: Option<f64>,
    #[serde(rename = "ParaBirimi")]
    pub para_birimi: String,
    #[serde(rename = "KayitKim")]
    pub kayit_kim: String,
    #[serde(rename = "KartAdSoyad")]
    pub kart_ad_soyad: String,
    #[serde(rename = "KartId")]
    pub kart_id: String,
    #[serde(rename = "KayitTipi")]
    pub kayit_tipi: Option<i32>,
    #[serde(rename = "Yil")]
    pub yil: Option<i32>,
}

// ─────────────────────────────────────────────
// MOBILE RESPONSE MODELS (Middleware'den mobile'a giden — Swift CodingKeys ile uyumlu)
// ─────────────────────────────────────────────

/// Mobile'a gönderilen token response
#[derive(Debug, Serialize)]
#[serde(rename_all = "PascalCase")]
pub struct TokenResponse {
    pub token: String,
    pub email: String,
    pub user_full_name: Option<String>,
    pub user_id: Option<i64>,
    pub web_api_url: Option<String>,
    pub user_profile_image_url: Option<String>,
}

impl From<RawTokenResponse> for TokenResponse {
    fn from(r: RawTokenResponse) -> Self {
        Self {
            token: r.token,
            email: r.email,
            user_full_name: r.user_full_name,
            user_id: r.user_id,
            web_api_url: r.web_api_url,
            user_profile_image_url: r.user_profile_image_url,
        }
    }
}

/// Mobile'a gönderilen kart verisi
#[derive(Debug, Serialize)]
#[serde(rename_all = "PascalCase")]
pub struct KartResponse {
    pub rec_id: i64,
    pub marina_no: i64,
    pub abone_no: String,
    pub kart_id: String,
    pub kart_sahibi: String,
}

impl From<RawAboneKart> for KartResponse {
    fn from(r: RawAboneKart) -> Self {
        Self {
            rec_id: r.rec_id,
            marina_no: r.marina_no,
            abone_no: r.abone_no,
            kart_id: r.kart_id,
            kart_sahibi: r.kart_sahibi,
        }
    }
}

/// Mobile'a gönderilen pedestal verisi
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "PascalCase")]
pub struct PedestalResponse {
    pub rec_id: i64,
    pub marina_no: i64,
    pub port_adi: String,
    pub istasyon_adi: String,
    pub istasyon_id: i64,
    pub priz_no: i64,
    pub aciklama: Option<String>,
    pub aktif: bool,
}

impl From<RawPedestalResponse> for PedestalResponse {
    fn from(r: RawPedestalResponse) -> Self {
        Self {
            rec_id: r.rec_id,
            marina_no: r.marina_no,
            port_adi: r.port_adi,
            istasyon_adi: r.istasyon_adi,
            istasyon_id: r.istasyon_id,
            priz_no: r.priz_no,
            aciklama: r.aciklama,
            aktif: r.aktif,
        }
    }
}

/// Mobile'a gönderilen istasyon durumu (IstasyonBilgiResponse)
#[derive(Debug, Serialize)]
#[serde(rename_all = "PascalCase")]
pub struct IstasyonDurumResponse {
    pub rec_id: i64,
    pub tarih: String,
    pub marina_no: i64,
    pub istasyon_id: i64,
    pub abone_no: Option<String>,
    pub kart_id: Option<String>,
    pub bakiye: Option<f64>,
    pub bakiye_kart: Option<f64>,
    pub su: Option<bool>,
    pub elektrik: Option<bool>,
    pub elektrik_tuketim: Option<f64>,
    pub litre_tuketim: Option<f64>,
    pub kapali: Option<bool>,
    pub yil: Option<i32>,
}

impl From<RawIstasyonBilgi> for IstasyonDurumResponse {
    fn from(r: RawIstasyonBilgi) -> Self {
        Self {
            rec_id: r.rec_id,
            tarih: r.tarih,
            marina_no: r.marina_no,
            istasyon_id: r.istasyon_id,
            abone_no: r.abone_no,
            kart_id: r.kart_id,
            bakiye: r.bakiye,
            bakiye_kart: r.bakiye_kart,
            su: r.su,
            elektrik: r.elektrik,
            elektrik_tuketim: r.elektrik_tuketim,
            litre_tuketim: r.litre_tuketim,
            kapali: r.kapali,
            yil: r.yil,
        }
    }
}

/// Mobile'a gönderilen bakiye hareketi
#[derive(Debug, Serialize)]
#[serde(rename_all = "PascalCase")]
pub struct BakiyeHareketResponse {
    pub marina_no: Option<i64>,
    pub abone_no: Option<String>,
    pub istasyon_id: Option<i64>,
    pub tarih: Option<String>,
    pub tutar: Option<f64>,
    pub tutar_iade: Option<f64>,
    pub bakiye: Option<f64>,
    pub para_birimi: String,
    pub kayit_kim: String,
    pub kart_ad_soyad: String,
    pub kart_id: String,
    pub kayit_tipi: Option<i32>,
    pub yil: Option<i32>,
}

impl From<RawBakiyeHareket> for BakiyeHareketResponse {
    fn from(r: RawBakiyeHareket) -> Self {
        Self {
            marina_no: r.marina_no,
            abone_no: r.abone_no,
            istasyon_id: r.istasyon_id,
            tarih: r.tarih,
            tutar: r.tutar,
            tutar_iade: r.tutar_iade,
            bakiye: r.bakiye,
            para_birimi: r.para_birimi,
            kayit_kim: r.kayit_kim,
            kart_ad_soyad: r.kart_ad_soyad,
            kart_id: r.kart_id,
            kayit_tipi: r.kayit_tipi,
            yil: r.yil,
        }
    }
}

/// Genel başarı response
#[derive(Debug, Serialize)]
#[serde(rename_all = "PascalCase")]
pub struct OkResponse {
    pub success: bool,
    pub message: String,
}

impl OkResponse {
    pub fn ok() -> Self {
        Self { success: true, message: "OK".into() }
    }
}

/// API hata response
#[derive(Debug, Serialize)]
pub struct ErrorResponse {
    pub success: bool,
    pub error: bool,
    pub message: String,
    pub code: u16,
}
