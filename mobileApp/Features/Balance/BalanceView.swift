import SwiftUI

struct BalanceView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var amount = ""
    @State private var showingAddCard = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    let presetAmounts = [100, 200, 500, 1000]
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.02, green: 0.12, blue: 0.18), Color(red: 0.01, green: 0.05, blue: 0.1)]),
                           startPoint: .top,
                           endPoint: .bottom)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 25) {
                        
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Mevcut Bakiye")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.8))
                            
                            HStack {
                                Image(systemName: "creditcard.fill")
                                    .font(.title)
                                Spacer()
                                Text("VISA")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .italic()
                            }
                            
                            if let user = authViewModel.currentUser {
                                Text("€\(user.balance, specifier: "%.2f")")
                                    .font(.system(size: 45, weight: .bold, design: .rounded))
                            }
                        }
                        .foregroundColor(.white)
                        .padding(25)
                        .background(
                            LinearGradient(gradient: Gradient(colors: [Color.cyan.opacity(0.8), Color.blue.opacity(0.6)]),
                                           startPoint: .topLeading,
                                           endPoint: .bottomTrailing)
                        )
                        .cornerRadius(25)
                        .shadow(color: Color.cyan.opacity(0.2), radius: 10, x: 0, y: 5)
                        
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Yüklemek İstediğiniz Tutarı Seçiniz")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(presetAmounts, id: \.self) { preset in
                                    Button(action: { amount = "\(preset)" }) {
                                        Text("€\(preset)")
                                            .font(.system(size: 15, weight: .bold))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(amount == "\(preset)" ? Color.cyan : Color.white.opacity(0.1))
                                            .foregroundColor(.white)
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(amount == "\(preset)" ? Color.cyan : Color.white.opacity(0.2), lineWidth: 1)
                                            )
                                    }
                                }
                            }
                        }
                        
                        // ÖZEL TUTAR GİRİŞİ
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Veya Manuel Tutar Giriniz")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                            
                            HStack {
                                Spacer() // Sol boşluk (ortalamak için)
                                
                                // Tutar girildiğinde veya girilmeden önce sembolün rengini ayarla
                                Text("€")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(amount.isEmpty ? .white.opacity(0.3) : .white)
                                
                                // TextField
                                TextField("0", text: $amount)
                                    .keyboardType(.numberPad)
                                    .fixedSize() // Yazdıkça genişlemesini sağlar, böylece sembolle bitişik kalır
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                
                                Spacer() // Sağ boşluk (ortalamak için)
                            }
                            .padding()
                            .frame(height: 60) // Yüksekliği sabitlemek için
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(15)
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        }
                        
                        // ÖDEME YÖNTEMLERİ
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Ödeme Yöntemi")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                            
                            if let card = authViewModel.currentUser?.savedCard {
                                HStack {
                                    Image(systemName: "creditcard.and.123")
                                    Text("Visa **** \(String(card.cardNumber.suffix(4)))")
                                    Spacer()
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(.cyan)
                                }
                                .padding()
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(15)
                                .foregroundColor(.white)
                                .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.cyan.opacity(0.3), lineWidth: 1))
                            }
                            
                            
                            Button(action: { showingAddCard = true }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Farklı Bir Kart Ekle")
                                    Spacer()
                                }
                                .padding()
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(15)
                                .foregroundColor(.cyan)
                                .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            }
                        }
                        
                        if let error = errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                                .padding(.horizontal)
                        }
                    }
                    .padding(20)
                }
                
                // ANA YÜKLE BUTONU
                Button(action: processPayment) {
                    ZStack {
                        if isLoading {
                            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Bakiyeyi Yükle")
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(isValidAmount ? Color.cyan : Color.gray.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(25)
                    .shadow(color: isValidAmount ? Color.cyan.opacity(0.3) : Color.clear, radius: 10, y: 5)
                }
                .padding(.horizontal, 25)
                .padding(.bottom, 20)
                .disabled(!isValidAmount || isLoading)
            }
        }
        // NAVİGASYON AYARLARI
        .navigationTitle("Bakiye Yükle")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddCard) {
            AddCardView().environmentObject(authViewModel)
        }
    }
    
    private var isValidAmount: Bool {
        guard let value = Double(amount), value > 0 else { return false }
        return true
    }
    
    private func processPayment() {
        guard let value = Double(amount) else { return }
        isLoading = true
        
        authViewModel.addBalance(amount: value) { success, error in
            isLoading = false
            if success {
                dismiss()
            } else {
                errorMessage = error
            }
        }
    }
}



