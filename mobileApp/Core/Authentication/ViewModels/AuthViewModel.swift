import SwiftUI
import Combine

class AuthViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    
    private let apiService = ApiService.shared
    
    init() {
        checkAuthentication()
    }
    
    // MARK: - Authentication Methods
    
    func signIn(email: String, password: String) {
        errorMessage = nil
        isLoading = true
        
        Task {
            do {
                let tokenResponse = try await apiService.login(email: email, password: password)
                
                // Backend'den gelen kullanıcı bilgilerini kullan
                let user = User(
                    email: tokenResponse.email,
                    password: "",
                    name: tokenResponse.userFullName ?? "",
                    balance: 0.0 // Bakiye ayrıca API'den çekilecek
                )
                
                await MainActor.run {
                    self.currentUser = user
                    self.isAuthenticated = true
                    UserDefaults.standard.set(true, forKey: "isAuthenticated")
                    UserDefaults.standard.set(tokenResponse.email, forKey: "currentUserEmail")
                    UserDefaults.standard.set(tokenResponse.userFullName ?? "", forKey: "currentUserName")
                    self.isLoading = false
                }
                
                // Bakiyeyi de çek
                await refreshBalance()
                
            } catch {
                await MainActor.run {
                    if let apiError = error as? APIError {
                        self.errorMessage = apiError.errorDescription
                    } else {
                        self.errorMessage = "Giriş başarısız: \(error.localizedDescription)"
                    }
                    self.isLoading = false
                }
            }
        }
    }
    
    func signUp(email: String, password: String, name: String, boatName: String, adress: String, tcIdentityNumber: String) {
        errorMessage = nil
        isLoading = true
        
        Task {
            do {
                // Email kontrolü
                let emailExists = try await apiService.postMailKontrol(email: email)
                if emailExists {
                    await MainActor.run {
                        self.errorMessage = "Bu e-posta adresi zaten kayıtlı"
                        self.isLoading = false
                    }
                    return
                }
                
                // TC kontrolü
                if tcIdentityNumber.count != 11 {
                    await MainActor.run {
                        self.errorMessage = "TC numarası 11 haneli olmalıdır"
                        self.isLoading = false
                    }
                    return
                }
                
                let tcExists = try await apiService.postTCKontrol(tcNo: tcIdentityNumber)
                if tcExists {
                    await MainActor.run {
                        self.errorMessage = "Bu TC kimlik numarası zaten kayıtlı"
                        self.isLoading = false
                    }
                    return
                }
                
                // TODO: Backend'e kullanıcı kayıt API'si eklendiğinde burası güncellenecek
                await MainActor.run {
                    self.errorMessage = "Kayıt işlemi için backend API'si bekleniyor"
                    self.isLoading = false
                }
                
            } catch {
                await MainActor.run {
                    if let apiError = error as? APIError {
                        self.errorMessage = apiError.errorDescription
                    } else {
                        self.errorMessage = "Kayıt başarısız: \(error.localizedDescription)"
                    }
                    self.isLoading = false
                }
            }
        }
    }
    
    func signOut() {
        apiService.logout()
        currentUser = nil
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: "isAuthenticated")
        UserDefaults.standard.removeObject(forKey: "currentUserEmail")
    }
    
    private func checkAuthentication() {
        let isAuthenticatedStored = UserDefaults.standard.bool(forKey: "isAuthenticated")
        
        if isAuthenticatedStored && apiService.isAuthenticated {
            Task {
                // 1. Önce email'i al ve currentUser'ı oluştur
                if let email = UserDefaults.standard.string(forKey: "currentUserEmail") {
                    await MainActor.run {
                        self.currentUser = User(
                            email: email,
                            password: "",
                            name: UserDefaults.standard.string(forKey: "currentUserName") ?? "",
                            balance: 0.0
                        )
                        self.isAuthenticated = true
                    }
                }
                
                // 2. Sonra bakiyeyi çek (artık currentUser nil değil)
                await refreshBalance()
            }
        }
    }
    
    // MARK: - Balance Operations
    
    func addBalance(amount: Double, completion: @escaping (Bool, String?) -> Void) {
        guard amount > 0 else {
            completion(false, "Geçersiz tutar")
            return
        }
        
        Task {
            do {
                try await apiService.postBakiyeYukle(tutar: amount)
                
                await refreshBalance()
                
                await MainActor.run {
                    completion(true, nil)
                }
            } catch {
                await MainActor.run {
                    if let apiError = error as? APIError {
                        completion(false, apiError.errorDescription)
                    } else {
                        completion(false, "Bakiye yükleme başarısız: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    func refreshBalance() async {
        do {
            let balance = try await apiService.getMevcutBakiye()
            print("Bakiye güncellendi (Sync): \(balance)")
            await MainActor.run {
                self.currentUser?.balance = balance
            }
        } catch {
            print("Bakiye getirme hatası: \(error)")
        }
    }
    
    // MARK: - Card Management
    
    func saveCard(cardHolderName: String, cardNumber: String,
                  expirationDate: String, cvv: String,
                  completion: @escaping (Bool, String?) -> Void) {
        
        let cleanNumber = cardNumber.replacingOccurrences(of: " ", with: "")
        

        guard cleanNumber.count == 16, CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: cleanNumber)) else {
            completion(false, "Geçerli bir kart numarası giriniz (16 haneli)")
            return
        }
        
        guard cvv.count == 3, Int(cvv) != nil else {
            completion(false, "Geçerli bir CVV giriniz (3 haneli)")
            return
        }
        
        guard isValidExpirationDate(expirationDate) else {
            completion(false, "Geçerli bir son kullanma tarihi giriniz (MM/YY)")
            return
        }
        
        let lastFour = String(cleanNumber.suffix(4))
        let maskedCardNumber = "**** **** **** \(lastFour)"
        
        let newCard = Savedcard(
            cardHolderName: cardHolderName.uppercased(),
            cardNumber: maskedCardNumber,
            expirationDate: expirationDate,
            cvv: cvv
        )
        
        // Local olarak kaydet
        currentUser?.savedCard = newCard
        completion(true, nil)
        
        // TODO: Backend'e kart kaydetme API'si eklendiğinde burası güncellenecek
    }
        
    func removeCard() {
        currentUser?.savedCard = nil
        // TODO: Backend'den kart silme API'si eklendiğinde burası güncellenecek
    }
    
    private func isValidExpirationDate(_ date: String) -> Bool {
        let pattern = #"^(0[1-9]|1[0-2])\/([0-9]{2})$"#
        return date.range(of: pattern, options: .regularExpression) != nil
    }
    
    // MARK: - Profile Update
    
    func updateUserProfile(name: String, boatName: String, adress: String, tcIdentityNumber: String,
                           completion: @escaping (Bool, String?) -> Void) {
        guard currentUser != nil else {
            completion(false, "Kullanıcı bulunamadı")
            return
        }
        
        // Local olarak güncelle
        currentUser?.name = name
        currentUser?.boatName = boatName
        currentUser?.adress = adress
        currentUser?.tcIdentityNumber = tcIdentityNumber
        
        completion(true, nil)
        
        // TODO: Backend'e profil güncelleme API'si eklendiğinde burası güncellenecek
    }
    
    // MARK: - JWT Token Decoding
    
    private func decodeToken(_ token: String) -> User? {
        print("Decoding JWT Token...")
        
        let segments = token.components(separatedBy: ".")
        guard segments.count > 1 else {
            print("Token segment sayısı yeterli değil: \(segments.count)")
            return nil
        }
        
        let payloadSegment = segments[1]
        var base64 = payloadSegment
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // Padding ekle
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("JWT decode hatası")
            return nil
        }
        
        // DEBUG: Token içeriği
        print("JWT Payload içeriği:")
        for (key, value) in json {
            print("  - \(key): \(value)")
        }
        
        // JWT claims'lerinden kullanıcı bilgilerini çıkar
        let email = json["email"] as? String ?? json["unique_name"] as? String ?? json["sub"] as? String ?? ""
        let name = json["given_name"] as? String ?? json["name"] as? String ?? ""
        
        print("Decode edilen email: \(email)")
        print("Decode edilen name: \(name)")
        
        if email.isEmpty {
            print("Email bulunamadı! Token içinde email claim'i yok.")
        }
        
        return User(
            email: email,
            password: "",
            name: name,
            balance: 0.0
        )
    }
}

