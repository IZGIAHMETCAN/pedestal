import SwiftUI

struct SideMenuView: View {
    @Binding var isShowing: Bool
    @EnvironmentObject var authViewModel: AuthViewModel // Kullanıcı bilgileri için
    
    var editProfileAction: () -> Void
    var addCardAction: () -> Void
    var historyAction: () -> Void
    var logoutAction: () -> Void // Çıkış işlemi için
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Arka Plan Koyu Gradyan (BalanceView ile uyumlu)
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.02, green: 0.12, blue: 0.18), Color(red: 0.01, green: 0.05, blue: 0.1)]),
                           startPoint: .top,
                           endPoint: .bottom)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 25) {
                
                // Geri Butonu ve Başlık
                HStack {
                    Button(action: { isShowing = false }) {
                        Image(systemName: "arrow.left.circle.fill")
                            .font(.system(size: 35))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Text("Profil")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.leading, 10)
                }
                .padding(.top, 20)
                
                // KULLANICI BİLGİ KARTI (Görseldeki en üstteki büyük alan)
                HStack(spacing: 15) {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.cyan)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(authViewModel.currentUser?.name ?? "Kullanıcı Adı")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(authViewModel.currentUser?.email ?? "email@example.com")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.1))
                .cornerRadius(20)
                
                // MENÜ BUTONLARI
                VStack(spacing: 15) {
                    SideMenuButton(icon: "gearshape.fill", title: "Profil Ayarları") {
                        isShowing = false
                        editProfileAction()
                    }
                    
                    SideMenuButton(icon: "creditcard.fill", title: "Kayıtlı Ödeme Yöntemleri") {
                        isShowing = false
                        addCardAction()
                    }
                    
                    SideMenuButton(icon: "clock.fill", title: "Geçmiş Kullanımlar") {
                        isShowing = false
                        historyAction()
                    }
                }
                
                Spacer()
                
                // ÇIKIŞ BUTONU (Görseldeki en alttaki buton)
                Button(action: {
                    isShowing = false
                    logoutAction()
                }) {
                    Text("Çıkış")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.cyan.opacity(0.8))
                        .cornerRadius(25)
                }
                .padding(.bottom, 30)
            }
            .padding(.horizontal, 20)
            .frame(width: 300) // Menü genişliği
        }
    }
}

// Görseldeki oval ve turkuaz geçişli buton stili
struct SideMenuButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                // Görseldeki turkuaz gradyan efekti
                LinearGradient(gradient: Gradient(colors: [Color.cyan.opacity(0.6), Color.cyan.opacity(0.3)]),
                               startPoint: .leading,
                               endPoint: .trailing)
            )
            .cornerRadius(25) // Görseldeki tam oval yapı
            .overlay(
                RoundedRectangle(cornerRadius: 25)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
}
