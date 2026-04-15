import SwiftUI

@main
struct mobileApp: App {
    // AuthViewModel zaten sende vardı, koruyoruz.
    @StateObject private var authViewModel = AuthViewModel()
    
    // GlobalUsageManager'ı burada bir kez oluşturuyoruz.
    // Bu sayede uygulama kapanana kadar tüm ViewModel'ler burada yaşar.
    @StateObject private var usageManager = GlobalUsageManager.shared
     
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .environmentObject(usageManager) // Manager'ı tüm uygulamaya yayıyoruz
        }
    }
}

