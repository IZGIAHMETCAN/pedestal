import Foundation

// Tüketim verisi modeli
struct Consumption: Identifiable, Codable {
    let id: UUID
    let date: Date
    let waterUsage: Double
    let electricityUsage: Double
    let cost: Double
    let duration: TimeInterval?
    
    init(id: UUID = UUID(), date: Date, waterUsage: Double, electricityUsage: Double, cost: Double, duration: TimeInterval? = nil) {
        self.id = id
        self.date = date
        self.waterUsage = waterUsage
        self.electricityUsage = electricityUsage
        self.cost = cost
        self.duration = duration
    }
}

// Günlük saatlik tüketim
struct HourlyConsumption: Identifiable, Codable {
    let id: UUID
    let hour: String           
    let waterUsage: Double
    let electricityUsage: Double
    let cost: Double
    
    init(id: UUID = UUID(), hour: String, waterUsage: Double, electricityUsage: Double, cost: Double) {
        self.id = id
        self.hour = hour
        self.waterUsage = waterUsage
        self.electricityUsage = electricityUsage
        self.cost = cost
    }
}

// Haftalık günlük tüketim
struct DailyConsumption: Identifiable, Codable {
    let id: UUID
    let day: String
    let waterUsage: Double
    let electricityUsage: Double
    let cost: Double
    let fullDayName: String
    
    init(id: UUID = UUID(), day: String, waterUsage: Double, electricityUsage: Double, cost: Double) {
        self.id = id
        self.day = day
        self.waterUsage = waterUsage
        self.electricityUsage = electricityUsage
        self.cost = cost
        self.fullDayName = DailyConsumption.getFullDayName(for: day)
    }
    
    private static func getFullDayName(for shortName: String) -> String {
        switch shortName {
        case "Pzt": return "Pazartesi"
        case "Sal": return "Salı"
        case "Çar": return "Çarşamba"
        case "Per": return "Perşembe"
        case "Cum": return "Cuma"
        case "Cmt": return "Cumartesi"
        case "Paz": return "Pazar"
        default: return shortName
        }
    }
}

// Aylık tüketim
struct MonthlyConsumption: Identifiable, Codable {
    let id: UUID
    let month: String
    let waterUsage: Double
    let electricityUsage: Double
    let cost: Double
    let fullMonthName: String
    
    init(id: UUID = UUID(), month: String, waterUsage: Double, electricityUsage: Double, cost: Double) {
        self.id = id
        self.month = month
        self.waterUsage = waterUsage
        self.electricityUsage = electricityUsage
        self.cost = cost
        self.fullMonthName = MonthlyConsumption.getFullMonthName(for: month)
    }
    
    private static func getFullMonthName(for shortName: String) -> String {
        switch shortName {
        case "Oca": return "Ocak"
        case "Şub": return "Şubat"
        case "Mar": return "Mart"
        case "Nis": return "Nisan"
        case "May": return "Mayıs"
        case "Haz": return "Haziran"
        case "Tem": return "Temmuz"
        case "Ağu": return "Ağustos"
        case "Eyl": return "Eylül"
        case "Eki": return "Ekim"
        case "Kas": return "Kasım"
        case "Ara": return "Aralık"
        default: return shortName
        }
    }
}

// Özet istatistikler
struct ConsumptionSummary {
    let totalWater: Double
    let totalElectricity: Double
    let totalCost: Double
    let averageDailyWater: Double
    let averageDailyElectricity: Double
    let averageDailyCost: Double
}

// Tüketim tipi enum'u
enum ConsumptionType: String, CaseIterable {
    case water = "Su"
    case electricity = "Elektrik"
    case cost = "Maliyet"
    
    var unit: String {
        switch self {
        case .water: return "Litre"
        case .electricity: return "kWh"
        case .cost: return "TL"
        }
    }
    
    var icon: String {
        switch self {
        case .water: return "drop.fill"
        case .electricity: return "bolt.fill"
        case .cost: return "turkishlirasign.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .water: return "blue"
        case .electricity: return "yellow"
        case .cost: return "green"
        }
    }
}

// Zaman periyodu enum'u
enum TimePeriod: String, CaseIterable {
    case daily = "Günlük"
    case weekly = "Haftalık"
    case monthly = "Aylık"
    
    var icon: String {
        switch self {
        case .daily: return "calendar.day.timeline.left"
        case .weekly: return "calendar"
        case .monthly: return "chart.bar.fill"
        }
    }
}
