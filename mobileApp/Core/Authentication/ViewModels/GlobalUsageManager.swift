import SwiftUI
import Combine
import Foundation

class GlobalUsageManager: ObservableObject {
    static let shared = GlobalUsageManager()

    @Published var activeViewModels: [Int: PedestalUsageViewModel] = [:]

    private var trackedIdsKey: String {
        let rawEmail = UserDefaults.standard.string(forKey: "currentUserEmail") ?? "guest"
        let normalized = rawEmail.lowercased().replacingOccurrences(of: " ", with: "_")
        return "tracked_pedestal_ids_\(normalized)"
    }

    private init() {}

    func clearInMemory() {
        Task { @MainActor in
            self.activeViewModels.removeAll()
        }
    }

    private func saveTrackedId(_ id: Int) {
        var ids = Set(UserDefaults.standard.array(forKey: trackedIdsKey) as? [Int] ?? [])
        ids.insert(id)
        UserDefaults.standard.set(Array(ids), forKey: trackedIdsKey)
    }

    private func getTrackedIds() -> [Int] {
        UserDefaults.standard.array(forKey: trackedIdsKey) as? [Int] ?? []
    }

    func getViewModel(for pedestal: Pedestal) -> PedestalUsageViewModel {
        saveTrackedId(pedestal.id)

        if let existingVM = activeViewModels[pedestal.id] {
            return existingVM
        }

        let newVM = PedestalUsageViewModel(pedestal: pedestal)
        activeViewModels[pedestal.id] = newVM
        if newVM.isWaterActive || newVM.isElectricityActive {
            newVM.startMonitoringIfNeeded()
        }
        return newVM
    }

    func syncActiveUsages() async {
        do {
            let apiService = ApiService.shared

            let activeFromBackend = (try? await apiService.getKullanilanPedestal()) ?? []
            let allStations = (try? await apiService.getBosIstasyonlar()) ?? []

            let trackedIds = getTrackedIds()

            var allIdsToSync = Set(activeFromBackend.map { $0.istasyonId })
            allIdsToSync.formUnion(trackedIds)

            if allIdsToSync.isEmpty { return }

            var syncedIds = Set<Int>()
            var explicitlyInactiveIds = Set<Int>()   // Kesin inaktif doğrulananlar
            var failedIds = Set<Int>()               // Geçici hatalar

            for pedestalId in allIdsToSync {
                do {
                    let istasyonBilgi = try await apiService.getIstasyonSonKayit(istasyonId: pedestalId)

                    let response = activeFromBackend.first(where: { $0.istasyonId == pedestalId }) ??
                        allStations.first(where: { $0.istasyonId == pedestalId }) ??
                        PedestalResponse(
                            recId: 0,
                            marinaNo: 1,
                            portAdi: "İstasyon \(pedestalId)",
                            istasyonAdi: "Konum Bilgisi Alınıyor",
                            istasyonId: pedestalId,
                            prizNo: 0,
                            aciklama: nil,
                            aktif: true,
                            silTarih: nil,
                            silKim: nil
                        )

                    let updatedPedestal = Pedestal.fromResponse(response, istasyonBilgi: istasyonBilgi)

                    let isActuallyActive =
                        (istasyonBilgi.bakiye ?? 0) > 0 ||
                        (istasyonBilgi.su ?? false) ||
                        (istasyonBilgi.elektrik ?? false) ||
                        activeFromBackend.contains(where: { $0.istasyonId == pedestalId })

                    if !isActuallyActive {
                        explicitlyInactiveIds.insert(pedestalId)
                        continue
                    }

                    syncedIds.insert(pedestalId)

                    await MainActor.run {
                        if let existingVM = activeViewModels[pedestalId] {
                            existingVM.pedestal = updatedPedestal
                            existingVM.isWaterActive = updatedPedestal.isWaterActive
                            existingVM.isElectricityActive = updatedPedestal.isElectricityActive
                            existingVM.currentWaterUsage = updatedPedestal.waterUsage
                            existingVM.currentElectricityUsage = updatedPedestal.electricityUsage
                            if existingVM.isWaterActive || existingVM.isElectricityActive {
                                existingVM.startMonitoringIfNeeded()
                            } else {
                                existingVM.stopMonitoring()
                            }
                        } else {
                            let newVM = PedestalUsageViewModel(pedestal: updatedPedestal)
                            newVM.isWaterActive = updatedPedestal.isWaterActive
                            newVM.isElectricityActive = updatedPedestal.isElectricityActive
                            newVM.currentWaterUsage = updatedPedestal.waterUsage
                            newVM.currentElectricityUsage = updatedPedestal.electricityUsage
                            activeViewModels[pedestalId] = newVM

                            if newVM.isWaterActive || newVM.isElectricityActive {
                                newVM.startMonitoringIfNeeded()
                            }
                        }
                    }
                } catch {
                    failedIds.insert(pedestalId)
                }
            }

            await MainActor.run {
                var currentTracked = Set(getTrackedIds())

                // Sadece kesin inaktif olanları sil
                currentTracked.subtract(explicitlyInactiveIds)
                UserDefaults.standard.set(Array(currentTracked), forKey: trackedIdsKey)

                // Geçici hata alanları SAKLA, silme
                for id in explicitlyInactiveIds where !failedIds.contains(id) {
                    activeViewModels[id]?.stopMonitoring()
                    activeViewModels.removeValue(forKey: id)
                }
            }
        } catch {
            // global hata: hiçbir şey silme
        }
    }
}
