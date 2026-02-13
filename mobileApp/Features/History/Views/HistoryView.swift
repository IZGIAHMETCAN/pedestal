import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @StateObject private var historyVM = HistoryViewModel()
    @State private var showingFilter = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Arka Plan
                LinearGradient(gradient: Gradient(colors: [Color(red: 0.02, green: 0.12, blue: 0.18), Color(red: 0.01, green: 0.05, blue: 0.1)]),
                               startPoint: .top,
                               endPoint: .bottom)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        headerView
                        
                        // Aktif Filtre Göstergesi
                        if historyVM.isFilterActive {
                            filterIndicatorView
                        }
                        
                        summaryCardsView
                        periodSelectorView
                        consumptionTypeSelectorView
                        
                        if historyVM.showChart {
                            chartView
                        } else {
                            listView
                        }
                        
                        detailedTableView
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 15) {
                        Button(action: { historyVM.showChart.toggle() }) {
                            Image(systemName: historyVM.showChart ? "list.bullet" : "chart.bar.fill")
                                .foregroundColor(.cyan)
                        }
                        Button(action: { showingFilter = true }) {
                            Image(systemName: "slider.horizontal.3").foregroundColor(.cyan)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingFilter) {
                FilterView().environmentObject(historyVM)
            }
        }
    }
    
    // MARK: - Subviews
    private var headerView: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 50)).foregroundColor(.cyan)
            Text("Tüketim Geçmişi").font(.title2).fontWeight(.bold).foregroundColor(.white)
            Text("Su ve Elektrik Kullanım Takibi").font(.subheadline).foregroundColor(.white.opacity(0.6))
        }.padding(.top, 20)
    }
    
    private var filterIndicatorView: some View {
        HStack {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .foregroundColor(.cyan)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Aktif Filtre")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                if let start = historyVM.filterStartDate, let end = historyVM.filterEndDate {
                    Text(formatDateRange(start: start, end: end))
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            Spacer()
            
            Button(action: { historyVM.clearFilter() }) {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                    Text("Temizle")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.3))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.cyan.opacity(0.15))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
    }
    
    private func formatDateRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM HH:mm"
        formatter.locale = Locale(identifier: "tr_TR")
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }

    private var summaryCardsView: some View {
        VStack(spacing: 15) {
            HStack(spacing: 15) {
                SummaryCard(title: "Toplam Su", value: String(format: "%.1f", historyVM.summary.totalWater), unit: "Litre", icon: "drop.fill", color: Color.blue)
                SummaryCard(title: "Toplam Elektrik", value: String(format: "%.1f", historyVM.summary.totalElectricity), unit: "kWh", icon: "bolt.fill", color: Color.yellow)
            }
            HStack(spacing: 15) {
                SummaryCard(title: "Toplam Maliyet", value: String(format: "%.1f", historyVM.summary.totalCost), unit: "TL", icon: "turkishlirasign.circle.fill", color: Color.green)
                SummaryCard(title: "Günlük Ortalama", value: String(format: "%.1f", historyVM.summary.averageDailyCost), unit: "TL/Gün", icon: "calendar", color: Color.purple)
            }
        }.padding(.horizontal)
    }

    private var periodSelectorView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Zaman Periyodu").font(.headline).foregroundColor(.cyan).padding(.horizontal)
            Picker("Periyot", selection: $historyVM.selectedPeriod) {
                ForEach(TimePeriod.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
        }
    }

    private var consumptionTypeSelectorView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Gösterilen Veri").font(.headline).foregroundColor(.cyan).padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(ConsumptionType.allCases, id: \.self) { type in
                        ConsumptionTypeButton(type: type, isSelected: historyVM.selectedConsumptionType == type) {
                            historyVM.selectedConsumptionType = type
                        }
                    }
                }.padding(.horizontal)
            }
        }
    }

    private var chartView: some View {
        VStack(spacing: 15) {
            ChartView(data: historyVM.chartData, maxValue: historyVM.maxChartValue, type: historyVM.selectedConsumptionType)
                .frame(height: 200).padding().background(Color.white.opacity(0.05)).cornerRadius(15).padding(.horizontal)
            
        }
    }

    private var listView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Zaman").frame(width: 80, alignment: .leading)
                Spacer()
                Text("Su").frame(width: 60, alignment: .trailing)
                Text("Elek.").frame(width: 70, alignment: .trailing)
                Text("TL").frame(width: 60, alignment: .trailing)
            }
            .font(.caption.bold()).foregroundColor(.cyan).padding()
            .background(Color.cyan.opacity(0.1))
            
            ForEach(Array(historyVM.currentData.enumerated()), id: \.offset) { index, item in
                ConsumptionRow(item: item, period: historyVM.selectedPeriod)
                    .background(index % 2 == 0 ? Color.clear : Color.white.opacity(0.03))
            }
        }
        .background(Color.white.opacity(0.05)).cornerRadius(10).padding(.horizontal)
    }

    private var detailedTableView: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(historyVM.isFilterActive ? "Filtrelenen Dönem Detayı" : "Son 7 Günlük Detay").font(.headline).foregroundColor(.cyan).padding(.horizontal)
            ForEach(Array(historyVM.last7DaysChartData.enumerated()), id: \.offset) { index, data in
                HStack {
                    Text(data.date).font(.caption).foregroundColor(.white).frame(width: 80, alignment: .leading)
                    Spacer()
                    HStack(spacing: 12) {
                        Text("\(data.water, specifier: "%.1f")L").foregroundColor(.blue)
                        Text("\(data.electricity, specifier: "%.1f")kW").foregroundColor(.yellow)
                        Text("\(data.cost, specifier: "%.1f")₺").foregroundColor(.green)
                    }.font(.system(size: 11, weight: .medium))
                }
                .padding().background(Color.white.opacity(0.05)).cornerRadius(8)
            }
        }.padding(.horizontal)
    }
}

