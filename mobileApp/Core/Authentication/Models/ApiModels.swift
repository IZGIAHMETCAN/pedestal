import Foundation

// MARK: - Request Models

/// Login request body
struct LoginRequest: Codable {
    let email: String
    let password: String
}

/// Token response from authentication
struct TokenResponse: Codable {
    let token: String
    let email: String
    let userFullName: String?
    let userId: Int?
    let webApiUrl: String?
    let userProfileImageUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case token = "Token"  // Backend büyük T ile dönüyor
        case email = "Email"
        case userFullName = "UserFullName"
        case userId = "UserId"
        case webApiUrl = "WebApiUrl"
        case userProfileImageUrl = "UserProfileImageUrl"
    }
}

/// Bakiye yükleme request
struct BakiyeYukleRequest: Codable {
    let kartId: String?
    let tutar: Double
}

/// İstasyona bakiye yükleme request
struct BakiyeIstasyonRequest: Codable {
    let istasyonId: Int
    let kartId: String
    let amount: Double
    let currency: String
}

/// Elektrik/Su kontrol request
struct ElektrikSuKontrolRequest: Codable {
    let istasyonId: Int
    let kartId: String
    let suElektrik: Bool  // true: Su, false: Elektrik
    let islem: Int        // 1: Aç, 0: Kapat
}

/// Bakiye iade request
struct BakiyeIadeRequest: Codable {
    let istasyonId: Int
    let kartId: String
}

/// Bakiye hareketleri request (tarih aralığı ile)
struct BakiyeHareketleriRequest: Codable {
    let kartId: String
    let firstDate: Date
    let secondDate: Date
}

/// Tüketim raporu request
struct TuketimRaporuRequest: Codable {
    let kartID: String
    let firstDate: Date
    let secondDate: Date
    
    enum CodingKeys: String, CodingKey {
        case kartID = "KartID"
        case firstDate = "FirstDate"
        case secondDate = "SecondDate"
    }
}

/// Mesaj bilgisi (genel amaçlı)
struct MesajRequest: Codable {
    let mesajGelen: String
}

// MARK: - Response Models

/// Abone kartı response (Backend'den gelen gerçek format)
struct AboneKart: Codable, Identifiable, Hashable {
    var id: String { kartId }
    let recId: Int
    let marinaNo: Int
    let aboneNo: String
    let kartId: String
    let kartSahibi: String
    let silTarih: String?
    let silKim: String?
    
    enum CodingKeys: String, CodingKey {
        case recId = "RecId"
        case marinaNo = "MarinaNo"
        case aboneNo = "AboneNo"
        case kartId = "KartId"
        case kartSahibi = "KartSahibi"
        case silTarih = "SilTarih"
        case silKim = "SilKim"
    }
}

/// Pedestal/İstasyon listesi response (Backend'den gelen gerçek format)
struct PedestalResponse: Codable, Identifiable, Hashable {
    var id: Int { istasyonId }
    let recId: Int
    let marinaNo: Int
    let portAdi: String
    let istasyonAdi: String
    let istasyonId: Int
    let prizNo: Int
    let aciklama: String?
    let aktif: Bool
    let silTarih: String?
    let silKim: String?
    
    enum CodingKeys: String, CodingKey {
        case recId = "RecId"
        case marinaNo = "MarinaNo"
        case portAdi = "PortAdi"
        case istasyonAdi = "IstasyonAdi"
        case istasyonId = "IstasyonId"
        case prizNo = "PrizNo"
        case aciklama = "Aciklama"
        case aktif = "Aktif"
        case silTarih = "SilTarih"
        case silKim = "SilKim"
    }
}

/// İstasyon detay bilgisi response (Backend'den gelen gerçek format)
struct IstasyonBilgiResponse: Codable {
    let recId: Int
    let tarih: String // Tarih formatı: "2026-02-03T14:14:51.36"
    let marinaNo: Int
    let istasyonId: Int
    let aboneNo: String?
    let kartId: String?
    let bakiye: Double?
    let bakiyeKart: Double?
    let su: Bool?
    let elektrik: Bool?
    let elektrikTuketim: Double?
    let litreTuketim: Double?
    let kapali: Bool?
    let yil: Int?
    
    enum CodingKeys: String, CodingKey {
        case recId = "RecId"
        case tarih = "Tarih"
        case marinaNo = "MarinaNo"
        case istasyonId = "IstasyonId"
        case aboneNo = "AboneNo"
        case kartId = "KartId"
        case bakiye = "Bakiye"
        case bakiyeKart = "BakiyeKart"
        case su = "Su"
        case elektrik = "Elektrik"
        case elektrikTuketim = "ElektrikTuketim"
        case litreTuketim = "LitreTuketim"
        case kapali = "Kapali"
        case yil = "Yil"
    }
}

/// Bakiye hareketi response
struct BakiyeHareket: Codable, Identifiable {
    var id: String { "\(tarih?.timeIntervalSince1970 ?? 0)-\(kartId)" }
    let marinaNo: Int?
    let aboneNo: String?
    let istasyonId: Int?
    let tarih: Date?
    let tutar: Double?
    let tutarIade: Double?
    let bakiye: Double?
    let paraBirimi: String
    let kayitKim: String
    let kartAdSoyad: String
    let kartId: String
    let kayitTipi: Int?
    let yil: Int?
}


/// Tüketim bilgisi response (Backend IstasyonBilgiResponse ile aynı formatta dönüyor)
typealias TuketimBilgisiResponse = IstasyonBilgiResponse


/// Genel mesaj response
struct MesajResponse: Codable {
    let mesajGelen: String?
}

// MARK: - Helper Extensions

extension JSONDecoder {
    /// API için özelleştirilmiş decoder (ISO 8601 tarih formatı)
    static var apiDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

extension JSONEncoder {
    /// API için özelleştirilmiş encoder (ISO 8601 tarih formatı)
    static var apiEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

// MARK: - API Error

enum APIError: LocalizedError {
    case invalidResponse
    case unauthorized
    case networkError
    case decodingError(Error)
    case serverError(String)
    case badRequest(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Geçersiz sunucu yanıtı"
        case .unauthorized:
            return "Oturum süreniz doldu. Lütfen tekrar giriş yapın."
        case .networkError:
            return "Bağlantı hatası. İnternet bağlantınızı kontrol edin."
        case .decodingError(let error):
            return "Veri işleme hatası: \(error.localizedDescription)"
        case .serverError(let message):
            return "Sunucu hatası: \(message)"
        case .badRequest(let message):
            return "Hatalı istek: \(message)"
        }
    }
}

