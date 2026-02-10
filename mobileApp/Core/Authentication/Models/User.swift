import Foundation

struct User: Identifiable, Codable {
    let id: UUID
    var email: String
    var password: String  // Local use only, not sent to backend
    var name: String
    var boatName: String
    var adress: String
    var tcIdentityNumber: String
    var balance: Double
    var savedCard: Savedcard?
    
    init(id: UUID = UUID(),
         email: String,
         password: String,
         name: String = "",
         boatName: String = "",
         adress: String = "",
         tcIdentityNumber: String = "",
         balance: Double = 0.0,
         savedCard: Savedcard? = nil) {
        self.id = id
        self.email = email
        self.password = password
        self.name = name
        self.boatName = boatName
        self.adress = adress
        self.tcIdentityNumber = tcIdentityNumber
        self.balance = balance
        self.savedCard = savedCard
    }
}

struct Savedcard: Codable {
    var cardHolderName: String
    var cardNumber: String // Masked: ** ** ** 1234
    var expirationDate: String // MM/YY
    var cvv: String
}


