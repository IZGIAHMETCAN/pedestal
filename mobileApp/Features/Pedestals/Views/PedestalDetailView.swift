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
    
    // Su/Elektrik işlem bildirimleri
    @State private var showWaterSuccessAlert = false
    @State private var showWaterErrorAlert = false
    @State private var showElectricitySuccessAlert = false
    @State private var showElectricityErrorAlert = false
    @State private var waterAlertMessage: String = ""
    @State private var electricityAlertMessage: String = ""
    
    // Başarı/Başarısız bildirimleri için
    @State private var showTransferSuccessAlert = false
    @State private var showTransferErrorAlert = false
    @State private var showRefundSuccessAlert = false
    @State private var showRefundErrorAlert = false
    @State private var alertErrorMessage: String = ""
    
    // DEĞİŞİKLİK 2: Init içinde GlobalUsageManager'ı bağlıyoruz
    init(pedestal: Pedestal) {
        self.pedestal = pedestal
        // Manager'dan bu pedestal için çalışan (veya yeni) beyni alıyoruz
        self._usageViewModel = ObservedObject(wrappedValue: GlobalUsageManager.shared.getViewModel(for: pedestal))
    }
    
    var body: some View {
        contentWithEffects
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
            .sheet(isPresented: $showTransferSheet) {
                stationTransferSheet
            }
    }
    
    private var contentWithEffects: some View {
        content
            .alert("Yetersiz Bakiye", isPresented: $usageViewModel.showLowBalanceAlert) {
                Button("Tamam", role: .cancel) { }
                Button("Bakiye Yükle") { navigateToBalance = true }
            } message: {
                Text("Bakiyeniz yetersiz. Lütfen bakiye yükleyiniz.")
            }
            .alert("İşlem Başarılı", isPresented: $showTransferSuccessAlert) {
                Button("Tamam", role: .cancel) { }
            } message: {
                Text("Bakiye başarıyla istasyona aktarıldı.")
            }
            .alert("İşlem Başarısız", isPresented: $showTransferErrorAlert) {
                Button("Tamam", role: .cancel) { }
            } message: {
                Text("Transfer işlemi başarısız oldu. \(alertErrorMessage)")
            }
            .alert("İşlem Başarılı", isPresented: $showRefundSuccessAlert) {
                Button("Tamam", role: .cancel) { }
            } message: {
                Text("Bakiye başarıyla ana hesabınıza iade edildi.")
            }
            .alert("İşlem Başarısız", isPresented: $showRefundErrorAlert) {
                Button("Tamam", role: .cancel) { }
            } message: {
                Text("İade işlemi başarısız oldu. \(alertErrorMessage)")
            }
            .alert("İşlem Başarılı", isPresented: $showWaterSuccessAlert) {
                Button("Tamam", role: .cancel) { }
            } message: {
                Text(waterAlertMessage)
            }
            .alert("İşlem Başarısız", isPresented: $showWaterErrorAlert) {
                Button("Tamam", role: .cancel) { }
            } message: {
                Text(waterAlertMessage)
            }
            .alert("İşlem Başarılı", isPresented: $showElectricitySuccessAlert) {
                Button("Tamam", role: .cancel) { }
            } message: {
                Text(electricityAlertMessage)
            }
            .alert("İşlem Başarısız", isPresented: $showElectricityErrorAlert) {
                Button("Tamam", role: .cancel) { }
            } message: {
                Text(electricityAlertMessage)
            }
    }

    private var content: some View {
        ZStack {
            // Arka Plan Gradient (Senin orijinal gradient'in)
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

                    HStack(spacing: 15) {
                        // Su Kontrolü
                        serviceControlCard(
                            title: "Su\nTüketimi",
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
                                    Task {
                                        let isOpening = !usageViewModel.isWaterActive
                                        let success = await usageViewModel.toggleWaterAsync()
                                        
                                        if success {
                                            waterAlertMessage = isOpening ? "Su başarıyla açıldı." : "Su başarıyla kapatıldı."
                                            showWaterSuccessAlert = true
                                        } else {
                                            waterAlertMessage = usageViewModel.errorMessage ?? "Bilinmeyen bir hata oluştu."
                                            showWaterErrorAlert = true
                                        }
                                    }
                                },
                                secondaryButton: .cancel(Text("Hayır"))
                            )
                        }
                        
                        // Elektrik Kontrolü
                        serviceControlCard(
                            title: "Elektrik\nTüketimi",
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
                                    Task {
                                        let isOpening = !usageViewModel.isElectricityActive
                                        let success = await usageViewModel.toggleElectricityAsync()
                                        
                                        if success {
                                            electricityAlertMessage = isOpening ? "Elektrik başarıyla açıldı." : "Elektrik başarıyla kapatıldı."
                                            showElectricitySuccessAlert = true
                                        } else {
                                            electricityAlertMessage = usageViewModel.errorMessage ?? "Bilinmeyen bir hata oluştu."
                                            showElectricityErrorAlert = true
                                        }
                                    }
                                },
                                secondaryButton: .cancel(Text("Hayır"))
                            )
                        }
                    }
                    
                    
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .refreshable {
                await usageViewModel.refreshPedestalData()
            }
            .task {
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
                
                Text("Kullanımda")
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
                    Text("₺300,00/m³")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Elektrik Tarifesi")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                    Text("₺30/kWh")
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
                    
                    Text("€\(usageViewModel.pedestal.balance, specifier: "%.2f")")
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
                    Text("İstasyondaki €\(usageViewModel.pedestal.balance, specifier: "%.2f") tutarındaki bakiyenin tamamını ana hesabınıza aktarmak istiyor musunuz?")
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
            VStack(spacing: 12) {
                // 1. Başlık
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                // 2. Sembol (İkon)
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(color)
                    .padding(.vertical, 5)
                    .shadow(color: color.opacity(0.5), radius: 10)
                
                // 3. Kullanım Miktarı
                if isActive, let usage = usageValue, let unit = unit {
                    Text(String(format: "%.1f %@", usage, unit))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                } else {
                    Text("-")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                
                // 4. Açma/Kapama Butonu
                Button(action: toggleAction) {
                    Text(isActive ? "Kapat" : "Aç")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isActive ? Color.red.opacity(0.8) : color.opacity(0.8))
                        .cornerRadius(12)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 220) // Sabit yükseklik ve esnek genişlik
            .background(
                ZStack {
                    Color.black.opacity(0.4) // Karartma katmanı
                    Image("newşmage")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                }
            )
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
                        Text("€\(authViewModel.currentUser?.balance ?? 0, specifier: "%.2f")")
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
                        Text("€\(usageViewModel.pedestal.balance, specifier: "%.2f")")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundColor(.orange)
                    }
                    
                    // Tutar Girişi
                    VStack(alignment: .leading, spacing: 12) {
                        Text("İstasyona Aktarılacak Tutar")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                        
                        HStack(spacing: 8) { // Sembol ve sayı arasındaki boşluk
                            Spacer()
                            
                            // TL Sembolü
                            Text("€")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            // Metin Giriş Alanı
                            TextField("0", text: $transferAmount)
                                .keyboardType(.decimalPad)
                                .fixedSize() // Genişliğin içeriğe göre daralmasını sağlar
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Spacer()
                        }
                        .padding(.vertical, 16)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(15)
                    }
                    
                    // Hızlı Seçim Butonları
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach([100, 200, 500], id: \.self) { amount in
                            Button(action: { transferAmount = "\(amount)" }) {
                                Text("€\(amount)")
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
    
    // MARK: - Transfer Validation (0 TL için özel durum)
    private var isValidTransferAmount: Bool {
        guard let amount = Double(transferAmount) else { return false }
        
        // 0 TL'ye izin ver (ghost transfer için)
        if amount == 0 { return true }
        
        // Normal transfer validasyonu
        guard amount > 0 else { return false }
        guard let userBalance = authViewModel.currentUser?.balance else { return false }
        return amount <= userBalance
    }

    // MARK: - Transfer Function (Ghost Transfer Desteği)
    private func performTransfer() {
        guard let amount = Double(transferAmount) else { return }
        
        isTransferring = true
        transferError = nil
        
        Task {
            do {
                
                if amount == 0 {
                    print("Ghost Transfer: Cache bypass için 0 TL transfer yapılıyor...")
                    
                    // Backend'e 0 TL gönder (sadece cache'i temizlemek için)
                    try await usageViewModel.loadBalanceToStation(amount: 0)
                    
                    await MainActor.run {
                        isTransferring = false
                        showTransferSheet = false
                        transferAmount = ""
                        
                    }
                    
                    return
                }
                
                print("Normal Transfer: \(amount) TL aktarılıyor...")
                try await usageViewModel.loadBalanceToStation(amount: amount)
                
                await MainActor.run {
                    // Ana hesaptan düş
                    authViewModel.currentUser?.balance -= amount
                    
                    isTransferring = false
                    showTransferSheet = false
                    transferAmount = ""
                    
                    // Başarılı bildirimi göster
                    showTransferSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    transferError = "Transfer başarısız: \(error.localizedDescription)"
                    alertErrorMessage = error.localizedDescription
                    isTransferring = false
                    
                    // Başarısız bildirimi göster
                    showTransferErrorAlert = true
                }
            }
        }
    }
    
    // MARK: - Refund Function
    private func refundPedestalBalance() {
        print("Bakiye iadesi başlatılıyor...")
        print("Mevcut pedestal bakiyesi: \(pedestal.balance)")
        
        guard usageViewModel.pedestal.balance > 0 else {
            print("Pedestal bakiyesi 0, iade edilemez")
            return
        }
        
        isLoadingRefund = true // Loading başlat
        
        Task {
            do {
                print("API isteği gönderiliyor: PostBakiyeIade")
                let oldBalance = usageViewModel.pedestal.balance
                
                // API'ye iade isteği gönder
                try await usageViewModel.refundBalance()
                
                print("Bakiye iadesi başarılı!")
                
                await MainActor.run {
                    // Ana hesaba pedestal bakiyesini ekle
                    let currentUserBalance = authViewModel.currentUser?.balance ?? 0
                    authViewModel.currentUser?.balance = currentUserBalance + oldBalance
                    
                    print("Ana hesap güncellendi: \(currentUserBalance) → \(authViewModel.currentUser?.balance ?? 0)")
                    print("Pedestal verileri yenileniyor...")
                    
                    // İşlem bitti, loading kapat
                    isLoadingRefund = false
                    
                    // Başarılı bildirimi göster
                    showRefundSuccessAlert = true
                }
            } catch {
                print("Bakiye iadesi başarısız: \(error)")
                print("Hata detayı: \(error.localizedDescription)")
                
                await MainActor.run {
                    isLoadingRefund = false // Hata olsa da kapat
                    alertErrorMessage = error.localizedDescription
                    
                    // Başarısız bildirimi göster
                    showRefundErrorAlert = true
                    
                    print("Kullanıcıya hata gösterildi: \(error.localizedDescription)")
                }
            }
        }
    }
}

