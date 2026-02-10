import Foundation

struct Pedestal: Identifiable, Codable, Hashable {
    let id: Int  // Backend istasyonId
    let pedestalNumber: String  // portAdi
    let location: String  // istasyonAdi
    var status: Status
    var balance: Double  // İstasyondaki bakiye
    var kartId: String?
    var isWaterActive: Bool
    var isElectricityActive: Bool
    var waterUsage: Double  // litre
    var electricityUsage: Double  // kWh
    var isOccupied: Bool  // kapali flag'ı (ters mantık)
    
    // Rate bilgileri (frontend'de gösterim için - backend'den gelmez)
    var waterRate: Double = 10.0 // EUR/m³
    var electricityRate: Double = 2.5 // EUR/kWh
    
    enum Status: String, Codable, Hashable {
        case available = "Müsait"
        case occupied = "Dolu"
        case inUse = "Kullanımda"
        case maintenance = "Bakımda"
    }
    
    init(
        id: Int,
        pedestalNumber: String,
        location: String,
        status: Status = .available,
        balance: Double = 0.0,
        kartId: String? = nil,
        isWaterActive: Bool = false,
        isElectricityActive: Bool = false,
        waterUsage: Double = 0.0,
        electricityUsage: Double = 0.0,
        isOccupied: Bool = false
    ) {
        self.id = id
        self.pedestalNumber = pedestalNumber
        self.location = location
        self.status = status
        self.balance = balance
        self.kartId = kartId
        self.isWaterActive = isWaterActive
        self.isElectricityActive = isElectricityActive
        self.waterUsage = waterUsage
        self.electricityUsage = electricityUsage
        self.isOccupied = isOccupied
    }
    
    // Backend response'undan Pedestal oluştur
    static func fromResponse(_ response: PedestalResponse, istasyonBilgi: IstasyonBilgiResponse? = nil) -> Pedestal {
        var status: Status = .available
        var isOccupied = false
        var balance: Double = 0.0
        var kartId: String? = nil
        var isWaterActive = false
        var isElectricityActive = false
        var waterUsage: Double = 0.0
        var electricityUsage: Double = 0.0
        
        // Önce aktiflik kontrolü
        if !response.aktif {
            status = .maintenance
        } else if let bilgi = istasyonBilgi {
            isOccupied = bilgi.kapali ?? false
            balance = bilgi.bakiye ?? 0.0
            kartId = bilgi.kartId
            isWaterActive = bilgi.su ?? false
            isElectricityActive = bilgi.elektrik ?? false
            waterUsage = bilgi.litreTuketim ?? 0.0
            electricityUsage = bilgi.elektrikTuketim ?? 0.0
            
            // Durum belirle
            if isOccupied {
                if isWaterActive || isElectricityActive {
                    status = .inUse
                } else {
                    status = .occupied
                }
            } else {
                status = .available
            }
        }
        
        return Pedestal(
            id: response.istasyonId,
            pedestalNumber: response.portAdi,
            location: response.istasyonAdi,
            status: status,
            balance: balance,
            kartId: kartId,
            isWaterActive: isWaterActive,
            isElectricityActive: isElectricityActive,
            waterUsage: waterUsage,
            electricityUsage: electricityUsage,
            isOccupied: isOccupied
        )
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Pedestal, rhs: Pedestal) -> Bool {
        lhs.id == rhs.id
    }
    
    // Computed properties
    var waterCost: Double {
        return waterUsage * waterRate / 1000 // litre'yi m³'e çevir
    }
    
    var electricityCost: Double {
        return electricityUsage * electricityRate
    }
    
    var totalCost: Double {
        return waterCost + electricityCost
    }
}
