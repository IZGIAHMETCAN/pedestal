import Foundation

final class ApiService {
    static let shared = ApiService()
    private init() {}
    
    // Backend test sunucusu
    private let baseURL = "http://31.141.228.115:44350"
    
    // Token artık Keychain'de güvenli olarak saklanıyor
    private var token: String? {
        get {
            KeychainHelper.shared.getToken()
        }
        set {
            if let newValue = newValue {
                KeychainHelper.shared.saveToken(newValue)
            } else {
                KeychainHelper.shared.deleteToken()
            }
        }
    }
    
    // MARK: - Authentication
    
    /// Login with email and password
    func login(email: String, password: String) async throws -> TokenResponse {
        let url = URL(string: "\(baseURL)/api/Token/Authenticate")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = LoginRequest(email: email, password: password)
        request.httpBody = try JSONEncoder.apiEncoder.encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("Login Response: \(responseString)")
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        print("Status Code: \(httpResponse.statusCode)")
        
        guard 200..<300 ~= httpResponse.statusCode else {
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }
            throw APIError.serverError("HTTP \(httpResponse.statusCode)")
        }
        
        // JSON decode
        do {
            let tokenResponse = try JSONDecoder.apiDecoder.decode(TokenResponse.self, from: data)
            token = tokenResponse.token
            
            print("Token alındı: \(String(tokenResponse.token.prefix(20)))...")
            print("Email: \(tokenResponse.email)")
            print("UserFullName: \(tokenResponse.userFullName ?? "N/A")")
            
            return tokenResponse
        } catch {
            print("JSON Decode Hatası: \(error)")
            print("Response Data: \(String(data: data, encoding: .utf8) ?? "nil")")
            throw APIError.decodingError(error)
        }
    }
    
    /// Logout - clear token
    func logout() {
        token = nil
        UserDefaults.standard.removeObject(forKey: "authToken")
    }
    
    /// Check if user is authenticated
    var isAuthenticated: Bool {
        return token != nil
    }
    
    // MARK: - Balance Operations
    
    /// Get current user balance
    func getMevcutBakiye() async throws -> Double {
        let data = try await authorizedRequest(
            endpoint: "api/Customer/GetMevcutBakiye",
            method: "GET"
        )
        
        let balance = try JSONDecoder.apiDecoder.decode(Double.self, from: data)
        return balance
    }
    
    /// Add balance to user account
    func postBakiyeYukle(tutar: Double, kartId: String? = nil) async throws {
        let body = BakiyeYukleRequest(kartId: kartId, tutar: tutar)
        let bodyData = try JSONEncoder.apiEncoder.encode(body)
        
        _ = try await authorizedRequest(
            endpoint: "api/Customer/PostBakiyeYukle",
            method: "POST",
            body: bodyData
        )
    }
    
    /// Get balance history/transactions
    func getBakiyeHareketleri(kartId: String, firstDate: Date, secondDate: Date) async throws -> [BakiyeHareket] {
        let request = BakiyeHareketleriRequest(
            kartId: kartId,
            firstDate: firstDate,
            secondDate: secondDate
        )
        let bodyData = try JSONEncoder.apiEncoder.encode(request)
        
        let data = try await authorizedRequest(
            endpoint: "api/Customer/GetBakiyeListDate",
            method: "GET",
            body: bodyData
        )
        
        let hareketler = try JSONDecoder.apiDecoder.decode([BakiyeHareket].self, from: data)
        return hareketler
    }
    
    // MARK: - Card Operations
    
    /// Get user's cards
    func getKullaniciKartlari() async throws -> [AboneKart] {
        let data = try await authorizedRequest(
            endpoint: "api/Customer/GetAboneKartlari",
            method: "GET"
        )
        
        let kartlar = try JSONDecoder.apiDecoder.decode([AboneKart].self, from: data)
        return kartlar
    }
    
    /// Create virtual card
    func getSanalKartOlustur() async throws {
        _ = try await authorizedRequest(
            endpoint: "api/Customer/GetSanalKartOlustur",
            method: "GET"
        )
    }
    
    // MARK: - Pedestal/Station Operations
    
    /// Get user's active pedestals
    func getKullanilanPedestal() async throws -> [PedestalResponse] {
        let data = try await authorizedRequest(
            endpoint: "api/Customer/GetKullanilanPedestal",
            method: "GET"
        )
        
        let pedestaller = try JSONDecoder.apiDecoder.decode([PedestalResponse].self, from: data)
        return pedestaller
    }
    
    /// Get available (empty) pedestals
    func getBosIstasyonlar() async throws -> [PedestalResponse] {
        let data = try await authorizedRequest(
            endpoint: "api/Customer/GetBosIstasyonlar",
            method: "GET"
        )
        
        let pedestaller = try JSONDecoder.apiDecoder.decode([PedestalResponse].self, from: data)
        return pedestaller
    }
    
    /// Get station last record info
    func getIstasyonSonKayit(istasyonId: Int) async throws -> IstasyonBilgiResponse {
        
        let bodyData = "\(istasyonId)".data(using: .utf8)!
        
        let data = try await authorizedRequest(
            endpoint: "api/Customer/PostIstasyonSonKayit",
            method: "POST",
            body: bodyData
        )
        
        let bilgi = try JSONDecoder.apiDecoder.decode(IstasyonBilgiResponse.self, from: data)
        return bilgi
    }
    
    /// Load balance to station
    func postBakiyeIstasyon(request: BakiyeIstasyonRequest) async throws {
        let bodyData = try JSONEncoder.apiEncoder.encode(request)
        
        let data = try await authorizedRequest(
            endpoint: "api/Customer/PostBakiyeIstasyon",
            method: "POST",
            body: bodyData
        )
        
        // Dönen cevap: Düz string "Tamam" (JSON değil)
        let responseString = String(data: data, encoding: .utf8)?.replacingOccurrences(of: "\"", with: "")
        
        if responseString != "Tamam" {
            // Belki JSON dönmüştür, bir de öyle deneyelim (Fallback)
            if let response = try? JSONDecoder.apiDecoder.decode(MesajResponse.self, from: data) {
                if response.mesajGelen != "Tamam" {
                    throw APIError.serverError(response.mesajGelen ?? "Bilinmeyen hata")
                }
            } else {
                // Ne JSON ne de "Tamam" stringi
                throw APIError.serverError(responseString ?? "Sunucu hatası")
            }
        }
    }
    
    /// Control water/electricity (open/close)
    func postElektrikSuKontrol(request: ElektrikSuKontrolRequest) async throws {
        let bodyData = try JSONEncoder.apiEncoder.encode(request)
        
        let data = try await authorizedRequest(
            endpoint: "api/Customer/PostElektrikSuAc",
            method: "POST",
            body: bodyData
        )
        
        // Response string olarak geliyor: "Tamam"
        if let responseString = String(data: data, encoding: .utf8) {
            let cleanedString = responseString.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            if cleanedString != "Tamam" {
                throw APIError.serverError("İşlem başarısız")
            }
        }
    }
    
    /// Refund balance from station
    func postBakiyeIade(request: BakiyeIadeRequest) async throws {
        let bodyData = try JSONEncoder.apiEncoder.encode(request)
        
        let data = try await authorizedRequest(
            endpoint: "api/Customer/PostBakiyeIade",
            method: "POST",
            body: bodyData
        )
        
        // Dönen cevap: Düz string "Tamam" veya Boolean JSON olabilir
        let responseString = String(data: data, encoding: .utf8)?.replacingOccurrences(of: "\"", with: "")
        
        if responseString == "Tamam" {
            // Başarılı
            return
        }
        
        // Boolean deneyelim (Eski davranış)
        if let success = try? JSONDecoder.apiDecoder.decode(Bool.self, from: data), success {
            return
        }
        
        // MesajResponse deniyelim
        if let response = try? JSONDecoder.apiDecoder.decode(MesajResponse.self, from: data) {
            if response.mesajGelen == "Tamam" {
                return
            }
            throw APIError.serverError(response.mesajGelen ?? "İade işlemi başarısız")
        }
        
        throw APIError.serverError(responseString ?? "İade işlemi başarısız")
    }
    
    // MARK: - Consumption Reports
    
    /// Get user consumption report (Backend IstasyonBilgiResponse array'i dönüyor)
    func getKullaniciTuketimler(kartID: String, firstDate: Date, secondDate: Date) async throws -> [IstasyonBilgiResponse] {
        let request = TuketimRaporuRequest(
            kartID: kartID,
            firstDate: firstDate,
            secondDate: secondDate
        )
        let bodyData = try JSONEncoder.apiEncoder.encode(request)
        
        let data = try await authorizedRequest(
            endpoint: "api/Customer/GetKullaniciTuketimler",
            method: "GET",  // Backend POST bekliyor
            body: bodyData
        )
        
        let tuketimler = try JSONDecoder.apiDecoder.decode([IstasyonBilgiResponse].self, from: data)
        return tuketimler
    }
    
    // MARK: - User Registration Helpers
    
    /// Check if email exists
    func postMailKontrol(email: String) async throws -> Bool {
        let request = MesajRequest(mesajGelen: email)
        let bodyData = try JSONEncoder.apiEncoder.encode(request)
        
        let data = try await authorizedRequest(
            endpoint: "api/Customer/PostMailControl",
            method: "POST",
            body: bodyData,
            requiresAuth: false
        )
        
        // Dönen cevap: Düz string "true"/"false" veya JSON olabilir
        let responseString = String(data: data, encoding: .utf8)?.replacingOccurrences(of: "\"", with: "")
        
        if responseString == "true" { return true }
        if responseString == "false" { return false }
        
        // JSON deneyelim (Fallback)
        if let response = try? JSONDecoder.apiDecoder.decode(MesajResponse.self, from: data) {
            return response.mesajGelen == "true"
        }
        
        return false
    }
    
    /// Check if TC number exists
    func postTCKontrol(tcNo: String) async throws -> Bool {
        let request = MesajRequest(mesajGelen: tcNo)
        let bodyData = try JSONEncoder.apiEncoder.encode(request)
        
        let data = try await authorizedRequest(
            endpoint: "api/Customer/PostTCNumara",
            method: "POST",
            body: bodyData,
            requiresAuth: false
        )
        
        // Dönen cevap: Düz string "true"/"false" veya JSON olabilir
        let responseString = String(data: data, encoding: .utf8)?.replacingOccurrences(of: "\"", with: "")
        
        if responseString == "true" { return true }
        if responseString == "false" { return false }
        
        // JSON deneyelim (Fallback)
        if let response = try? JSONDecoder.apiDecoder.decode(MesajResponse.self, from: data) {
            return response.mesajGelen == "true"
        }
        
        return false
    }
    
    /// Send email
    func getMailGonder(mesaj: String) async throws {
        let request = MesajRequest(mesajGelen: mesaj)
        let bodyData = try JSONEncoder.apiEncoder.encode(request)
        
        _ = try await authorizedRequest(
            endpoint: "api/Customer/GetMailGonder",
            method: "POST",
            body: bodyData
        )
    }
    
    // MARK: - Private Helper Methods
    
    private func authorizedRequest(
        endpoint: String,
        method: String = "POST",
        body: Data? = nil,
        requiresAuth: Bool = true,
        contentType: String = "application/json"
    ) async throws -> Data {
        
        if requiresAuth {
            guard let token else {
                throw APIError.unauthorized
            }
        }
        
        let url = URL(string: "\(baseURL)/\(endpoint)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        // Eğer contentType boş değilse ekle
        if !contentType.isEmpty {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        
        if requiresAuth, let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard 200..<300 ~= httpResponse.statusCode else {
            if httpResponse.statusCode == 401 {
                // Token expired, logout
                logout()
                throw APIError.unauthorized
            }
            throw APIError.serverError("HTTP \(httpResponse.statusCode)")
        }
        
        return data
    }
}
