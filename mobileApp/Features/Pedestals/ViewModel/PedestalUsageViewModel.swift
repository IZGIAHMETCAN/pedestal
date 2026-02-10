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
                
                await MainActor.run {
                    self.isWaterActive = true
                    self.isLoading = false
                    self.waterStartTime = Date()
                }
                
                try await Task.sleep(nanoseconds: 2_000_000_000)
                await self.refreshPedestalData()
                await MainActor.run { self.startPolling() }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Su açma başarısız: \(error.localizedDescription)"
                    self.isLoading = false
                }
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
                    suElektrik: true,
                    islem: 0
                )
                
                try await apiService.postElektrikSuKontrol(request: request)
                
                await MainActor.run {
                    self.isWaterActive = false
                    self.isLoading = false
                    // Elektrik de kapalıysa polling durdur
                    if !self.isElectricityActive {
                        self.stopPolling()
                    }
                }
                
                try await Task.sleep(nanoseconds: 2_000_000_000)
                await self.refreshPedestalData()
                
            } catch {
                await MainActor.run {
                    self.errorMessage = "Su kapatma başarısız: \(error.localizedDescription)"
                    self.isLoading = false
                }
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
                
                await MainActor.run {
                    self.isElectricityActive = true
                    self.electricityStartTime = Date()
                    self.isLoading = false
                }
                
                // Elektrik açıldıktan sonra veriyi çek ve polling başlat
                try await Task.sleep(nanoseconds: 2_000_000_000)
                await self.refreshPedestalData()
                await MainActor.run { self.startPolling() }
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
                
                await MainActor.run {
                    self.isElectricityActive = false
                    self.isLoading = false
                    // Su da kapalıysa polling durdur
                    if !self.isWaterActive {
                        self.stopPolling()
                    }
                }
                
                try await Task.sleep(nanoseconds: 2_000_000_000)
                await self.refreshPedestalData()
                
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
        
        // Bakiye yüklendikten sonra pedestal bilgilerini güncelle
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
            
            print("Adım 1: GetKullanilanPedestal tetikleniyor...")
            _ = try? await apiService.getKullanilanPedestal()
            
            try await Task.sleep(nanoseconds: 5_000_000_000) // 5 saniye
            
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
            print(" Detay: \(error.localizedDescription)")
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
    
    // MARK: - Polling (Periyodik Güncelleme)
    
    /// Su veya elektrik açıkken 10 saniyede bir backend'den güncel veriyi çeker
    func startPolling() {
        guard pollingTask == nil else { return }
        
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 10_000_000_000) // 5 saniye
                } catch {
                    break // Task iptal edildi
                }
                guard !Task.isCancelled else { break }
                await self?.refreshPedestalData()
            }
        }
    }
    
    func stopPolling() {
        print("Polling durduruldu")
        pollingTask?.cancel()
        pollingTask = nil
    }
    
    func stopAllServices() {
        stopPolling()
        if isWaterActive {
            stopWater()
        }
        if isElectricityActive {
            stopElectricity()
        }
    }
    
    deinit {
        stopPolling()
        stopAllServices()
    }
}
