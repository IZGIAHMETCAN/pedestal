import SwiftUI

struct PedestalListView: View {
    @StateObject private var viewModel = PedestalViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Arka Plan Gradient (HistoryView ile tutarlı)
                LinearGradient(gradient: Gradient(colors: [Color(red: 0.02, green: 0.12, blue: 0.18), Color(red: 0.01, green: 0.05, blue: 0.1)]),
                               startPoint: .top,
                               endPoint: .bottom)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Liste Başlığı ve İstatistik Özeti (İsteğe bağlı, çok küçük bir bilgi alanı)
                    headerSummaryView
                    
                    ScrollView {
                        LazyVStack(spacing: 15) {
                            ForEach(viewModel.filteredPedestals) { pedestal in
                                if pedestal.status == .available {
                                    // SADECE MÜSAİTSE: Detay sayfasına git ve tıklanabilir yap
                                    NavigationLink(destination: PedestalDetailView(pedestal: pedestal)) {
                                        PedestalRowView(pedestal: pedestal)
                                    }
                                } else {
                                    // DOLU/BAKIM/REZERVE: Tıklanamaz, sadece bilgi kartı
                                    PedestalRowView(pedestal: pedestal)
                                        .opacity(0.6) // Tıklanamaz olduğunu görsel olarak belli eder
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                    }
                }
            }
            .navigationTitle("Pedestallar")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { authViewModel.signOut() }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.cyan)
                    }
                }
            }
        }
    }
    
    // Üst kısımda kaç tane müsait olduğunu gösteren çok sade bir yazı
    private var headerSummaryView: some View {
        HStack {
            Text("\(viewModel.filteredPedestals.count) Toplam Pedestal")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
            Spacer()
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
            Text("\(viewModel.statistics.available) Müsait")
                .font(.caption)
                .foregroundColor(.green.opacity(0.8))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}

// MARK: - Pedestal Kart Tasarımı
struct PedestalRowView: View {
    let pedestal: Pedestal
    
    var body: some View {
        HStack(spacing: 15) {
            // Sol: Numara ve Lokasyon
            VStack(alignment: .leading, spacing: 4) {
                Text(pedestal.pedestalNumber)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(pedestal.location)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            // Orta: Servis Simgeleri
            HStack(spacing: 12) {
                if pedestal.isWaterActive {
                    Image(systemName: "drop.fill")
                        .foregroundColor(.blue)
                }
                if pedestal.isElectricityActive {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.yellow)
                }
            }
            .font(.system(size: 14))
            
            // Sağ: Durum Rozeti
            statusBadge
        }
        .padding(.all, 18)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(pedestal.status == .available ? Color.cyan.opacity(0.2) : Color.clear, lineWidth: 1)
        )
    }
    
    private var statusBadge: some View {
        Text(pedestal.status.rawValue)
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(statusColor.opacity(0.15))
            .foregroundColor(statusColor)
            .cornerRadius(8)
    }
    
    private var statusColor: Color {
        switch pedestal.status {
        case .available: return .green
        case .occupied: return .red
        case .maintenance: return .orange
        case .inUse: return .yellow
        }
    }
}


