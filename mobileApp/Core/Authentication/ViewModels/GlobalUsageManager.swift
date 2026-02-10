import SwiftUI
import Combine
import Foundation

class GlobalUsageManager: ObservableObject {
    static let shared = GlobalUsageManager()

    @Published var activeViewModels: [Int: PedestalUsageViewModel] = [:]
    private init() {}
    
    func getViewModel(for pedestal: Pedestal) -> PedestalUsageViewModel {
        if let existingVM = activeViewModels[pedestal.id] {
            return existingVM
        }
        
        let newVM = PedestalUsageViewModel(pedestal: pedestal)
        activeViewModels[pedestal.id] = newVM
        return newVM
    }
}
