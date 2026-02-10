import SwiftUI

struct SignInView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showingSignUp = false

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(gradient: Gradient(colors: [Color(red: 0.02, green: 0.12, blue: 0.18), Color(red: 0.01, green: 0.05, blue: 0.1)]),
                               startPoint: .top,
                               endPoint: .bottom)
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 35) {
                        
                        // LOGO BÖLÜMÜ
                        VStack(spacing: 15) {
                            ZStack {
                                Circle()
                                    .fill(Color.cyan.opacity(0.1))
                                    .frame(width: 100, height: 100)
                                
                                Circle()
                                    .stroke(Color.cyan.opacity(0.5), lineWidth: 2)
                                    .frame(width: 100, height: 100)
                                
                                Image(systemName: "bolt.circle.fill")
                                    .font(.system(size: 70))
                                    .foregroundColor(.cyan)
                                    .shadow(color: .cyan.opacity(0.4), radius: 10)
                            }
                            
                            Text("Hoş Geldiniz")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("Devam etmek için giriş yapın")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.top, 60)
                        
                        // GİRİŞ ALANLARI
                        VStack(spacing: 20) {
                            // Email Alanı
                            AuthInputView(placeholder: "E-posta Adresi", icon: "envelope.fill", text: $email)
                            
                            // Şifre Alanı
                            AuthInputView(placeholder: "Şifre", icon: "lock.fill", text: $password, isSecure: true)
                        }
                        .padding(.horizontal, 30)
                        
                        // HATA MESAJI
                        if let error = authViewModel.errorMessage {
                            Text(error)
                                .foregroundColor(.orange)
                                .font(.system(size: 14, weight: .medium))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .transition(.opacity)
                        }
                        
                        // AKSİYON BUTONLARI
                        VStack(spacing: 15) {
                            // Giriş Yap
                            Button(action: {
                                authViewModel.signIn(email: email, password: password)
                            }) {
                                Text("Giriş Yap")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 18)
                                    .background(Color.cyan)
                                    .cornerRadius(25)
                                    .shadow(color: .cyan.opacity(0.3), radius: 10, y: 5)
                            }
                            
                            HStack {
                                Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                                Text("Veya").font(.caption).foregroundColor(.white.opacity(0.4))
                                Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                            }
                            .padding(.vertical, 10)
                            
                            // Kayıt Ol
                            Button(action: { showingSignUp = true }) {
                                Text("Yeni Hesap Oluştur")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 18)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(25)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 25)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            }
                        }
                        .padding(.horizontal, 30)
                        
                        Spacer()
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingSignUp) {
                SignUpView().environmentObject(authViewModel)
            }
        }
    }
}

struct AuthInputView: View {
    let placeholder: String
    let icon: String
    @Binding var text: String
    var isSecure: Bool = false
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .foregroundColor(.cyan)
                .frame(width: 25)
            
            if isSecure {
                SecureField("", text: $text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.3)))
            } else {
                TextField("", text: $text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.3)))
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(15)
        .foregroundColor(.white)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}
