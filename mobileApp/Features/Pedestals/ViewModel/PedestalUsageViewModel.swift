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

    var usageHistory: [Usage] {
        UsageHistoryManager.shared.getUsageHistory(for: pedestal.id)
    }

    var totalCost: Double {
        currentWaterCost + currentElectricityCost
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

    // MARK: - Monitoring Control

    func startMonitoringIfNeeded() {
        guard pollingTask == nil else { return }
        pollingTask = Task { [weak self] in
            await self?.monitorUsage()
        }
    }

    func stopMonitoring() {
        pollingTask?.cancel()
        pollingTask = nil
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
                    suElektrik: true,
                    islem: 1
                )

                try await apiService.postElektrikSuKontrol(request: request)
                await self.refreshPedestalData()

                await MainActor.run {
                    self.isWaterActive = true
                    self.isLoading = false
                    self.waterStartTime = Date()
                    self.startWaterMeterValue = self.currentWaterUsage
                }

                self.startMonitoringIfNeeded()

                try await Task.sleep(nanoseconds: 2_000_000_000)
                await self.refreshPedestalData()
            } catch {
                await MainActor.run {
                    self.errorMessage = "Su açma başarısız: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    func toggleWaterAsync() async -> Bool {
        let currentBalance = pedestal.balance

        if isWaterActive {
            isLoading = true
            do {
                let request = ElektrikSuKontrolRequest(
                    istasyonId: pedestal.id,
                    kartId: pedestal.kartId ?? "",
                    suElektrik: true,
                    islem: 0
                )

                try await apiService.postElektrikSuKontrol(request: request)
                try await Task.sleep(nanoseconds: 2_000_000_000)
                await self.refreshPedestalData()

                await MainActor.run {
                    self.isWaterActive = false
                    self.isLoading = false

                    if let startVal = self.startWaterMeterValue {
                        let endVal = self.currentWaterUsage
                        let consumption = max(0, endVal - startVal)
                        let cost = consumption * (self.pedestal.waterRate > 0 ? self.pedestal.waterRate : 10.0) / 1000.0
                        self.saveUsageToHistory(type: .water, consumption: consumption, cost: cost)
                    }
                    self.startWaterMeterValue = nil
                }

                if !isElectricityActive { stopMonitoring() }
                return true
            } catch {
                await MainActor.run {
                    self.errorMessage = "Su kapatma başarısız: \(error.localizedDescription)"
                    self.isLoading = false
                }
                return false
            }
        } else {
            guard currentBalance >= 1.0 else {
                await MainActor.run { self.showLowBalanceAlert = true }
                return false
            }

            isLoading = true
            do {
                let request = ElektrikSuKontrolRequest(
                    istasyonId: pedestal.id,
                    kartId: pedestal.kartId ?? "",
                    suElektrik: true,
                    islem: 1
                )

                try await apiService.postElektrikSuKontrol(request: request)
                await self.refreshPedestalData()

                await MainActor.run {
                    self.isWaterActive = true
                    self.isLoading = false
                    self.waterStartTime = Date()
                    self.startWaterMeterValue = self.currentWaterUsage
                }

                self.startMonitoringIfNeeded()

                try await Task.sleep(nanoseconds: 2_000_000_000)
                await self.refreshPedestalData()
                return true
            } catch {
                await MainActor.run {
                    self.errorMessage = "Su açma başarısız: \(error.localizedDescription)"
                    self.isLoading = false
                }
                return false
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
                try await Task.sleep(nanoseconds: 2_000_000_000)
                await self.refreshPedestalData()

                await MainActor.run {
                    self.isWaterActive = false
                    self.isLoading = false

                    if let startVal = self.startWaterMeterValue {
                        let endVal = self.currentWaterUsage
                        let consumption = max(0, endVal - startVal)
                        let cost = consumption * (self.pedestal.waterRate > 0 ? self.pedestal.waterRate : 10.0) / 1000.0
                        self.saveUsageToHistory(type: .water, consumption: consumption, cost: cost)
                    }

                    self.startWaterMeterValue = nil
                }

                if !isElectricityActive { stopMonitoring() }
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
                    suElektrik: false,
                    islem: 1
                )

                try await apiService.postElektrikSuKontrol(request: request)
                await self.refreshPedestalData()

                await MainActor.run {
                    self.isElectricityActive = true
                    self.electricityStartTime = Date()
                    self.isLoading = false
                    self.startElectricityMeterValue = self.currentElectricityUsage
                }

                self.startMonitoringIfNeeded()

                try await Task.sleep(nanoseconds: 2_000_000_000)
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
                try await Task.sleep(nanoseconds: 2_000_000_000)
                await self.refreshPedestalData()

                await MainActor.run {
                    self.isElectricityActive = false
                    self.isLoading = false

                    if let startVal = self.startElectricityMeterValue {
                        let endVal = self.currentElectricityUsage
                        let consumption = max(0, endVal - startVal)
                        let cost = consumption * (self.pedestal.electricityRate > 0 ? self.pedestal.electricityRate : 5.0)
                        self.saveUsageToHistory(type: .electricity, consumption: consumption, cost: cost)
                    }

                    self.startElectricityMeterValue = nil
                }

                if !isWaterActive { stopMonitoring() }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Elektrik kapatma başarısız: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    func toggleElectricityAsync() async -> Bool {
        let currentBalance = pedestal.balance

        if isElectricityActive {
            isLoading = true
            do {
                let request = ElektrikSuKontrolRequest(
                    istasyonId: pedestal.id,
                    kartId: pedestal.kartId ?? "",
                    suElektrik: false,
                    islem: 0
                )

                try await apiService.postElektrikSuKontrol(request: request)
                try await Task.sleep(nanoseconds: 2_000_000_000)
                await self.refreshPedestalData()

                await MainActor.run {
                    self.isElectricityActive = false
                    self.isLoading = false

                    if let startVal = self.startElectricityMeterValue {
                        let endVal = self.currentElectricityUsage
                        let consumption = max(0, endVal - startVal)
                        let cost = consumption * (self.pedestal.electricityRate > 0 ? self.pedestal.electricityRate : 5.0)
                        self.saveUsageToHistory(type: .electricity, consumption: consumption, cost: cost)
                    }
                    self.startElectricityMeterValue = nil
                }

                if !isWaterActive { stopMonitoring() }
                return true
            } catch {
                await MainActor.run {
                    self.errorMessage = "Elektrik kapatma başarısız: \(error.localizedDescription)"
                    self.isLoading = false
                }
                return false
            }
        } else {
            guard currentBalance >= 10.0 else {
                await MainActor.run { self.showLowBalanceAlert = true }
                return false
            }

            isLoading = true
            do {
                let request = ElektrikSuKontrolRequest(
                    istasyonId: pedestal.id,
                    kartId: pedestal.kartId ?? "",
                    suElektrik: false,
                    islem: 1
                )

                try await apiService.postElektrikSuKontrol(request: request)
                await self.refreshPedestalData()

                await MainActor.run {
                    self.isElectricityActive = true
                    self.electricityStartTime = Date()
                    self.isLoading = false
                    self.startElectricityMeterValue = self.currentElectricityUsage
                }

                self.startMonitoringIfNeeded()

                try await Task.sleep(nanoseconds: 2_000_000_000)
                await self.refreshPedestalData()
                return true
            } catch {
                await MainActor.run {
                    self.errorMessage = "Elektrik açma başarısız: \(error.localizedDescription)"
                    self.isLoading = false
                }
                return false
            }
        }
    }

    // MARK: - Balance Operations

    func loadBalanceToStation(amount: Double) async throws {
        // Önce gerçek kartId'yi al
        let kartlar = try await apiService.getKullaniciKartlari()
        
        guard let gercekKartId = kartlar.first?.kartId else {
            throw APIError.serverError("Kart bulunamadı")
        }
        
        let request = BakiyeIstasyonRequest(
            istasyonId: pedestal.id,
            kartId: gercekKartId,   
            amount: amount,
            currency: "EURO"
        )

        try await apiService.postBakiyeIstasyon(request: request)
        await refreshPedestalData()
    }

    func refundBalance() async throws {
        // Önce gerçek kartId'yi al
        let kartlar = try await apiService.getKullaniciKartlari()
        guard let gercekKartId = kartlar.first?.kartId else {
            throw APIError.serverError("Kart bulunamadı")
        }
        
        let request = BakiyeIadeRequest(
            istasyonId: pedestal.id,
            kartId: gercekKartId  // ← gerçek kartId
        )
        try await apiService.postBakiyeIade(request: request)
        await refreshPedestalData()
    }

    func refreshPedestalData() async {
        await MainActor.run { self.isRefreshing = true }

        do {
            _ = try? await apiService.getKullanilanPedestal()
            try await Task.sleep(nanoseconds: 2_000_000_000)

            let istasyonBilgi = try await apiService.getIstasyonSonKayit(istasyonId: pedestal.id)

            await MainActor.run {
                if let bakiye = istasyonBilgi.bakiye {
                    self.pedestal.balance = bakiye
                }

                self.isWaterActive = istasyonBilgi.su ?? false
                self.isElectricityActive = istasyonBilgi.elektrik ?? false

                if let suTuketim = istasyonBilgi.litreTuketim {
                    self.currentWaterUsage = suTuketim
                }

                if let elektrikTuketim = istasyonBilgi.elektrikTuketim {
                    self.currentElectricityUsage = elektrikTuketim
                }

                self.isRefreshing = false
            }

            if isWaterActive || isElectricityActive {
                startMonitoringIfNeeded()
            } else {
                stopMonitoring()
            }

        } catch {
            await MainActor.run { self.isRefreshing = false }
        }
    }

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

    private var usageStream: AsyncStream<Void> {
        AsyncStream { continuation in
            let task = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 5_000_000_000)

                    if !self.isWaterActive && !self.isElectricityActive {
                        continuation.finish()
                        break
                    }

                    continuation.yield()
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func monitorUsage() async {
        guard isWaterActive || isElectricityActive else {
            stopMonitoring()
            return
        }

        for await _ in usageStream {
            if Task.isCancelled { break }
            if !isWaterActive && !isElectricityActive { break }
            await refreshPedestalData()
        }

        stopMonitoring()
    }

    func stopAllServices() {
        if isWaterActive { stopWater() }
        if isElectricityActive { stopElectricity() }
    }

    deinit {
        // KRITIK FIX: deinit sırasında backend'e kapatma isteği atma
        pollingTask?.cancel()
        pollingTask = nil
    }
}
