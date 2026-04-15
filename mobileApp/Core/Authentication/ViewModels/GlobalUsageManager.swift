import SwiftUI
import Combine
import Foundation

class GlobalUsageManager: ObservableObject {
    static let shared = GlobalUsageManager()

    @Published var activeViewModels: [Int: PedestalUsageViewModel] = [:]  // Int: Backend istasyon ID
    
    private let trackedIdsKey = "tracked_pedestal_ids"
    
    private init() {
    }
    
    private func saveTrackedId(_ id: Int) {
        var ids = Set(UserDefaults.standard.array(forKey: trackedIdsKey) as? [Int] ?? [])
        ids.insert(id)
        UserDefaults.standard.set(Array(ids), forKey: trackedIdsKey)
    }
    
    private func getTrackedIds() -> [Int] {
        return UserDefaults.standard.array(forKey: trackedIdsKey) as? [Int] ?? []
    }
    
    func getViewModel(for pedestal: Pedestal) -> PedestalUsageViewModel {
        // Takip edilen ID'yi kaydet
        saveTrackedId(pedestal.id)
        
        // Eğer bu pedestalın sayacı zaten listede varsa (arka planda çalışıyordur), onu ver.
        if let existingVM = activeViewModels[pedestal.id] {
            return existingVM
        }
        
        // Eğer ilk kez açılıyorsa, yeni bir sayaç oluştur ve listeye ekle.
        let newVM = PedestalUsageViewModel(pedestal: pedestal)
        activeViewModels[pedestal.id] = newVM
        return newVM
    }
    
    /// Backend'den aktif kullanımları çekip memory'deki viewmodel'ları senkronize eder
    func syncActiveUsages() async {
        print("syncActiveUsages: Senkronizasyon başlatıldı...")
        do {
            let apiService = ApiService.shared
            
            // 1. Backend'den "kullanılan" ve "boş" listelerini çek (İsimleri doğru almak için)
            print("syncActiveUsages: İstasyon listeleri çekiliyor...")
            let activeFromBackend = (try? await apiService.getKullanilanPedestal()) ?? []
            let allStations = (try? await apiService.getBosIstasyonlar()) ?? []
            
            // 2. Lokal olarak takip edilen ID'leri çek
            let trackedIds = getTrackedIds()
            print("syncActiveUsages: Takip edilen ID'ler: \(trackedIds)")
            
            // Tüm ID'leri birleştir (Backend'den gelenler + Bizim yerel takip ettiklerimiz)
            var allIdsToSync = Set(activeFromBackend.map { $0.istasyonId })
            allIdsToSync.formUnion(trackedIds)
            
            if allIdsToSync.isEmpty {
                print("syncActiveUsages: Senkronize edilecek istasyon bulunamadı.")
                return
            }
            
            print("syncActiveUsages: \(allIdsToSync.count) istasyon için durum sorgulanıyor...")
            
            var syncedIds = Set<Int>()
            
            for pedestalId in allIdsToSync {
                do {
                    // 3. Her istasyon için son durumu (bakiye vb.) çek
                    print(" syncActiveUsages: İstasyon \(pedestalId) için detay çekiliyor...")
                    let istasyonBilgi = try await apiService.getIstasyonSonKayit(istasyonId: pedestalId)
                    
                    // PedestalResponse'u bul (İsim ve konum bilgisi için)
                    let response = activeFromBackend.first(where: { $0.istasyonId == pedestalId }) ??
                                  allStations.first(where: { $0.istasyonId == pedestalId }) ??
                                  PedestalResponse(recId: 0, marinaNo: 1, portAdi: "İstasyon \(pedestalId)", istasyonAdi: "Konum Bilgisi Alınıyor", istasyonId: pedestalId, prizNo: 0, aciklama: nil, aktif: true, silTarih: nil, silKim: nil)
                    
                    let updatedPedestal = Pedestal.fromResponse(response, istasyonBilgi: istasyonBilgi)
                    
                    // KRİTİK: Eğer bakiye 0 ise ve backend aktif demiyorsa bu istasyonu takip etmeyi bırakabiliriz
                    let isActuallyActive = (istasyonBilgi.bakiye ?? 0) > 0 || (istasyonBilgi.su ?? false) || (istasyonBilgi.elektrik ?? false) || activeFromBackend.contains(where: { $0.istasyonId == pedestalId })
                    
                    if !isActuallyActive {
                        print("syncActiveUsages: İstasyon \(pedestalId) artık aktif değil (Bakiye: \(istasyonBilgi.bakiye ?? 0)).")
                        continue
                    }
                    
                    syncedIds.insert(pedestalId)
                    print("syncActiveUsages: İstasyon \(pedestalId) aktif. Bakiye: \(updatedPedestal.balance)")
                    
                    await MainActor.run {
                        if let existingVM = activeViewModels[pedestalId] {
                            existingVM.pedestal = updatedPedestal
                            existingVM.isWaterActive = updatedPedestal.isWaterActive
                            existingVM.isElectricityActive = updatedPedestal.isElectricityActive
                            existingVM.currentWaterUsage = updatedPedestal.waterUsage
                            existingVM.currentElectricityUsage = updatedPedestal.electricityUsage
                        } else {
                            let newVM = PedestalUsageViewModel(pedestal: updatedPedestal)
                            newVM.isWaterActive = updatedPedestal.isWaterActive
                            newVM.isElectricityActive = updatedPedestal.isElectricityActive
                            newVM.currentWaterUsage = updatedPedestal.waterUsage
                            newVM.currentElectricityUsage = updatedPedestal.electricityUsage
                            activeViewModels[pedestalId] = newVM
                            
                            if newVM.isWaterActive || newVM.isElectricityActive {
                                Task { await newVM.monitorUsage() }
                            }
                        }
                    }
                } catch {
                    print("syncActiveUsages: İstasyon \(pedestalId) sorgulanırken hata: \(error.localizedDescription)")
                }
            }
            
            // 4. Takip listesini temizle (Artık aktif olmayanları çıkar)
            await MainActor.run {
                var currentTracked = Set(getTrackedIds())
                // Sadece bizde olup syncedIds'de olmayanları temizle
                for id in currentTracked {
                    if !syncedIds.contains(id) {
                        // Eğer backend listesinde de yoksa ve bakiyesi bittiyse çıkar
                        currentTracked.remove(id)
                    }
                }
                UserDefaults.standard.set(Array(currentTracked), forKey: trackedIdsKey)
                
                // activeViewModels'ı da temizle
                for id in activeViewModels.keys {
                    if !syncedIds.contains(id) {
                        activeViewModels.removeValue(forKey: id)
                    }
                }
            }
            
            print("syncActiveUsages: Tamamlandı. \(syncedIds.count) istasyon gösteriliyor.")
            
        } catch {
            print("syncActiveUsages: Genel hata: \(error)")
        }
    }
}
