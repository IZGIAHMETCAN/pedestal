import Foundation
import Combine

class PedestalUsageViewModel: ObservableObject {
    @Published var pedestal: Pedestal
    
    @Published var isWaterActive: Bool = false
    @Published var isElectricityActive: Bool = false
    @Published var currentWaterUsage: Double = 0.0
    @Published var currentElectricityUsage: Double = 0.0
    @Published var currentWaterCost: Double = 0.0
    @Published var currentElectricityCost: Double = 0.0
    
    @Published var showLowBalanceAlert: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    @Published var isRefreshing: Bool = false
    
    // Usage history
    var usageHistory: [Usage] {
        return UsageHistoryManager.shared.getUsageHistory(for: pedestal.id)
    }
    
    var totalCost: Double {
        return currentWaterCost + currentElectricityCost
    }
    

    
    private var waterStartTime: Date?
    private var electricityStartTime: Date?
    private var pollingTask: Task<Void, Never>?
    
    var getRemoteBalance: (() -> Double)?
    var updateRemoteBalance: ((Double) -> Void)?
    
    private let apiService = ApiService.shared
    
    init(pedestal: Pedestal) {
        self.pedestal = pedestal
    }
    
    // MARK: - Water Control
    
    func toggleWater() {
        if isWaterActive {
            stopWater()
        } else {
            startWater()
        }
    }
    
    private var startWaterMeterValue: Double?
    private var startElectricityMeterValue: Double?
    
    private func startWater() {
        let currentBalance = pedestal.balance
        guard currentBalance >= 1.0 else {
            showLowBalanceAlert = true
            return
        }
        
        isLoading = true
        
        Task {
            do {
                
                let request = ElektrikSuKontrolRequest(
                    istasyonId: pedestal.id,
                    kartId: pedestal.kartId ?? "",
                    suElektrik: true, // Su
                    islem: 1 // Aç
                )
                
                try await apiService.postElektrikSuKontrol(request: request)
                
                await self.refreshPedestalData()
                
                await MainActor.run {
                    self.isWaterActive = true
                    self.isLoading = false
                    self.waterStartTime = Date()
                    // Başlangıç sayacını kaydet
                    self.startWaterMeterValue = self.currentWaterUsage
                    print("Su Başlangıç Sayacı: \(self.currentWaterUsage)")
                }
                
                try await Task.sleep(nanoseconds: 2_000_000_000)
                await self.refreshPedestalData()
                await self.refreshPedestalData()
            } catch {
                
            }
        }
    }
    
    private func stopWater() {
        isLoading = true
        
        Task {
            do {
                let request = ElektrikSuKontrolRequest(
                    istasyonId: pedestal.id,
                    kartId: pedestal.kartId ?? "",
                    suElektrik: true, // Su
                    islem: 0 // Kapat
                )
                
                try await apiService.postElektrikSuKontrol(request: request)
                
                // Kapattıktan sonra son veriyi çek
                try await Task.sleep(nanoseconds: 2_000_000_000)
                await self.refreshPedestalData()
                
                await MainActor.run {
                    self.isWaterActive = false
                    self.isLoading = false
                    
                    // Tüketim Hesapla ve Kaydet
                    if let startVal = self.startWaterMeterValue {
                        let endVal = self.currentWaterUsage
                        let consumption = max(0, endVal - startVal) // Negatif olmasın
                        
                        let cost = consumption * (self.pedestal.waterRate > 0 ? self.pedestal.waterRate : 10.0) / 1000.0
                        
                        print("Su Tüketimi Hesaplandı: \(endVal) - \(startVal) = \(consumption) L")
                        
                        self.saveUsageToHistory(type: .water, consumption: consumption, cost: cost)
                    }
                    
                    self.startWaterMeterValue = nil // Sıfırla
                    
                    if !self.isElectricityActive {
                        // self.stopPolling() -> View lifecycle otomatik yönetecek
                    }
                }
            } catch {
                
            }
        }
    }


    
    // MARK: - Electricity Control
    
    func toggleElectricity() {
        if isElectricityActive {
            stopElectricity()
        } else {
            startElectricity()
        }
    }
    
