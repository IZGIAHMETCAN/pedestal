import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var boatName = ""
    @State private var address = ""
    @State private var tcIdentityNumber = ""
    
    
    let brandBlue = Color(red: 0.1, green: 0.35, blue: 0.7)
    
    var body: some View {
        ZStack {
            // 1. Arka Plan
            brandBlue.ignoresSafeArea()
            
            VStack {
                // Özel Toolbar İptal butonu için
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .font(.title3)
                            .padding()
                    }
                    Spacer()
                    Text("Yeni Hesap")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    // Denge sağlamak için boş alan
                    Color.clear.frame(width: 50, height: 50)
                }
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Başlık ve İkon
                        Image(systemName: "person.badge.plus")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.top, 10)
                        
                        Text("Bilgilerinizi Girin")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        // FORM ALANLARI
                        VStack(spacing: 15) {
                            groupLabel("Kişisel Bilgiler")
                            
                            AuthTextField(placeholder: "Ad Soyad", iconName: "person", isSecure: false, text: $name)
                            
                            AuthTextField(placeholder: "TC Kimlik Numarası", iconName: "person.text.rectangle", isSecure: false, text: $tcIdentityNumber)
                                .keyboardType(.numberPad)
                            
                            groupLabel("Tekne Bilgileri")
                            
                            AuthTextField(placeholder: "Tekne Adı", iconName: "sailboat", isSecure: false, text: $boatName)
                            
                            AuthTextField(placeholder: "Adres", iconName: "house", isSecure: false, text: $address)
                            
                            groupLabel("Giriş Bilgileri")
                            
                            AuthTextField(placeholder: "E-posta", iconName: "envelope", isSecure: false, text: $email)
                            
                            AuthTextField(placeholder: "Şifre", iconName: "lock", isSecure: true, text: $password)
                            
                            AuthTextField(placeholder: "Şifre Tekrar", iconName: "lock", isSecure: true, text: $confirmPassword)
                        }
                        .padding(.horizontal, 25)
                        
                        // Hata Mesajı
                        if let error = authViewModel.errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                                .padding(.top, 5)
                        }
                        
                        // KAYIT BUTONU
                        Button(action: signUp) {
                            Text("Hesabı Oluştur")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isFormValid ? Color.green : Color.gray.opacity(0.5))
                                .cornerRadius(30)
                        }
                        .padding(.horizontal, 25)
                        .padding(.top, 20)
                        .disabled(!isFormValid)
                        
                        Spacer(minLength: 50)
                    }
                }
            }
        }
    }
    
    // Yardımcı Başlık Tasarımı
    private func groupLabel(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white.opacity(0.7))
                .padding(.leading, 10)
            Spacer()
        }
        .padding(.top, 10)
    }

    private var isFormValid: Bool {
        !name.isEmpty && !email.isEmpty && tcIdentityNumber.count == 11 &&
        !boatName.isEmpty && !address.isEmpty && !password.isEmpty &&
        password == confirmPassword && password.count >= 6
    }
    
    private func signUp() {
        authViewModel.signUp(
            email: email,
            password: password,
            name: name,
            boatName: boatName,
            adress: address,
            tcIdentityNumber: tcIdentityNumber
        )
        if authViewModel.isAuthenticated {
            dismiss()
        }
    }
}
