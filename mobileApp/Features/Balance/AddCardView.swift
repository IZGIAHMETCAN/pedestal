import SwiftUI

struct AddCardView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var cardHolderName = ""
    @State private var cardNumber = ""
    @State private var expirationDate = ""
    @State private var cvv = ""
    @State private var cardNickname = ""
    @State private var isAgreed = false
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.02, green: 0.12, blue: 0.18), Color(red: 0.01, green: 0.05, blue: 0.1)]),
                           startPoint: .top,
                           endPoint: .bottom)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // CUSTOM NAVIGATION BAR
                customNavBar
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 25) {
                        
                        // KART ÜZERİNDEKİ İSİM
                        inputField(title: "Kart Üzerindeki İsim", text: $cardHolderName, placeholder: "Ad Soyad")
                        
                        // KART NUMARASI
                        inputField(title: "Kart Numarası", text: $cardNumber, placeholder: "0000 0000 0000 0000", isNumber: true)
                            .onChange(of: cardNumber) { _, newValue in formatCardNumber(newValue) }
                        
                        // SKT VE CVV (YAN YANA)
                        HStack(spacing: 15) {
                            inputField(title: "Son Kullanma Tarihi", text: $expirationDate, placeholder: "AA/YY", isNumber: true)
                                .onChange(of: expirationDate) { _, newValue in formatExpirationDate(newValue) }
                            
                            inputField(title: "CVV", text: $cvv, placeholder: "123", isNumber: true, isSecure: true)
                        }
                        
                        // KART İSMİ
                        inputField(title: "Kart İsmi", text: $cardNickname, placeholder: "Örn: Maaş Kartım")
                        
                        // KULLANIM KOŞULLARI (CHECKBOX)
                        Toggle(isOn: $isAgreed) {
                            Text("Kredi kartı saklama koşullarını kabul ediyorum.")
                                .font(.footnote)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .toggleStyle(CheckboxStyle())
                        .padding(.vertical, 10)
                        
                        if let error = errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                                .padding(.horizontal)
                        }
                        
                        // KAYDET BUTONU
                        Button(action: saveCard) {
                            Text("Kartımı Kaydet")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isFormValid ? Color.cyan : Color.gray.opacity(0.3))
                                .cornerRadius(25)
                                .shadow(color: isFormValid ? Color.cyan.opacity(0.3) : .clear, radius: 10, x: 0, y: 5)
                        }
                        .disabled(!isFormValid)
                        .padding(.top, 20)
                    }
                    .padding(25)
                }
            }
        }
        .navigationBarHidden(true)
    }
}

extension AddCardView {
    
    // Özel Navigasyon Bar
    private var customNavBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "arrow.left.circle.fill")
                    .font(.system(size: 35))
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
            Text("Yeni Kart Ekle")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Spacer()
            Image(systemName: "arrow.left.circle.fill")
                .font(.system(size: 35))
                .opacity(0)
        }
        .padding()
    }
    
    // Cam Efektli Input Alanı
    private func inputField(title: String, text: Binding<String>, placeholder: String, isNumber: Bool = false, isSecure: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.9))
            
            Group {
                if isSecure {
                    SecureField("", text: text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.3)))
                } else {
                    TextField("", text: text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.3)))
                }
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            .foregroundColor(.white)
            .tint(.cyan) // Kursör rengi
            .keyboardType(isNumber ? .numberPad : .default)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

struct CheckboxStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .top) {
            Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                .foregroundColor(configuration.isOn ? .cyan : .white.opacity(0.5))
                .font(.system(size: 20))
                .onTapGesture {
                    configuration.isOn.toggle()
                }
            configuration.label
        }
    }
}

extension AddCardView {
    private var isFormValid: Bool {
        let cleanNumber = cardNumber.replacingOccurrences(of: " ", with: "")
        return cleanNumber.count == 16 &&
               expirationDate.count == 5 &&
               cvv.count == 3 &&
               !cardHolderName.isEmpty &&
               isAgreed
    }
    
    private func formatCardNumber(_ value: String) {
        let clean = value.filter { "0123456789".contains($0) }
        let limited = String(clean.prefix(16))
        var result = ""
        for (i, char) in limited.enumerated() {
            if i > 0 && i % 4 == 0 { result += " " }
            result.append(char)
        }
        cardNumber = result
    }
    
    private func formatExpirationDate(_ value: String) {
        let clean = value.filter { "0123456789".contains($0) }
        var result = String(clean.prefix(4))
        if result.count > 2 {
            result.insert("/", at: result.index(result.startIndex, offsetBy: 2))
        }
        expirationDate = result
    }
    
    private func saveCard() {
        authViewModel.saveCard(
            cardHolderName: cardHolderName,
            cardNumber: cardNumber,
            expirationDate: expirationDate,
            cvv: cvv
        ) { success, error in
            if success { dismiss() } else { errorMessage = error }
        }
    }
}



