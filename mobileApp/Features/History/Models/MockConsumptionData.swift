import Foundation

class MockConsumptionData {
    static let shared = MockConsumptionData()
    
    // Saatlik (günlük) veriler
    let hourlyData: [HourlyConsumption] = [
        HourlyConsumption(hour: "00:00", waterUsage: 2.5, electricityUsage: 0.8, cost: 1.2),
        HourlyConsumption(hour: "04:00", waterUsage: 1.2, electricityUsage: 0.5, cost: 0.6),
        HourlyConsumption(hour: "08:00", waterUsage: 5.3, electricityUsage: 1.2, cost: 2.1),
        HourlyConsumption(hour: "12:00", waterUsage: 8.7, electricityUsage: 2.1, cost: 3.5),
        HourlyConsumption(hour: "16:00", waterUsage: 12.4, electricityUsage: 3.5, cost: 5.2),
        HourlyConsumption(hour: "20:00", waterUsage: 15.1, electricityUsage: 4.4, cost: 6.8),
    ]
    
    // Günlük (haftalık) veriler
    let dailyData: [DailyConsumption] = [
        DailyConsumption(day: "Pzt", waterUsage: 45.2, electricityUsage: 12.5, cost: 18.5),
        DailyConsumption(day: "Sal", waterUsage: 38.7, electricityUsage: 10.2, cost: 15.8),
        DailyConsumption(day: "Çar", waterUsage: 52.3, electricityUsage: 15.8, cost: 22.1),
        DailyConsumption(day: "Per", waterUsage: 41.5, electricityUsage: 11.3, cost: 17.2),
        DailyConsumption(day: "Cum", waterUsage: 48.9, electricityUsage: 13.7, cost: 20.3),
        DailyConsumption(day: "Cmt", waterUsage: 65.2, electricityUsage: 18.9, cost: 27.8),
        DailyConsumption(day: "Paz", waterUsage: 58.4, electricityUsage: 16.2, cost: 24.5),
    ]
    
    // Aylık veriler
    let monthlyData: [MonthlyConsumption] = [
        MonthlyConsumption(month: "Oca", waterUsage: 1250.5, electricityUsage: 345.2, cost: 520.8),
        MonthlyConsumption(month: "Şub", waterUsage: 1180.3, electricityUsage: 320.5, cost: 485.2),
        MonthlyConsumption(month: "Mar", waterUsage: 1320.7, electricityUsage: 368.9, cost: 552.3),
        MonthlyConsumption(month: "Nis", waterUsage: 1420.2, electricityUsage: 395.7, cost: 595.1),
        MonthlyConsumption(month: "May", waterUsage: 1580.9, electricityUsage: 425.3, cost: 658.7),
        MonthlyConsumption(month: "Haz", waterUsage: 1720.4, electricityUsage: 468.2, cost: 725.9),
    ]
    
    // Toplam istatistikler
    var totalSummary: ConsumptionSummary {
        let totalWater = monthlyData.reduce(0) { $0 + $1.waterUsage }
        let totalElectricity = monthlyData.reduce(0) { $0 + $1.electricityUsage }
        let totalCost = monthlyData.reduce(0) { $0 + $1.cost }
        
        return ConsumptionSummary(
            totalWater: totalWater,
            totalElectricity: totalElectricity,
            totalCost: totalCost,
            averageDailyWater: totalWater / Double(monthlyData.count * 30), // Yaklaşık
            averageDailyElectricity: totalElectricity / Double(monthlyData.count * 30),
            averageDailyCost: totalCost / Double(monthlyData.count * 30)
        )
    }
    
    // Son 7 günün verileri (grafik için)
    let last7Days: [(date: Date, water: Double, electricity: Double, cost: Double)] = [
        (Date().addingTimeInterval(-6 * 24 * 3600), 42.3, 11.8, 16.5),
        (Date().addingTimeInterval(-5 * 24 * 3600), 38.7, 10.2, 15.8),
        (Date().addingTimeInterval(-4 * 24 * 3600), 52.3, 15.8, 22.1),
        (Date().addingTimeInterval(-3 * 24 * 3600), 41.5, 11.3, 17.2),
        (Date().addingTimeInterval(-2 * 24 * 3600), 48.9, 13.7, 20.3),
        (Date().addingTimeInterval(-1 * 24 * 3600), 65.2, 18.9, 27.8),
        (Date(), 58.4, 16.2, 24.5)
    ]
    
    // Fiyatlandırma bilgisi
    struct Pricing {
        let waterPricePerLitre = 0.05 // TL/litre
        let electricityPricePerKwh = 0.70 // TL/kWh
    }
    
    let pricing = Pricing()
    
    // Tarih formatlayıcı
    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.string(from: date)
    }
    
    static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
