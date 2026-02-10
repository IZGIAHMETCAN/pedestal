import Foundation
import Combine

class UsageHistoryManager: ObservableObject {
    static let shared = UsageHistoryManager()
    
    @Published var allUsageHistory: [Usage] = []
    
    private init() {
        // İlk başlatmada mock data yükle
        loadMockDataIfNeeded()
    }
    
    // Usage ekleme
    func addUsage(_ usage: Usage) {
        allUsageHistory.append(usage)
        saveToUserDefaults()
    }
    
    // Birden fazla usage ekleme
    func addUsages(_ usages: [Usage]) {
        allUsageHistory.append(contentsOf: usages)
        saveToUserDefaults()
    }
    
    // Belirli bir pedestal'a ait usage'ları getirme
    func getUsageHistory(for pedestalId: Int) -> [Usage] {
        return allUsageHistory.filter { $0.pedestalId == pedestalId }
    }
    
    // Tüm geçmişi temizleme
    func clearHistory() {
        allUsageHistory.removeAll()
        saveToUserDefaults()
    }
    
    // Consumption formatına dönüştürme (HistoryView için)
    func convertToHourlyConsumption() -> [HourlyConsumption] {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:00"
        
        // Son 24 saati grupla
        var hourlyDict: [String: (water: Double, electricity: Double, cost: Double)] = [:]
        
        let last24Hours = allUsageHistory.filter {
            let hoursDiff = Date().timeIntervalSince($0.startTime) / 3600
            return hoursDiff <= 24
        }
        
        for usage in last24Hours {
            let hourString = dateFormatter.string(from: usage.startTime)
            
            if hourlyDict[hourString] == nil {
                hourlyDict[hourString] = (0, 0, 0)
            }
            
            if usage.serviceType == .water {
                hourlyDict[hourString]?.water += usage.consumption
                hourlyDict[hourString]?.cost += usage.cost
            } else {
                hourlyDict[hourString]?.electricity += usage.consumption
                hourlyDict[hourString]?.cost += usage.cost
            }
        }
        
        return hourlyDict.map { key, value in
            HourlyConsumption(
                hour: key,
                waterUsage: value.water,
                electricityUsage: value.electricity,
                cost: value.cost
            )
        }.sorted { $0.hour < $1.hour }
    }
    
    func convertToDailyConsumption() -> [DailyConsumption] {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "tr_TR")
        dateFormatter.dateFormat = "EEE"
        
        // Son 7 günü grupla
        var dailyDict: [String: (water: Double, electricity: Double, cost: Double)] = [:]
        
        let last7Days = allUsageHistory.filter {
            let daysDiff = Date().timeIntervalSince($0.startTime) / 86400
            return daysDiff <= 7
        }
        
        for usage in last7Days {
            let dayString = dateFormatter.string(from: usage.startTime)
            
            if dailyDict[dayString] == nil {
                dailyDict[dayString] = (0, 0, 0)
            }
            
            if usage.serviceType == .water {
                dailyDict[dayString]?.water += usage.consumption
                dailyDict[dayString]?.cost += usage.cost
            } else {
                dailyDict[dayString]?.electricity += usage.consumption
                dailyDict[dayString]?.cost += usage.cost
            }
        }
        
