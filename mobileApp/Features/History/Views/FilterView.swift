import SwiftUI

struct FilterView: View {
    @EnvironmentObject var historyVM: HistoryViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var startDate: Date
    @State private var startTime: Date
    @State private var endDate: Date
    @State private var endTime: Date
    
    init() {
        // Default: Son 7 gün
        let now = Date()
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        
        _startDate = State(initialValue: sevenDaysAgo)
        _startTime = State(initialValue: Calendar.current.startOfDay(for: sevenDaysAgo))
        _endDate = State(initialValue: now)
        _endTime = State(initialValue: now)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Arka plan
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
                        // Header
                        VStack(spacing: 10) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 50))
                                .foregroundColor(.cyan)
                            Text("Tarih ve Saat Filtresi")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Text("Görmek istediğiniz aralığı seçin")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.top, 20)
                        
                        // Başlangıç Tarihi ve Saati
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(.green)
                                Text("Başlangıç")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            
                            HStack(spacing: 15) {
                                // Tarih Seçici
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Tarih")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.6))
                                    DatePicker("", selection: $startDate, displayedComponents: .date)
                                        .labelsHidden()
                                        .datePickerStyle(.compact)
                                        .accentColor(.cyan)
                                        .colorScheme(.dark)
                                }
                                
                                Spacer()
                                
                                // Saat Seçici
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Saat")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.6))
                                    DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                                        .labelsHidden()
                                        .datePickerStyle(.compact)
                                        .accentColor(.cyan)
                                        .colorScheme(.dark)
                                }
                            }
                        }
                        .padding(20)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(15)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        )
                        
                        // Bitiş Tarihi ve Saati
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Image(systemName: "calendar.badge.checkmark")
                                    .foregroundColor(.red)
                                Text("Bitiş")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            
                            HStack(spacing: 15) {
                                // Tarih Seçici
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Tarih")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.6))
                                    DatePicker("", selection: $endDate, displayedComponents: .date)
                                        .labelsHidden()
                                        .datePickerStyle(.compact)
                                        .accentColor(.cyan)
                                        .colorScheme(.dark)
                                }
                                
                                Spacer()
                                
                                // Saat Seçici
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Saat")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.6))
                                    DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                                        .labelsHidden()
                                        .datePickerStyle(.compact)
                                        .accentColor(.cyan)
                                        .colorScheme(.dark)
                                }
                            }
                        }
                        .padding(20)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(15)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                        
                        // Özet Bilgisi
                        VStack(spacing: 10) {
                            Text("Seçilen Aralık")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                            
                            Text(selectedRangeSummary)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.cyan)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .background(Color.cyan.opacity(0.1))
                        .cornerRadius(10)
                        
                        // Hızlı Seçim Butonları
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Hızlı Seçim")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                QuickSelectButton(title: "Bugün", icon: "sun.max.fill") {
                                    selectToday()
                                }
                                QuickSelectButton(title: "Dün", icon: "sun.and.horizon.fill") {
                                    selectYesterday()
                                }
                                QuickSelectButton(title: "Son 7 Gün", icon: "calendar") {
                                    selectLast7Days()
                                }
                                QuickSelectButton(title: "Son 30 Gün", icon: "calendar.circle") {
                                    selectLast30Days()
                                }
                            }
                        }
                        .padding(20)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(15)
                        
                        // Uygula Butonu
                        Button(action: applyFilters) {
                            HStack {
                                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                Text("Filtreyi Uygula")
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.cyan)
                            .cornerRadius(15)
                        }
                        
                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("Filtrele")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") {
                        dismiss()
                    }
                    .foregroundColor(.cyan)
                }
            }
            .onAppear {
                // ViewModel'den mevcut filtreleri yükle
                if let existingStart = historyVM.filterStartDate,
                   let existingEnd = historyVM.filterEndDate {
                    startDate = existingStart
                    startTime = existingStart
                    endDate = existingEnd
                    endTime = existingEnd
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var selectedRangeSummary: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy HH:mm"
        formatter.locale = Locale(identifier: "tr_TR")
        
        let combinedStart = combineDateTime(date: startDate, time: startTime)
        let combinedEnd = combineDateTime(date: endDate, time: endTime)
        
        return "\(formatter.string(from: combinedStart)) - \(formatter.string(from: combinedEnd))"
    }
    
    // MARK: - Helper Methods
    
    private func combineDateTime(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        
        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute
        
        return calendar.date(from: combined) ?? date
    }
    
    private func applyFilters() {
        let combinedStart = combineDateTime(date: startDate, time: startTime)
        let combinedEnd = combineDateTime(date: endDate, time: endTime)
        
        print("📅 Filtre uygulanıyor:")
        print("   Başlangıç: \(combinedStart)")
        print("   Bitiş: \(combinedEnd)")
        
        // ViewModel'e filtreleri kaydet
        historyVM.filterStartDate = combinedStart
        historyVM.filterEndDate = combinedEnd
        
        // Veriyi yükle
        historyVM.applyDateFilter(startDate: combinedStart, endDate: combinedEnd)
        
        dismiss()
    }
    
    // MARK: - Quick Select Methods
    
    private func selectToday() {
        let now = Date()
        startDate = Calendar.current.startOfDay(for: now)
        startTime = Calendar.current.startOfDay(for: now)
        endDate = now
        endTime = now
    }
    
    private func selectYesterday() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        startDate = Calendar.current.startOfDay(for: yesterday)
        startTime = Calendar.current.startOfDay(for: yesterday)
        endDate = Calendar.current.startOfDay(for: Date())
        endTime = Calendar.current.startOfDay(for: Date())
    }
    
    private func selectLast7Days() {
        let now = Date()
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        startDate = sevenDaysAgo
        startTime = Calendar.current.startOfDay(for: sevenDaysAgo)
        endDate = now
        endTime = now
    }
    
    private func selectLast30Days() {
        let now = Date()
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        startDate = thirtyDaysAgo
        startTime = Calendar.current.startOfDay(for: thirtyDaysAgo)
        endDate = now
        endTime = now
    }
}

// MARK: - Quick Select Button

struct QuickSelectButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.1))
            .cornerRadius(10)
        }
    }
}
