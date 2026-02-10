import SwiftUI
import Combine

class PedestalViewModel: ObservableObject {
    @Published var pedestals: [Pedestal] = []
    @Published var filteredPedestals: [Pedestal] = []
    @Published var searchText: String = ""
    @Published var selectedStatus: Pedestal.Status? = nil
    @Published var selectedLocation: String? = nil
    @Published var showWaterOnly: Bool = false
    @Published var showElectricityOnly: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    private var cancellables = Set<AnyCancellable>()
    private let apiService = ApiService.shared
    private var refreshTimer: Timer?
    
    init() {
        setupFiltering()
        loadPedestals()
        startAutoRefresh()
    }
    
    deinit {
        stopAutoRefresh()
    }
    
    func startAutoRefresh() {
        stopAutoRefresh() // Varsa öncekini durdur
        
        // Her 15 saniyede bir verileri yenile
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            print("Otomatik veri yenileme çalışıyor...")
            self?.loadPedestals()
        }
    }
    
    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    // MARK: - API Methods
    
    func loadPedestals() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Kullanılan pedestal'ları çek
                let pedestalResponses = try await apiService.getKullanilanPedestal()
                
                // Her pedestal için detay bilgisi çek
                var loadedPedestals: [Pedestal] = []
                
                for response in pedestalResponses {
                    do {
                        let istasyonBilgi = try await apiService.getIstasyonSonKayit(istasyonId: response.istasyonId)
                        let pedestal = Pedestal.fromResponse(response, istasyonBilgi: istasyonBilgi)
                        loadedPedestals.append(pedestal)
                    } catch {
                        // Detay bilgisi alınamazsa sadece temel bilgilerle oluştur
                        let pedestal = Pedestal.fromResponse(response)
                        loadedPedestals.append(pedestal)
                    }
                }
                
                // Eğer hiç kullanılan pedestal yoksa, boş pedestal'ları göster
                if loadedPedestals.isEmpty {
                    let bosPedestals = try await apiService.getBosIstasyonlar()
                    loadedPedestals = bosPedestals.map { Pedestal.fromResponse($0) }
                }
                
                await MainActor.run {
                    self.pedestals = loadedPedestals
                    self.filteredPedestals = loadedPedestals
                    self.isLoading = false
                }
                
            } catch {
                await MainActor.run {
                    if let apiError = error as? APIError {
                        self.errorMessage = apiError.errorDescription
                    } else {
                        self.errorMessage = "Pedestal listesi yüklenemedi: \(error.localizedDescription)"
                    }
                    self.isLoading = false
                }
            }
        }
    }
    
    func loadAvailablePedestals() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let bosPedestals = try await apiService.getBosIstasyonlar()
                let loadedPedestals = bosPedestals.map { Pedestal.fromResponse($0) }
                
                await MainActor.run {
                    self.pedestals = loadedPedestals
                    self.filteredPedestals = loadedPedestals
                    self.isLoading = false
                }
                
            } catch {
                await MainActor.run {
                    if let apiError = error as? APIError {
                        self.errorMessage = apiError.errorDescription
                    } else {
                        self.errorMessage = "Boş pedestal listesi yüklenemedi: \(error.localizedDescription)"
                    }
                    self.isLoading = false
                }
            }
        }
    }
    
    func refreshPedestalDetail(pedestalId: Int) async -> Pedestal? {
        do {
            let istasyonBilgi = try await apiService.getIstasyonSonKayit(istasyonId: pedestalId)
            
            // Mevcut pedestal'ı bul ve güncelle
            if let index = pedestals.firstIndex(where: { $0.id == pedestalId }) {
                let response = PedestalResponse(
                    recId: 0, // Placeholder
                    marinaNo: 0, // Placeholder
                    portAdi: pedestals[index].pedestalNumber,
                    istasyonAdi: pedestals[index].location,
                    istasyonId: pedestalId,
                    prizNo: 0, // Placeholder
                    aciklama: nil,
                    aktif: true, // Varsayılan aktif varsayalım
                    silTarih: nil,
                    silKim: nil
                )
                let updatedPedestal = Pedestal.fromResponse(response, istasyonBilgi: istasyonBilgi)
                
                await MainActor.run {
                    self.pedestals[index] = updatedPedestal
                }
                
                return updatedPedestal
            }
            
        } catch {
            print("Pedestal detay yenileme hatası: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Filtering
    
    private func setupFiltering() {
        Publishers.CombineLatest4(
            $searchText,
            $selectedStatus,
            $showWaterOnly,
            $showElectricityOnly
        )
        .map { [weak self] searchText, status, waterOnly, electricityOnly in
            guard let self = self else { return [] }
            
            return self.pedestals.filter { pedestal in
                // Arama filtresi
                let matchesSearch = searchText.isEmpty ||
                    pedestal.pedestalNumber.localizedCaseInsensitiveContains(searchText) ||
                    pedestal.location.localizedCaseInsensitiveContains(searchText)
                
                // Durum filtresi
                let matchesStatus = status == nil || pedestal.status == status
                
                // Su filtresi (aktif olan veya müsait olan)
                let matchesWater = !waterOnly || pedestal.isWaterActive || pedestal.status == .available
                
                // Elektrik filtresi
                let matchesElectricity = !electricityOnly || pedestal.isElectricityActive || pedestal.status == .available
                
                return matchesSearch && matchesStatus && matchesWater && matchesElectricity
            }
        }
        .assign(to: \.filteredPedestals, on: self)
        .store(in: &cancellables)
    }
    
    func toggleWaterFilter() {
        showWaterOnly.toggle()
    }
    
    func toggleElectricityFilter() {
        showElectricityOnly.toggle()
    }
    
    func clearFilters() {
        searchText = ""
        selectedStatus = nil
        selectedLocation = nil
        showWaterOnly = false
        showElectricityOnly = false
    }
    
    // Benzersiz lokasyonları getir (filtreleme için)
    var uniqueLocations: [String] {
        Array(Set(pedestals.map { $0.location })).sorted()
    }
    
    // İstatistikler
    var statistics: (available: Int, occupied: Int, maintenance: Int, inUse: Int) {
        let available = pedestals.filter { $0.status == .available }.count
        let occupied = pedestals.filter { $0.status == .occupied }.count
        let maintenance = pedestals.filter { $0.status == .maintenance }.count
        let inUse = pedestals.filter { $0.status == .inUse }.count
        
        return (available, occupied, maintenance, inUse)
    }
}
