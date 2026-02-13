import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var globalUsageManager = GlobalUsageManager.shared
    
    // UI Kontrolleri
    @State private var showMenu = false
    @State private var isScanning = false
    
    // Navigasyon State'leri
    @State private var navigateToBalance = false
    @State private var navigateToEditProfile = false
    @State private var navigateToAddCard = false
    @State private var navigateToHistory = false
    @State private var navigateToPedestals = false
    @State private var selectedPedestalId: Int?
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // 1. Arka Plan
                Color(red: 0.01, green: 0.05, blue: 0.1)
                    .ignoresSafeArea()
                
                // 2. Ana İçerik
                ScrollView {
                    VStack(spacing: 30) {
                        headerSection
                            .padding(.top, 40)
                        
                        if let user = authViewModel.currentUser {
                            balanceCard(user: user)
                        }
                        
                        // Aktif Kullanımlar Bölümü
                        if hasActiveUsage {
                            activeUsageSection
                                .padding(.horizontal, 25)
                        }
                        
                        Spacer(minLength: 100) // Alt bar için boşluk
                    }
                }
                .refreshable {
                    print("Ana sayfa yenileniyor...")
                    await authViewModel.refreshBalance()
                }
                .task {
                    // Auth state'in yüklenmesini bekle (Race condition önlemi)
                                        var retryCount = 0
                                        while !authViewModel.isAuthenticated && retryCount < 10 {
                                            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2sn
                                            retryCount += 1
                                        }
                                        
                                        print("🏠 HomeView: Başlangıç güncelleniyor... (Auth: \(authViewModel.isAuthenticated))")
                                        
                                        if authViewModel.isAuthenticated {
                                            await authViewModel.refreshBalance()
                                            await GlobalUsageManager.shared.syncActiveUsages()
                                        }
                }
                
                
                customBottomBar
                
                // Side Menu Overlay
                if showMenu { sideMenuOverlay }
            }
            // MARK: - Navigasyon Hedefleri
            .navigationDestination(isPresented: $navigateToPedestals) {
                PedestalListView()
            }
            .navigationDestination(isPresented: $navigateToBalance) {
                BalanceView().environmentObject(authViewModel)
            }
            .navigationDestination(isPresented: $navigateToEditProfile) {
                if let user = authViewModel.currentUser {
                    EditProfileView(user: user).environmentObject(authViewModel)
                }
            }
            .navigationDestination(isPresented: $navigateToAddCard) {
                AddCardView().environmentObject(authViewModel)
            }
            .navigationDestination(isPresented: $navigateToHistory) {
                HistoryView().environmentObject(authViewModel)
            }
            .navigationDestination(isPresented: Binding(
                get: { selectedPedestalId != nil },
                set: { if !$0 { selectedPedestalId = nil } }
            )) {
                if let pedestalId = selectedPedestalId {
                    // QR kod okutulunca direkt pedestal detayına git
                    QRPedestalDetailLoader(pedestalId: pedestalId)
                        .environmentObject(authViewModel)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { withAnimation(.spring()) { showMenu.toggle() } }) {
                        Image(systemName: "line.3.horizontal.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $isScanning) {
                scannerSheet
            }
        }
    }
    
    // MARK: - Aktif Kullanım Kontrolü
    private var hasActiveUsage: Bool {
            !globalUsageManager.activeViewModels.values.filter { $0.pedestal.balance > 0 }.isEmpty
        }
    
    // MARK: - Aktif Kullanımlar Bölümü
    private var activeUsageSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                            Image(systemName: "bolt.circle.fill")
                                .font(.title3)
                                .foregroundColor(.cyan)
                            Text("Aktif Kullanımlar")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        .padding(.bottom, 5)
                        
                        VStack(spacing: 12) {
                            ForEach(Array(globalUsageManager.activeViewModels.values.filter { $0.pedestal.balance > 0 }), id: \.pedestal.id) { viewModel in
                                ActiveUsageCard(viewModel: viewModel) {
                                    selectedPedestalId = viewModel.pedestal.id
                                }
                            }
                        }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Özel Alt Bar Tasarımı
    private var customBottomBar: some View {
        HStack {
            // SOL: History (Geçmiş)
            Button(action: { navigateToHistory = true }) {
                VStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 24))
                    Text("Geçmiş").font(.caption2)
                }
                .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            
            // ORTA: Büyük QR Butonu
            Button(action: { isScanning = true }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22)
                        .fill(LinearGradient(gradient: Gradient(colors: [Color.cyan, Color.blue]), startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 75, height: 75)
                        .shadow(color: .cyan.opacity(0.5), radius: 12, y: 8)
                    
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 35, weight: .bold))
                        .foregroundColor(.white)
                }
                .offset(y: -25) // Çubuğun dışına taşma efekti
            }
            .frame(maxWidth: .infinity)
            
            // SAĞ: Edit Profile (Profil)
            Button(action: { navigateToEditProfile = true }) {
                VStack(spacing: 4) {
                    Image(systemName: "person.circle")
                        .font(.system(size: 24))
                    Text("Profil").font(.caption2)
                }
                .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 30)
        .background(
            Color.black.opacity(0.4)
                .background(.ultraThinMaterial)
                .cornerRadius(35)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }
    
    // MARK: - Yardımcı Alt Bileşenler
    private var headerSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "bolt.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.cyan)
                .shadow(color: .cyan.opacity(0.3), radius: 15)
            
            VStack(spacing: 8) {
                Text("Hoş Geldiniz").foregroundColor(.white.opacity(0.7))
                if let user = authViewModel.currentUser {
                    Text(user.name).font(.largeTitle).fontWeight(.bold).foregroundColor(.white)
                }
            }
        }
    }
    
    private func balanceCard(user: User) -> some View {
        VStack(spacing: 20) {
            VStack(spacing: 15) {
                Text("Mevcut Bakiyeniz").font(.headline).foregroundColor(.white.opacity(0.8))
                Text("₺\(user.balance, specifier: "%.2f")").font(.system(size: 40, weight: .bold, design: .rounded)).foregroundColor(.white)
                Button(action: { navigateToBalance = true }) {
                    Text("Bakiye Yükle").fontWeight(.bold).padding(.horizontal, 40).padding(.vertical, 10)
                        .background(Color.white.opacity(0.2)).foregroundColor(.white).cornerRadius(25)
                        .overlay(RoundedRectangle(cornerRadius: 25).stroke(Color.white.opacity(0.3), lineWidth: 1))
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 30)
            .background(LinearGradient(gradient: Gradient(colors: [Color.cyan.opacity(0.6), Color.blue.opacity(0.4)]), startPoint: .topLeading, endPoint: .bottomTrailing))
            .cornerRadius(30).padding(.horizontal, 25)
            
            }
    }

    private var sideMenuOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea().onTapGesture { withAnimation { showMenu = false } }
            HStack {
                SideMenuView(isShowing: $showMenu, editProfileAction: { navigateToEditProfile = true }, addCardAction: { navigateToAddCard = true }, historyAction: { navigateToHistory = true }, logoutAction: { authViewModel.signOut() })
                    .environmentObject(authViewModel).transition(.move(edge: .leading))
                Spacer()
            }
        }.zIndex(2)
    }

    private var scannerSheet: some View {
        ZStack {
            QRCodeScannerView { result in
                // QR koddan gelen değer istasyon ID'si olmalı (Int)
                if let pedestalId = Int(result) {
                    self.selectedPedestalId = pedestalId
                    self.isScanning = false
                    // Navigasyon tetiklenir
                }
            }
            .ignoresSafeArea()
            
            Color.black.opacity(0.5)
                .mask(ZStack {
                    Color.black
                    RoundedRectangle(cornerRadius: 30).frame(width: 260, height: 260).blendMode(.destinationOut)
                }).ignoresSafeArea()

            VStack {
                HStack {
                    Text("QR Tara").font(.headline).foregroundColor(.white)
                    Spacer()
                    Button(action: { isScanning = false }) {
                        Image(systemName: "xmark.circle.fill").font(.title).foregroundColor(.white.opacity(0.7))
                    }
                }.padding(25)
                Spacer()
                ZStack {
                    ScannerCornerShape().stroke(LinearGradient(gradient: Gradient(colors: [.cyan, .blue]), startPoint: .top, endPoint: .bottom), lineWidth: 4).frame(width: 260, height: 260)
                    ScanningLineView()
                }
                Spacer()
                Text("Pedestal üzerindeki kodu çerçeveye hizalayın").font(.body).foregroundColor(.white.opacity(0.7)).padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Aktif Kullanım Kartı
struct ActiveUsageCard: View {
    @ObservedObject var viewModel: PedestalUsageViewModel
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 15) {
                // Sol: Pedestal İkonu ve Bilgi
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "ev.plug.ac.gb.t.fill")
                            .font(.title2)
                            .foregroundColor(.cyan)
                        
                        Text(viewModel.pedestal.pedestalNumber)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    
                    Text(viewModel.pedestal.location)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                // Sağ: Aktif Hizmetler
                VStack(alignment: .trailing, spacing: 8) {
                    if viewModel.isWaterActive {
                        HStack(spacing: 6) {
                            Image(systemName: "drop.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text(String(format: "%.1f m³", viewModel.currentWaterUsage))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(12)
                    }
                    
                    if viewModel.isElectricityActive {
                        HStack(spacing: 6) {
                            Image(systemName: "bolt.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f kWh", viewModel.currentElectricityUsage))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.yellow.opacity(0.2))
                        .cornerRadius(12)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.cyan.opacity(0.3), Color.blue.opacity(0.3)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Tasarım Şekilleri (Dosya sonunda kalmalı)
struct ScannerCornerShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let len: CGFloat = 40
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + len)); path.addLine(to: CGPoint(x: rect.minX, y: rect.minY)); path.addLine(to: CGPoint(x: rect.minX + len, y: rect.minY))
        path.move(to: CGPoint(x: rect.maxX - len, y: rect.minY)); path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY)); path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + len))
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY - len)); path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY)); path.addLine(to: CGPoint(x: rect.minX + len, y: rect.maxY))
        path.move(to: CGPoint(x: rect.maxX - len, y: rect.maxY)); path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY)); path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - len))
        return path
    }
}

struct ScanningLineView: View {
    @State private var move = false
    var body: some View {
        Rectangle()
            .fill(LinearGradient(gradient: Gradient(colors: [.clear, .cyan, .clear]), startPoint: .leading, endPoint: .trailing))
            .frame(width: 240, height: 2)
            .offset(y: move ? 120 : -120)
            .onAppear { withAnimation(.linear(duration: 2).repeatForever(autoreverses: true)) { move = true } }
    }
}
