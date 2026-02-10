import SwiftUI

// QR kod okutulduktan sonra pedestal detayını API'den çekip detail view'a yönlendiren loader
struct QRPedestalDetailLoader: View {
    let pedestalId: Int
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var pedestal: Pedestal?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let pedestal = pedestal {
                PedestalDetailView(pedestal: pedestal)
                    .environmentObject(authViewModel)
            } else if let error = errorMessage {
                errorView(error)
            }
        }
        .onAppear {
            loadPedestalDetail()
        }
    }
    
    private var loadingView: some View {
        ZStack {
            Color(red: 0.01, green: 0.05, blue: 0.1)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text("İstasyon bilgileri yükleniyor...")
                    .foregroundColor(.white.opacity(0.8))
                    .font(.subheadline)
            }
        }
    }
    
    private func errorView(_ message: String) -> some View {
        ZStack {
            Color(red: 0.01, green: 0.05, blue: 0.1)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)
                
                Text("Hata")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(message)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                
                Button("Tekrar Dene") {
                    loadPedestalDetail()
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 12)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
    }
    
    private func loadPedestalDetail() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let apiService = ApiService.shared
                
                print("QR Loader: Loading pedestal ID \(pedestalId)")
                
                var foundPedestalResponse: PedestalResponse?
                
                // 1. Önce kullanılan pedestal listesinde ara
                print("Fetching GetKullanilanPedestal...")
                if let usedList = try? await apiService.getKullanilanPedestal() {
                     print("Received used list: \(usedList.count) items")
                     foundPedestalResponse = usedList.first(where: { $0.istasyonId == pedestalId })
                }
                
                // 2. Bulunamadıysa Boş İstasyon listesinde ara
                if foundPedestalResponse == nil {
                    print("Fetching GetBosIstasyonlar...")
                    if let emptyList = try? await apiService.getBosIstasyonlar() {
                         print("Received empty list: \(emptyList.count) items")
                         foundPedestalResponse = emptyList.first(where: { $0.istasyonId == pedestalId })
                    }
                }
                
                // 3. Listede bulunamadıysa, fallback: Direkt PostIstasyonSonKayit dene
                let pedestalResponse: PedestalResponse
                if let found = foundPedestalResponse {
                    pedestalResponse = found
                    print("Processing pedestal: \(pedestalResponse.portAdi)")
                } else {
                    print("Pedestal not found in lists, trying fallback...")
                    pedestalResponse = PedestalResponse(
                        recId: 0,
                        marinaNo: 1,
                        portAdi: "İstasyon \(pedestalId)",
                        istasyonAdi: "Fallback Istasyon",
                        istasyonId: pedestalId,
                        prizNo: 0,
                        aciklama: nil,
                        aktif: true,
                        silTarih: nil,
                        silKim: nil
                    )
                    print("Created fallback PedestalResponse")
                }
                
                // Detaylı bilgi için PostIstasyonSonKayit çağır
                print("Fetching PostIstasyonSonKayit for ID \(pedestalId)...")
                let istasyonBilgi = try await apiService.getIstasyonSonKayit(istasyonId: pedestalId)
                print("Received station info")
                
                // Pedestal oluştur
                let loadedPedestal = Pedestal.fromResponse(pedestalResponse, istasyonBilgi: istasyonBilgi)
                
                await MainActor.run {
                    self.pedestal = loadedPedestal
                    self.isLoading = false
                }
                
            } catch {
                print("Error loading pedestal: \(error)")
                print("Error type: \(type(of: error))")
                print("Error localized: \(error.localizedDescription)")
                
                await MainActor.run {
                    if let apiError = error as? APIError {
                        self.errorMessage = apiError.errorDescription ?? "Bilinmeyen hata"
                    } else if let urlError = error as? URLError {
                        self.errorMessage = "Network hatası: \(urlError.localizedDescription) (Code: \(urlError.code.rawValue))"
                    } else {
                        self.errorMessage = "İstasyon bilgileri yüklenemedi: \(error.localizedDescription)"
                    }
                    self.isLoading = false
                }
            }
        }
    }
}