        return dailyDict.map { key, value in
            DailyConsumption(
                day: convertToShortDay(key),
                waterUsage: value.water,
                electricityUsage: value.electricity,
                cost: value.cost
            )
        }
    }
    
    func convertToMonthlyConsumption() -> [MonthlyConsumption] {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "tr_TR")
        dateFormatter.dateFormat = "MMM"
        
        // Son 12 ayı grupla
        var monthlyDict: [String: (water: Double, electricity: Double, cost: Double)] = [:]
        
        let last12Months = allUsageHistory.filter {
            let monthsDiff = calendar.dateComponents([.month], from: $0.startTime, to: Date()).month ?? 0
            return monthsDiff <= 12
        }
        
        for usage in last12Months {
            let monthString = dateFormatter.string(from: usage.startTime)
            
            if monthlyDict[monthString] == nil {
                monthlyDict[monthString] = (0, 0, 0)
            }
            
            if usage.serviceType == .water {
                monthlyDict[monthString]?.water += usage.consumption
                monthlyDict[monthString]?.cost += usage.cost
            } else {
                monthlyDict[monthString]?.electricity += usage.consumption
                monthlyDict[monthString]?.cost += usage.cost
            }
        }
        
        return monthlyDict.map { key, value in
            MonthlyConsumption(
                month: key,
                waterUsage: value.water,
                electricityUsage: value.electricity,
                cost: value.cost
            )
        }
    }
    
    // Summary hesaplama
    func calculateSummary() -> ConsumptionSummary {
        let totalWater = allUsageHistory
            .filter { $0.serviceType == .water }
            .reduce(0) { $0 + $1.consumption }
        
        let totalElectricity = allUsageHistory
            .filter { $0.serviceType == .electricity }
            .reduce(0) { $0 + $1.consumption }
        
        let totalCost = allUsageHistory.reduce(0) { $0 + $1.cost }
        
        let daysCount = max(1, calculateDaysSinceFirstUsage())
        
        return ConsumptionSummary(
            totalWater: totalWater,
            totalElectricity: totalElectricity,
            totalCost: totalCost,
            averageDailyWater: totalWater / Double(daysCount),
            averageDailyElectricity: totalElectricity / Double(daysCount),
            averageDailyCost: totalCost / Double(daysCount)
        )
    }
    
    // MARK: - Helper Methods
    
    private func calculateDaysSinceFirstUsage() -> Int {
        guard let firstUsage = allUsageHistory.sorted(by: { $0.startTime < $1.startTime }).first else {
            return 1
        }
        
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: firstUsage.startTime, to: Date()).day ?? 1
        return max(1, days)
    }
    
    private func convertToShortDay(_ dayString: String) -> String {
        let mapping: [String: String] = [
            "Mon": "Pzt",
            "Tue": "Sal",
            "Wed": "Çar",
            "Thu": "Per",
            "Fri": "Cum",
            "Sat": "Cmt",
            "Sun": "Paz"
        ]
        return mapping[dayString] ?? dayString
    }
    
    // MARK: - Persistence
    
    private func saveToUserDefaults() {
        if let encoded = try? JSONEncoder().encode(allUsageHistory) {
            UserDefaults.standard.set(encoded, forKey: "usageHistory")
        }
    }
    
    private func loadFromUserDefaults() {
        if let data = UserDefaults.standard.data(forKey: "usageHistory"),
           let decoded = try? JSONDecoder().decode([Usage].self, from: data) {
            allUsageHistory = decoded
        }
    }
    
    private func loadMockDataIfNeeded() {
        // Önce UserDefaults'tan yükle
        loadFromUserDefaults()
        
        // Eğer hiç veri yoksa, mock data oluştur
        if allUsageHistory.isEmpty {
            print("İlk kullanım - Mock data yükleniyor...")
            generateMockDataFromMockConsumption()
        }
    }
    
    // Mock data'dan gerçek Usage objeleri oluştur
    private func generateMockDataFromMockConsumption() {
        let mockData = MockConsumptionData.shared
        var mockUsages: [Usage] = []
        
        // bos sayfa olmaması için
        let pedestalIds = [1, 2, 3]  // Mock pedestal IDs
        
        // Son 7 gün için mock data oluştur
        for (index, dayData) in mockData.last7Days.enumerated() {
            let pedestalId = pedestalIds[index % pedestalIds.count]
            
            // Su kullanımı
            let waterUsage = Usage(
                pedestalId: pedestalId,
                serviceType: .water,
                startTime: dayData.date,
                consumption: dayData.water,
                cost: dayData.water * 0.5 // Yaklaşık maliyet
            )
            
            // Elektrik kullanımı
            let electricityUsage = Usage(
                pedestalId: pedestalId,
                serviceType: .electricity,
                startTime: dayData.date,
                consumption: dayData.electricity,
                cost: dayData.electricity * 2.5 // Yaklaşık maliyet
            )
            
            mockUsages.append(waterUsage)
            mockUsages.append(electricityUsage)
        }
        
        // Saatlik verilerden de birkaç örnek ekle bugün için
        let today = Date()
        let todayPedestalId = pedestalIds[0]
        
        for hourData in mockData.hourlyData.prefix(4) { // İlk 4 saat
            if let hour = Int(hourData.hour.prefix(2)) {
                let calendar = Calendar.current
                let hourDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: today) ?? today
                
                // Su
                let waterUsage = Usage(
                    pedestalId: todayPedestalId,
                    serviceType: .water,
                    startTime: hourDate,
                    consumption: hourData.waterUsage,
                    cost: hourData.cost * 0.4
                )
                
                // Elektrik
                let electricityUsage = Usage(
                    pedestalId: todayPedestalId,
                    serviceType: .electricity,
                    startTime: hourDate,
                    consumption: hourData.electricityUsage,
                    cost: hourData.cost * 0.6
                )
                
                mockUsages.append(waterUsage)
                mockUsages.append(electricityUsage)
            }
        }
        
        
        addUsages(mockUsages)
        print("\(mockUsages.count) adet mock usage eklendi")
    }
    
    // Mock data'yı temizlemek için
    func resetToMockData() {
        clearHistory()
        generateMockDataFromMockConsumption()
    }
}
