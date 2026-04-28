import SwiftUI

@main
struct mobileApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var usageManager = GlobalUsageManager.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .environmentObject(usageManager)
                .task(id: authViewModel.isAuthenticated) {
                    guard authViewModel.isAuthenticated else { return }
                    await GlobalUsageManager.shared.syncActiveUsages()
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active, authViewModel.isAuthenticated else { return }
                    Task {
                        await GlobalUsageManager.shared.syncActiveUsages()
                    }
                }
        }
    }
}
