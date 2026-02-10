import Foundation

struct Usage: Identifiable, Codable {
    let id: UUID
    let pedestalId: Int
    let serviceType: ServiceType
    let startTime: Date
    var endTime: Date?
    var duration: TimeInterval // Saniye cinsinden
    var consumption: Double // kWh veya m³
    var cost: Double // TL
    var isActive: Bool
    
    enum ServiceType: String, Codable {
        case electricity = "Elektrik"
        case water = "Su"
    }
    
    init(
        id: UUID = UUID(),
        pedestalId: Int,
        serviceType: ServiceType,
        startTime: Date = Date(),
        consumption: Double = 0.0,
        cost: Double = 0.0
    ) {
        self.id = id
        self.pedestalId = pedestalId
        self.serviceType = serviceType
        self.startTime = startTime
        self.endTime = nil
        self.duration = 0
        self.consumption = consumption
        self.cost = cost
        self.isActive = true
    }
}

struct PaymentTransaction: Identifiable, Codable {
    let id: UUID
    let date: Date
    let amount: Double
    let type: TransactionType
    let description: String
    let pedestalNumber: String
    
    enum TransactionType: String, Codable {
        case debit = "Ödeme"
        case credit = "Yükleme"
        case refund = "İade"
    }
}

struct UserBalance: Codable {
    var currentBalance: Double
    var totalSpent: Double
    var lastUpdated: Date
    var paymentHistory: [PaymentTransaction]
}
