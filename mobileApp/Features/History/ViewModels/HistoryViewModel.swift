import SwiftUI
import Combine

class HistoryViewModel: ObservableObject {
    @Published var selectedPeriod: TimePeriod = .daily
    @Published var selectedConsumptionType: ConsumptionType = .water
    @Published var isLoading = false
    @Published var showChart = true
    @Published var errorMessage: String?
    
    @Published var tuketimVerileri: [TuketimBilgisiResponse] = []
    @Published var filteredVerileri: [TuketimBilgisiResponse] = []
    @Published var selectedKartId: String?
    
    // Filter state
    @Published var filterStartDate: Date?
    @Published var filterEndDate: Date?
    @Published var isFilterActive: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private let apiService = ApiService.shared
    
    // Date parser for backend date strings (format: "2026-02-03T14:14:51.36")
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SS"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    private func parseDate(_ dateString: String) -> Date? {
        return dateFormatter.date(from: dateString)
    }
    
    // MARK: - API Methods
    
    func loadTuketimRaporu(kartID: String, firstDate: Date, secondDate: Date) {
        isLoading = true
        errorMessage = nil
        selectedKartId = kartID
        
        Task {
            do {
                let tuketimler = try await apiService.getKullaniciTuketimler(
                    kartID: kartID,
                    firstDate: firstDate,
                    secondDate: secondDate
                )
                
                await MainActor.run {
                    self.tuketimVerileri = tuketimler
                    self.isLoading = false
                }
                
            } catch {
                await MainActor.run {
                    if let apiError = error as? APIError {
                        self.errorMessage = apiError.errorDescription
                    } else {
                        self.errorMessage = "Tüketim raporu yüklenemedi: \(error.localizedDescription)"
                    }
                    self.isLoading = false
                    
                    // Hata durumunda boş liste
                    self.tuketimVerileri = []
                }
            }
        }
    }
    
    func refreshData() {
        guard let kartId = selectedKartId else { return }
        
        let (firstDate, secondDate) = getDateRangeForPeriod(selectedPeriod)
        loadTuketimRaporu(kartID: kartId, firstDate: firstDate, secondDate: secondDate)
    }
    
    
    
    
    // MARK: - Filter Methods
    
    /// Tarih ve saat aralığına göre verileri filtreler
    func applyDateFilter(startDate: Date, endDate: Date) {
        filterStartDate = startDate
        filterEndDate = endDate
        isFilterActive = true
        
        print("Filtre uygulanıyor: \(startDate) - \(endDate)")
        
        // Eğer mevcut veri varsa, local olarak filtrele
        if !tuketimVerileri.isEmpty {
            filteredVerileri = tuketimVerileri.filter { item in
                guard let itemDate = parseDate(item.tarih) else { return false }
                return itemDate >= startDate && itemDate <= endDate
            }
            print("Filtrelenen kayıt sayısı: \(filteredVerileri.count) / \(tuketimVerileri.count)")
        } else {
            // Veri yoksa API'den çek
            guard let kartId = selectedKartId else { return }
            loadTuketimRaporu(kartID: kartId, firstDate: startDate, secondDate: endDate)
        }
    }
    
    /// Filtreyi temizler ve tüm verileri gösterir
    func clearFilter() {
        filterStartDate = nil
        filterEndDate = nil
        isFilterActive = false
        filteredVerileri = []
    }
    
    /// Aktif veri seti (filtre aktifse filtrelenmiş, değilse tüm veriler)
    var activeData: [TuketimBilgisiResponse] {
        if isFilterActive && !filteredVerileri.isEmpty {
            return filteredVerileri
        }
        return tuketimVerileri
    }
    
    // MARK: - Data Processing
    
    // Seçilen periyoda göre veriler
    var currentData: [any Identifiable] {
        guard !activeData.isEmpty else {
            // Fallback olarak mock data kullan
            return getMockDataForPeriod()
        }
        
        switch selectedPeriod {
        case .daily:
            return convertToHourlyConsumption()
        case .weekly:
            return convertToDailyConsumption()
        case .monthly:
            return convertToMonthlyConsumption()
        }
    }
    
    // Toplam istatistikler
    var summary: ConsumptionSummary {
        guard !activeData.isEmpty else {
            return MockConsumptionData.shared.totalSummary
        }
        
        let totalWater = activeData.reduce(0) { $0 + ($1.litreTuketim ?? 0) } / 1000 // m³'e çevir
        let totalElectricity = activeData.reduce(0) { $0 + ($1.elektrikTuketim ?? 0) }
        
        // Maliyet hesaplama (örnek fiyatlarla)
        let waterCost = totalWater * 10.0 // 10 EUR/m³
        let electricityCost = totalElectricity * 2.5 // 2.5 EUR/kWh
        let totalCost = waterCost + electricityCost
        
        let dayCount = max(activeData.count, 1)
        
        return ConsumptionSummary(
            totalWater: totalWater,
            totalElectricity: totalElectricity,
            totalCost: totalCost,
            averageDailyWater: totalWater / Double(dayCount),
            averageDailyElectricity: totalElectricity / Double(dayCount),
            averageDailyCost: totalCost / Double(dayCount)
        )
    }
    
    // Grafik verileri
    var chartData: [(label: String, value: Double)] {
        guard !activeData.isEmpty else {
            return getMockChartData()
        }
        
        switch selectedPeriod {
        case .daily:
            let hourlyData = convertToHourlyConsumption()
            return hourlyData.map { item in
                let value = getValueForType(water: item.waterUsage, electricity: item.electricityUsage, cost: item.cost)
                return (item.hour, value)
            }
            
        case .weekly:
            let dailyData = convertToDailyConsumption()
            return dailyData.map { item in
                let value = getValueForType(water: item.waterUsage, electricity: item.electricityUsage, cost: item.cost)
                return (item.day, value)
            }
            
        case .monthly:
            let monthlyData = convertToMonthlyConsumption()
            return monthlyData.map { item in
                let value = getValueForType(water: item.waterUsage, electricity: item.electricityUsage, cost: item.cost)
                return (item.month, value)
            }
        }
    }
    
    private func getValueForType(water: Double, electricity: Double, cost: Double) -> Double {
        switch selectedConsumptionType {
        case .water:
            return water
        case .electricity:
            return electricity
        case .cost:
            return cost
        }
    }
    
    // Maksimum değer (grafik ölçekleme için)
    var maxChartValue: Double {
        return chartData.map { $0.value }.max() ?? 1.0
    }
    
    // Ortalama değer
    var averageValue: Double {
        let values = chartData.map { $0.value }
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }
    
    // Toplam değer
    var totalValue: Double {
        return chartData.map { $0.value }.reduce(0, +)
    }
    
    // MARK: - Private Helper Methods
    
    private func convertToHourlyConsumption() -> [HourlyConsumption] {
        // Backend'den gelen verileri saatlik gruplara ayır
        var hourlyDict: [Int: (water: Double, electricity: Double)] = [:]
        
        let calendar = Calendar.current
        for item in activeData {
            let dateString = item.tarih
            guard let tarih = parseDate(dateString) else { continue }
            let hour = calendar.component(.hour, from: tarih)
            
            let existing = hourlyDict[hour] ?? (0, 0)
            hourlyDict[hour] = (
                existing.water + (item.litreTuketim ?? 0) / 1000,
                existing.electricity + (item.elektrikTuketim ?? 0)
            )
        }
        
        return hourlyDict.keys.sorted().map { hour in
            let data = hourlyDict[hour]!
            let cost = (data.water * 10.0) + (data.electricity * 2.5)
            return HourlyConsumption(
                hour: String(format: "%02d:00", hour),
                waterUsage: data.water,
                electricityUsage: data.electricity,
                cost: cost
            )
        }
    }
    
    private func convertToDailyConsumption() -> [DailyConsumption] {
        var dailyDict: [Date: (water: Double, electricity: Double)] = [:]
        
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE"
        dateFormatter.locale = Locale(identifier: "tr_TR")
        
        for item in activeData {
            let dateString = item.tarih
            guard let tarih = parseDate(dateString) else { continue }
            let dayStart = calendar.startOfDay(for: tarih)
            
            let existing = dailyDict[dayStart] ?? (0, 0)
            dailyDict[dayStart] = (
                existing.water + (item.litreTuketim ?? 0) / 1000,
                existing.electricity + (item.elektrikTuketim ?? 0)
            )
        }
        
        return dailyDict.keys.sorted().map { date in
            let data = dailyDict[date]!
            let cost = (data.water * 10.0) + (data.electricity * 2.5)
            return DailyConsumption(
                day: dateFormatter.string(from: date),
                waterUsage: data.water,
                electricityUsage: data.electricity,
                cost: cost
            )
        }
    }
    
    private func convertToMonthlyConsumption() -> [MonthlyConsumption] {
        var monthlyDict: [String: (water: Double, electricity: Double)] = [:]
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM"
        dateFormatter.locale = Locale(identifier: "tr_TR")
        
        for item in activeData {
            let dateString = item.tarih
            guard let tarih = parseDate(dateString) else { continue }
            let monthKey = dateFormatter.string(from: tarih)
            
            let existing = monthlyDict[monthKey] ?? (0, 0)
            monthlyDict[monthKey] = (
                existing.water + (item.litreTuketim ?? 0) / 1000,
                existing.electricity + (item.elektrikTuketim ?? 0)
            )
        }
        
        return monthlyDict.keys.sorted().map { month in
            let data = monthlyDict[month]!
            let cost = (data.water * 10.0) + (data.electricity * 2.5)
            return MonthlyConsumption(
                month: month,
                waterUsage: data.water,
                electricityUsage: data.electricity,
                cost: cost
            )
        }
    }
    
    private func getDateRangeForPeriod(_ period: TimePeriod) -> (Date, Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch period {
        case .daily:
            // Son 24 saat
            let start = calendar.date(byAdding: .day, value: -1, to: now)!
            return (start, now)
        case .weekly:
            // Son 7 gün
            let start = calendar.date(byAdding: .day, value: -7, to: now)!
            return (start, now)
        case .monthly:
            // Son 30 gün
            let start = calendar.date(byAdding: .day, value: -30, to: now)!
            return (start, now)
        }
    }
    
    // Mock data fallback
    private func getMockDataForPeriod() -> [any Identifiable] {
        switch selectedPeriod {
        case .daily:
            return MockConsumptionData.shared.hourlyData
        case .weekly:
            return MockConsumptionData.shared.dailyData
        case .monthly:
            return MockConsumptionData.shared.monthlyData
        }
    }
    
    private func getMockChartData() -> [(label: String, value: Double)] {
        let mockData = getMockDataForPeriod()
        
        switch selectedPeriod {
        case .daily:
            let hourlyData = mockData as! [HourlyConsumption]
            return hourlyData.map { (
                $0.hour,
                getValueForType(water: $0.waterUsage, electricity: $0.electricityUsage, cost: $0.cost)
            )}
        case .weekly:
            let dailyData = mockData as! [DailyConsumption]
            return dailyData.map { (
                $0.day,
                getValueForType(water: $0.waterUsage, electricity: $0.electricityUsage, cost: $0.cost)
            )}
        case .monthly:
            let monthlyData = mockData as! [MonthlyConsumption]
            return monthlyData.map { (
                $0.month,
                getValueForType(water: $0.waterUsage, electricity: $0.electricityUsage, cost: $0.cost)
            )}
        }
    }
    
    // MARK: - Filtered Data (for detailed table)
    
    /// Detaylı tablo için veri - filtre aktifse filtrelenen aralıktaki, değilse son 7 gün verilerini gösterir
    var last7DaysChartData: [(date: String, water: Double, electricity: Double, cost: Double)] {
        guard !activeData.isEmpty else {
            // Mock data fallback
            return MockConsumptionData.shared.last7Days.map { item in
                let dateString = MockConsumptionData.formatDate(item.date)
                return (dateString, item.water, item.electricity, item.cost)
            }
        }
        
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM"
        dateFormatter.locale = Locale(identifier: "tr_TR")
        
        var dailyData: [Date: (water: Double, electricity: Double, cost: Double)] = [:]
        
        // Filtre aktifse filtrelenen aralıktaki günleri, değilse son 7 günü göster
        if isFilterActive, let startDate = filterStartDate, let endDate = filterEndDate {
            // Filtrelenen tarih aralığındaki tüm günleri oluştur
            var currentDate = calendar.startOfDay(for: startDate)
            let endDay = calendar.startOfDay(for: endDate)
            
            while currentDate <= endDay {
                dailyData[currentDate] = (0, 0, 0)
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
            }
        } else {
            // Son 7 gün için tarihleri oluştur
            for dayOffset in 0..<7 {
                let date = calendar.startOfDay(for: Date().addingTimeInterval(-Double(dayOffset * 86400)))
                dailyData[date] = (0, 0, 0)
            }
        }
        
        // Gerçek kullanım verilerini grupla
        for item in activeData {
            let dateString = item.tarih
            guard let tarih = parseDate(dateString) else { continue }
            let dayStart = calendar.startOfDay(for: tarih)
            
            // dailyData'da bu gün varsa ekle, yoksa da ekle (filtre dışı veriler için)
            let existing = dailyData[dayStart] ?? (0, 0, 0)
            let water = (item.litreTuketim ?? 0) / 1000 // m³'e çevir
            let electricity = item.elektrikTuketim ?? 0
            let cost = (water * 10.0) + (electricity * 2.5)
            
            dailyData[dayStart] = (
                existing.water + water,
                existing.electricity + electricity,
                existing.cost + cost
            )
        }
        
        // Sırala (en yeniden en eskiye) ve formatla
        return dailyData.keys.sorted(by: >).map { date in
            let values = dailyData[date]!
            return (dateFormatter.string(from: date), values.water, values.electricity, values.cost)
        }
    }
    
    // MARK: - Export Functionality
    
    func exportData(format: String) {
        
    }
}
