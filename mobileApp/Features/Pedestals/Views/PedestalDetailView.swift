import SwiftUI

struct PedestalDetailView: View {
    let pedestal: Pedestal
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject private var usageViewModel: PedestalUsageViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var navigateToBalance = false
    @State private var navigateToHistory = false
    @State private var showTransferSheet = false
    @State private var transferAmount = ""
    @State private var isTransferring = false
    @State private var isLoadingRefund = false // İade loading durumu
    @State private var transferError: String? = nil
    @State private var showRefundConfirmation = false // İade onayı için state
    @State private var showWaterConfirmation = false // Su açma/kapama onayı
    @State private var showElectricityConfirmation = false // Elektrik açma/kapama onayı
    
    init(pedestal: Pedestal) {
        self.pedestal = pedestal
        self._usageViewModel = ObservedObject(wrappedValue: GlobalUsageManager.shared.getViewModel(for: pedestal))
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.02, green: 0.12, blue: 0.18),
                    Color(red: 0.01, green: 0.05, blue: 0.1)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 25) {
                    // Pedestal bilgileri
                    pedestalInfoCard
                    
                    // Bakiye kartı
                    balanceCard

                    // Su Kontrolü
                    serviceControlCard(
                        title: "Su",
                        icon: "drop.fill",
                        color: .blue,
                        isActive: usageViewModel.isWaterActive,
                        toggleAction: { showWaterConfirmation = true },
                        usageValue: usageViewModel.currentWaterUsage,
                        unit: "Lt"
                    )
                    .alert(isPresented: $showWaterConfirmation) {
                        Alert(
                            title: Text(usageViewModel.isWaterActive ? "Suyu Kapat" : "Suyu Aç"),
                            message: Text(usageViewModel.isWaterActive ? "Suyu kapatmak istediğinize emin misiniz?" : "Suyu açmak istediğinize emin misiniz?"),
                            primaryButton: .default(Text("Evet")) {
                                usageViewModel.toggleWater()
                            },
                            secondaryButton: .cancel(Text("Hayır"))
                        )
                    }
                    
                    // Elektrik Kontrolü
                    serviceControlCard(
                        title: "Elektrik",
                        icon: "bolt.fill",
                        color: .yellow,
                        isActive: usageViewModel.isElectricityActive,
                        toggleAction: { showElectricityConfirmation = true },
                        usageValue: usageViewModel.currentElectricityUsage,
                        unit: "Watt"
                    )
                    .alert(isPresented: $showElectricityConfirmation) {
                        Alert(
                            title: Text(usageViewModel.isElectricityActive ? "Elektriği Kapat" : "Elektriği Aç"),
                            message: Text(usageViewModel.isElectricityActive ? "Elektriği kapatmak istediğinize emin misiniz?" : "Elektriği açmak istediğinize emin misiniz?"),
                            primaryButton: .default(Text("Evet")) {
                                usageViewModel.toggleElectricity()
                            },
                            secondaryButton: .cancel(Text("Hayır"))
                        )
                    }
                    
                    
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .refreshable {

                print("Pedestal detay sayfası yenileniyor...")
                await usageViewModel.refreshPedestalData()
            }
            .task {

                print("Pedestal detay sayfası açıldı veriler çekiliyor")
                await usageViewModel.refreshPedestalData()
            }
            .task(id: usageViewModel.isWaterActive) {
                // Su durumu değişince izlemeyi tetikle
                if usageViewModel.isWaterActive {
                    await usageViewModel.monitorUsage()
                }
            }
            .task(id: usageViewModel.isElectricityActive) {
                // Elektrik durumu değişince izlemeyi tetikle
                if usageViewModel.isElectricityActive {
                    await usageViewModel.monitorUsage()
                }
            }

        .navigationTitle(pedestal.pedestalNumber)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationDestination(isPresented: $navigateToBalance) {
            BalanceView().environmentObject(authViewModel)
        }
        .navigationDestination(isPresented: $navigateToHistory) {
            UsageHistoryView(pedestalId: pedestal.id)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { navigateToBalance = true }) {
                        Label("Bakiye Yükle", systemImage: "plus.circle.fill")
                    }
                    
                    Button(action: { navigateToHistory = true }) {
                        Label("Kullanım Geçmişi", systemImage: "clock.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .foregroundColor(.cyan)
                }
            }
        }

        .alert("Yetersiz Bakiye", isPresented: $usageViewModel.showLowBalanceAlert) {
            Button("Tamam", role: .cancel) { }
            Button("Bakiye Yükle") {
                navigateToBalance = true
            }
        } message: {
            Text("Bakiyeniz yetersiz. Lütfen bakiye yükleyiniz.")
        }
            // Transfer Sheet
            .sheet(isPresented: $showTransferSheet) {
                stationTransferSheet
            }
            
            // Loading Overlay (İade işlemi sırasında)
            if isLoadingRefund {
                ZStack {
                    Color.black.opacity(0.5).ignoresSafeArea()
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("İade İşlemi Sürüyor...")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(30)
                    .background(Color(red: 0.1, green: 0.1, blue: 0.1).opacity(0.9))
                    .cornerRadius(20)
                    .shadow(radius: 20)
                }
            }
            
            // Loading Overlay (Su/Elektrik işlemi sırasında)
            if usageViewModel.isLoading {
                ZStack {
                    Color.black.opacity(0.5).ignoresSafeArea()
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("İşlem Yapılıyor...")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(30)
                    .background(Color(red: 0.1, green: 0.1, blue: 0.1).opacity(0.9))
                    .cornerRadius(20)
                    .shadow(radius: 20)
                }
            }
        }
    }
    
    // MARK: - Subviews
    private var pedestalInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "poweroutlet.type.k.fill")
                    .font(.title2)
                    .foregroundColor(.cyan)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(pedestal.pedestalNumber)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(pedestal.location)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                Text(pedestal.status.rawValue)
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .cornerRadius(8)
            }
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Su Tarifesi")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                    Text("₺\(pedestal.waterRate, specifier: "%.2f")/m³")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Elektrik Tarifesi")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                    Text("₺\(pedestal.electricityRate, specifier: "%.2f")/kWh")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.yellow)
                }
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var balanceCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("İstasyon Bakiyesi")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("₺\(usageViewModel.pedestal.balance, specifier: "%.2f")")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Yenile Butonu
                Button(action: {
                    Task { await usageViewModel.refreshPedestalData() }
                }) {
                    if usageViewModel.isRefreshing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.title2)
                            .foregroundColor(.cyan.opacity(0.8))
                    }
                }
                .disabled(usageViewModel.isRefreshing)
            }
            
            HStack(spacing: 12) {
                // Pedestal'dan ana hesaba iade
                Button(action: { showRefundConfirmation = true }) {
                    HStack {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                        Text("Bakiye İade Et")
                            .fontWeight(.semibold)
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(usageViewModel.pedestal.balance > 0 ? Color.orange.opacity(0.3) : Color.gray.opacity(0.2))
                    .cornerRadius(12)
                }
                .disabled(usageViewModel.pedestal.balance <= 0)
                .alert("Bakiye İadesi", isPresented: $showRefundConfirmation) {
                    Button("İptal", role: .cancel) { }
                    Button("Evet, İade Et", role: .destructive) {
                        refundPedestalBalance()
                    }
                } message: {
                    Text("İstasyondaki ₺\(usageViewModel.pedestal.balance, specifier: "%.2f") tutarındaki bakiyenin tamamını ana hesabınıza aktarmak istiyor musunuz?")
                }
                
                // İstasyona transfer
                Button(action: { showTransferSheet = true }) {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("İstasyona Aktar")
                            .fontWeight(.semibold)
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.cyan.opacity(0.3))
                    .cornerRadius(12)
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.cyan.opacity(0.3),
                    Color.blue.opacity(0.2)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func serviceControlCard(
        title: String,
        icon: String,
        color: Color,
        isActive: Bool,
        toggleAction: @escaping () -> Void,
        usageValue: Double? = nil,
        unit: String? = nil
    ) -> some View {
        VStack(spacing: 16) {
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        if isActive, let usage = usageValue, let unit = unit {
                            Text(String(format: "%.4f %@", usage, unit))
                                .font(.caption)
                                .foregroundColor(color)
                                .fontWeight(.bold)
                        }
                    }
                }
            
                Spacer()
            
                Button(action: toggleAction) {
                    HStack(spacing: 8) {
                        Image(systemName: isActive ? "stop.circle.fill" : "play.circle.fill")
                        Text(isActive ? "Durdur" : "Başlat")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(isActive ? Color.red : color)
                    .cornerRadius(25)
                }
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
            .stroke(isActive ? color.opacity(0.5) : Color.white.opacity(0.1), lineWidth: isActive ? 2 : 1)
        )
    }
    

    
    

    
    // MARK: - Station Transfer Sheet
    private var stationTransferSheet: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.02, green: 0.12, blue: 0.18),
                        Color(red: 0.01, green: 0.05, blue: 0.1)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Bakiye Bilgisi
                    VStack(spacing: 15) {
                        Text("Ana Hesap Bakiyeniz")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                        Text("₺\(authViewModel.currentUser?.balance ?? 0, specifier: "%.2f")")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.cyan)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(15)
                    
                    // İstasyon Bakiyesi
                    VStack(spacing: 5) {
                        Text("Mevcut İstasyon Bakiyesi")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                        Text("₺\(usageViewModel.pedestal.balance, specifier: "%.2f")")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundColor(.orange)
                    }
                    
                    // Tutar Girişi
                    VStack(alignment: .leading, spacing: 12) {
                        Text("İstasyona Aktarılacak Tutar")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                        
                        TextField("0", text: $transferAmount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(15)
                            .foregroundColor(.white)
                    }
                    
                    // Hızlı Seçim Butonları
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach([10, 20, 50], id: \.self) { amount in
                            Button(action: { transferAmount = "\(amount)" }) {
                                Text("₺\(amount)")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(transferAmount == "\(amount)" ? Color.cyan : Color.white.opacity(0.1))
                                    .cornerRadius(12)
                            }
                        }
                    }
                    
                    if let error = transferError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                    
                    Spacer()
                    
                    // Transfer Butonu
                    Button(action: performTransfer) {
                        ZStack {
                            if isTransferring {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                HStack {
                                    Image(systemName: "arrow.right.circle.fill")
                                    Text("İstasyona Aktar")
                                }
                                .font(.headline)
                                .fontWeight(.bold)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isValidTransferAmount ? Color.cyan : Color.gray.opacity(0.3))
                        .cornerRadius(15)
                    }
                    .disabled(!isValidTransferAmount || isTransferring)
                }
                .padding(25)
            }
            .navigationTitle("Bakiye Aktar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") {
                        showTransferSheet = false
                        transferAmount = ""
                        transferError = nil
                    }
                    .foregroundColor(.cyan)
                }
            }
        }
    }
    
    private var isValidTransferAmount: Bool {
        guard let amount = Double(transferAmount), amount > 0 else { return false }
        guard let userBalance = authViewModel.currentUser?.balance else { return false }
        return amount <= userBalance
    }
    
    private func performTransfer() {
        guard let amount = Double(transferAmount) else { return }
        
        isTransferring = true
        transferError = nil
        
        Task {
            do {
                try await usageViewModel.loadBalanceToStation(amount: amount)
                
                await MainActor.run {
                    // Ana hesaptan düş
                    authViewModel.currentUser?.balance -= amount
                    
                    isTransferring = false
                    showTransferSheet = false
                    transferAmount = ""
                }
            } catch {
                await MainActor.run {
                    transferError = "Transfer başarısız: \(error.localizedDescription)"
                    isTransferring = false
                }
            }
        }
    }
    
    // MARK: - Refund Function
    private func refundPedestalBalance() {
        print("Mevcut pedestal bakiyesi: \(pedestal.balance)")
        
        guard usageViewModel.pedestal.balance > 0 else {
            print("Pedestal bakiyesi 0, iade edilemez")
            return
        }
        
        isLoadingRefund = true // Loading başlat
        
        Task {
            do {
                let oldBalance = usageViewModel.pedestal.balance
                
                try await usageViewModel.refundBalance()
                
                await MainActor.run {
                    // Ana hesaba pedestal bakiyesini ekle
                    let currentUserBalance = authViewModel.currentUser?.balance ?? 0
                    authViewModel.currentUser?.balance = currentUserBalance + oldBalance
                    
                    print("Ana hesap güncellendi: \(currentUserBalance) → \(authViewModel.currentUser?.balance ?? 0)")
                    print("Pedestal verileri yenileniyor...")
                    
                    // İşlem bitti, loading kapat
                    isLoadingRefund = false
                }
            } catch {
                print("Bakiye iadesi başarısız: \(error)")
                print("Hata detayı: \(error.localizedDescription)")
                
                await MainActor.run {
                    isLoadingRefund = false // Hata olsa da kapat
                    
                    // TODO: Alert ile kullanıcıya göster
                    let errorMessage = "Bakiye iadesi başarısız: \(error.localizedDescription)"
                    print("Kullanıcıya gösterilecek hata: \(errorMessage)")
                }
            }
        }
    }
}

