import SwiftUI

struct UsageHistoryView: View {
    @StateObject private var historyManager = UsageHistoryManager.shared
    let pedestalId: Int? // Opsiyonel: belirli bir pedestal için filtreleme
    
    // Pedestal ID'ye göre filtrelenmiş geçmiş
    private var filteredHistory: [Usage] {
        if let pedestalId = pedestalId {
            return historyManager.getUsageHistory(for: pedestalId)
        }
        return historyManager.allUsageHistory
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
            
            if filteredHistory.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        // Özet Kart
                        summaryCard
                        
                        // Kullanım Geçmişi Listesi
                        VStack(spacing: 12) {
                            ForEach(filteredHistory.reversed()) { usage in
                                UsageRowView(usage: usage)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                }
            }
        }
        .navigationTitle("Kullanım Geçmişi")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
    
    // MARK: - Özet Kart
    private var summaryCard: some View {
        let totalWaterCost = filteredHistory.filter { $0.serviceType == .water }.reduce(0) { $0 + $1.cost }
        let totalElectricityCost = filteredHistory.filter { $0.serviceType == .electricity }.reduce(0) { $0 + $1.cost }
        let totalCost = totalWaterCost + totalElectricityCost
        
        return VStack(spacing: 16) {
            Text("Toplam Harcama Özeti")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 20) {
                // Su
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "drop.fill")
                            .foregroundColor(.blue)
                        Text("Su")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Text("€\(totalWaterCost, specifier: "%.2f")")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                
                // Elektrik
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.yellow)
                        Text("Elektrik")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Text("€\(totalElectricityCost, specifier: "%.2f")")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.yellow)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(12)
            }
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // Toplam
            HStack {
                Text("TOPLAM HARCAMA")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                Text("€\(totalCost, specifier: "%.2f")")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.cyan)
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
    
    // Boş durum
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.badge.xmark")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.3))
            
            Text("Henüz Kullanım Geçmişi Yok")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("Su veya elektrik kullanımınız burada görünecektir")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - Kullanım Satırı
struct UsageRowView: View {
    let usage: Usage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Üst Kısım: Servis Tipi ve Tarih
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: usage.serviceType == .water ? "drop.fill" : "bolt.fill")
                        .foregroundColor(usage.serviceType == .water ? .blue : .yellow)
                    
                    Text(usage.serviceType.rawValue)
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formattedDate(usage.startTime))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text(formattedTime(usage.startTime))
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Alt Kısım: Kullanım ve Maliyet
            HStack {
                // Kullanım Miktarı
                VStack(alignment: .leading, spacing: 4) {
                    Text("Kullanım")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text("\(usage.consumption, specifier: "%.4f") \(usage.serviceType == .water ? "m³" : "kWh")")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(usage.serviceType == .water ? .blue : .yellow)
                }
                
                Spacer()
                
                // Maliyet
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Maliyet")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text("€\(usage.cost, specifier: "%.4f")")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
            
            // Durum Badge'i
            if usage.isActive {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    
                    Text("Aktif")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    usage.serviceType == .water ?
                        Color.blue.opacity(0.3) :
                        Color.yellow.opacity(0.3),
                    lineWidth: 1
                )
        )
    }
    
    // MARK: - Tarih Formatlama
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMMM yyyy"
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.string(from: date)
    }
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}


