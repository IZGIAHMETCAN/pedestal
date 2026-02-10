import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String
    @State private var boatName: String
    @State private var address: String
    @State private var tcIdentityNumber: String
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    init(user: User) {
        _name = State(initialValue: user.name) // User modelindeki isimlendirmeye dikkat
        _boatName = State(initialValue: user.boatName)
        _address = State(initialValue: user.adress)
        _tcIdentityNumber = State(initialValue: user.tcIdentityNumber)
    }
    
    var body: some View {
        ZStack {
            // 1. ARKA PLAN (Diğer sayfalarla aynı gradyan)
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.02, green: 0.12, blue: 0.18), Color(red: 0.01, green: 0.05, blue: 0.1)]),
                           startPoint: .top,
                           endPoint: .bottom)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    
                    // 2. PROFİL İKONU (Turkuaz efektli)
                    ZStack {
                        Circle()
                            .fill(Color.cyan.opacity(0.1))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 80, height: 80)
                            .foregroundColor(.cyan)
                    }
                    .padding(.top, 30)
                    
                    // 3. FORM ALANLARI (Koyu tema uyumlu)
                    VStack(spacing: 20) {
                        editField(placeholder: "Ad Soyad", icon: "person.fill", text: $name)
                        
                        editField(placeholder: "TC Kimlik No", icon: "person.text.rectangle.fill", text: $tcIdentityNumber, isNumber: true)
                        
                        editField(placeholder: "Tekne Adı", icon: "sailboat.fill", text: $boatName)
                        
                        editField(placeholder: "Adres", icon: "mappin.and.ellipse", text: $address)
                    }
                    .padding(.horizontal, 20)
                    
                    // Geri Bildirim Mesajları
                    messageSection
                    
                    // 4. KAYDET BUTONU (Turkuaz Tasarım)
                    saveButton
                        .padding(.horizontal, 25)
                        .padding(.top, 10)
                    
                    Spacer()
                }
            }
        }
        .navigationTitle("Profili Düzenle")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Tasarım Bileşenleri
extension EditProfileView {
    
    private func editField(placeholder: String, icon: String, text: Binding<String>, isNumber: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .foregroundColor(.cyan)
                    .frame(width: 25)
                
                TextField("", text: text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.3)))
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
                    .keyboardType(isNumber ? .numberPad : .default)
            }
            .padding(.vertical, 15)
            .padding(.horizontal, 20)
            .background(Color.white.opacity(0.05)) 
            .cornerRadius(15)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    private var saveButton: some View {
        Button(action: saveProfile) {
            Text("Değişiklikleri Kaydet")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(isFormValid ? Color.cyan : Color.gray.opacity(0.3))
                .cornerRadius(25)
                .shadow(color: isFormValid ? Color.cyan.opacity(0.3) : Color.clear, radius: 10, x: 0, y: 5)
        }
        .disabled(!isFormValid)
    }
    
    private var messageSection: some View {
        Group {
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.footnote)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
            }
            
            if let success = successMessage {
                Text(success)
                    .foregroundColor(.cyan)
                    .font(.footnote)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.cyan.opacity(0.1))
                    .cornerRadius(12)
            }
        }
        .padding(.horizontal, 25)
    }
    
    private var isFormValid: Bool {
        !name.isEmpty && tcIdentityNumber.count == 11 && !boatName.isEmpty && !address.isEmpty
    }
    
    private func saveProfile() {
        errorMessage = nil
        successMessage = nil
        
        authViewModel.updateUserProfile(
            name: name,
            boatName: boatName,
            adress: address,
            tcIdentityNumber: tcIdentityNumber
        ) { success, error in
            if success {
                successMessage = "Bilgileriniz başarıyla güncellendi."
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    dismiss()
                }
            } else {
                errorMessage = error
            }
        }
    }
}