// MARK: - Supporting Views

struct SummaryCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon).foregroundColor(color)
                Text(title).font(.caption).foregroundColor(.white.opacity(0.6))
                Spacer()
            }
            Text(value).font(.title2).fontWeight(.bold).foregroundColor(.white)
            Text(unit).font(.caption2).foregroundColor(.white.opacity(0.5))
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(15)
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}

struct StatisticView: View {
    let title: String
    let value: String
    let unit: String
    var body: some View {
        VStack(spacing: 5) {
            Text(title).font(.caption2).foregroundColor(.white.opacity(0.6))
            Text(value).font(.headline).foregroundColor(.white)
            Text(unit).font(.caption2).foregroundColor(.white.opacity(0.4))
        }.frame(maxWidth: .infinity)
    }
}

struct ConsumptionRow: View {
    let item: Any
    let period: TimePeriod
    var body: some View {
        HStack {
            if let data = item as? HourlyConsumption {
                Text(data.hour).frame(width: 80, alignment: .leading)
                Spacer()
                Text("\(data.waterUsage, specifier: "%.1f")").frame(width: 60, alignment: .trailing)
                Text("\(data.electricityUsage, specifier: "%.1f")").frame(width: 70, alignment: .trailing)
                Text("\(data.cost, specifier: "%.1f")").frame(width: 60, alignment: .trailing).foregroundColor(.green)
            } else if let data = item as? DailyConsumption {
                Text(data.day).frame(width: 80, alignment: .leading)
                Spacer()
                Text("\(data.waterUsage, specifier: "%.1f")").frame(width: 60, alignment: .trailing)
                Text("\(data.electricityUsage, specifier: "%.1f")").frame(width: 70, alignment: .trailing)
                Text("\(data.cost, specifier: "%.1f")").frame(width: 60, alignment: .trailing).foregroundColor(.green)
            }
        }
        .font(.caption).foregroundColor(.white.opacity(0.8)).padding(.horizontal).padding(.vertical, 10)
    }
}

struct ConsumptionTypeButton: View {
    let type: ConsumptionType
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: type.icon).font(.title3)
                Text(type.rawValue).font(.caption).fontWeight(.medium)
            }
            .frame(width: 85, height: 75)
            .foregroundColor(isSelected ? .black : .white)
            .background(isSelected ? Color.cyan : Color.white.opacity(0.05))
            .cornerRadius(12)
        }
    }
}

//ahemt 1