    private func startElectricity() {
        let currentBalance = pedestal.balance
        guard currentBalance >= 10.0 else {
            showLowBalanceAlert = true
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let request = ElektrikSuKontrolRequest(
                    istasyonId: pedestal.id,
                    kartId: pedestal.kartId ?? "",
                    suElektrik: false, // Elektrik için
                    islem: 1 // Aç
                )
                
                try await apiService.postElektrikSuKontrol(request: request)
                
                await self.refreshPedestalData()
                
                await MainActor.run {
                    self.isElectricityActive = true
                    self.electricityStartTime = Date()
                    self.isLoading = false
                    self.startElectricityMeterValue = self.currentElectricityUsage
                    print("Elektrik Başlangıç Sayacı: \(self.currentElectricityUsage)")
                }
                
                try await Task.sleep(nanoseconds: 2_000_000_000)
                await self.refreshPedestalData()
                await self.refreshPedestalData()
            } catch {
                await MainActor.run {
                    self.errorMessage = "Elektrik açma başarısız: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func stopElectricity() {
        isLoading = true
        
        Task {
            do {
                let request = ElektrikSuKontrolRequest(
                    istasyonId: pedestal.id,
                    kartId: pedestal.kartId ?? "",
                    suElektrik: false,
                    islem: 0
                )
                
                try await apiService.postElektrikSuKontrol(request: request)
                
                // Kapattıktan sonra son veriyi çek
                try await Task.sleep(nanoseconds: 2_000_000_000)
                await self.refreshPedestalData()
                
                await MainActor.run {
                    self.isElectricityActive = false
                    self.isLoading = false
                    
                    // Tüketim Hesapla ve Kaydet
                    if let startVal = self.startElectricityMeterValue {
                        let endVal = self.currentElectricityUsage
                        let consumption = max(0, endVal - startVal)
                        
                        let cost = consumption * (self.pedestal.electricityRate > 0 ? self.pedestal.electricityRate : 5.0)
                        
                        print("Elektrik Tüketimi Hesaplandı: \(endVal) - \(startVal) = \(consumption) Watt")
                        
                        self.saveUsageToHistory(type: .electricity, consumption: consumption, cost: cost)
                    }
                    
                    self.startElectricityMeterValue = nil
                    
                    
                    if !self.isWaterActive {
                        
                    }
                }
                
            } catch {
                await MainActor.run {
                    self.errorMessage = "Elektrik kapatma başarısız: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    

    
    // MARK: - Balance Operations
    
    func loadBalanceToStation(amount: Double) async throws {
        let request = BakiyeIstasyonRequest(
            istasyonId: pedestal.id,
            kartId: pedestal.kartId ?? "",
            amount: amount
        )
        
        try await apiService.postBakiyeIstasyon(request: request)
        
        // pedestal bilgilerini güncelle
        await refreshPedestalData()
    }
    
    func refundBalance() async throws {
        let request = BakiyeIadeRequest(
            istasyonId: pedestal.id,
            kartId: pedestal.kartId ?? ""
        )
        
        try await apiService.postBakiyeIade(request: request)
        
        // İade sonrası pedestal bilgilerini güncelle
        await refreshPedestalData()
    }
    
    func refreshPedestalData() async {
        
        await MainActor.run { self.isRefreshing = true }
        
        do {
            _ = try? await apiService.getKullanilanPedestal()
            
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 saniye
            
            let istasyonBilgi = try await apiService.getIstasyonSonKayit(istasyonId: pedestal.id)
            
            
            await MainActor.run {
                
                // Bakiye
                if let bakiye = istasyonBilgi.bakiye {
                    print("Bakiye güncellendi: \(self.pedestal.balance) -> \(bakiye)")
                    self.pedestal.balance = bakiye
                }
                
                // Su durumu
                let suDurumu = istasyonBilgi.su ?? false
                print("Su durumu: \(self.isWaterActive) -> \(suDurumu)")
                self.isWaterActive = suDurumu
                
                // Elektrik durumu
                let elektrikDurumu = istasyonBilgi.elektrik ?? false
                print("Elektrik durumu: \(self.isElectricityActive) -> \(elektrikDurumu)")
                self.isElectricityActive = elektrikDurumu
                
                // Tüketim bilgileri
                if let suTuketim = istasyonBilgi.litreTuketim {
                    print("Su tüketimi: \(suTuketim) Lt")
                    self.currentWaterUsage = suTuketim
                }
                
                if let elektrikTuketim = istasyonBilgi.elektrikTuketim {
                    print("Elektrik tüketimi: \(elektrikTuketim) Watt")
                    self.currentElectricityUsage = elektrikTuketim
                }
                
                print("Pedestal verileri başarıyla güncellendi!")
                self.isRefreshing = false
            }
            
        } catch {
            print("Pedestal verileri yenileme hatası: \(error)")
            print("Detay: \(error.localizedDescription)")
            await MainActor.run { self.isRefreshing = false }
        }
    }
    
    // MARK: - Helper Methods
    
    private func saveUsageToHistory(type: Usage.ServiceType, consumption: Double, cost: Double) {
        let newUsage = Usage(
            pedestalId: pedestal.id,
            serviceType: type,
            startTime: (type == .water ? waterStartTime : electricityStartTime) ?? Date(),
            consumption: consumption,
            cost: cost
        )
        
        UsageHistoryManager.shared.addUsage(newUsage)
    }
    
    
    
    // MARK: - Async Monitoring
    
    // Su veya elektrik aktif olduğu sürece 5 saniyede bir sinyal üreten akış
    private var usageStream: AsyncStream<Void> {
        AsyncStream { continuation in
            let task = Task {
                while !Task.isCancelled {
                    // 5 saniye bekle
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    
                    // Eğer aktif işlem yoksa döngüden çık akışı bitir
                    if !self.isWaterActive && !self.isElectricityActive {
                        continuation.finish()
                        break
                    }
                    
                    // Sinyal gönder
                    continuation.yield()
                }
            }
            
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
    
    // Akışı dinler ve veri günceller
    func monitorUsage() async {
        // Eğer zaten aktif değilse başlatma
        guard isWaterActive || isElectricityActive else { return }
        
        print(" AsyncStream izleme başladı 5 saniye aralıkla")
        
        for await _ in usageStream {
            // Güvenlik kontrolü: Her ikisi de kapalıysa çık
            if !isWaterActive && !isElectricityActive {
                print("AsyncStream izleme durduruldu aktif servis yok")
                break
            }
            
            await refreshPedestalData()
        }
    }
    
    func stopAllServices() {
        // stopPolling() -> Artık yok
        if isWaterActive {
            stopWater()
        }
        if isElectricityActive {
            stopElectricity()
        }
    }
    
    deinit {
        // stopPolling() -> Artık yok
        stopAllServices()
    }
}
