import Foundation
import UserNotifications

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        requestAuthorization()
    }
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Bildirim izni verildi")
            } else if let error = error {
                print("ildirim izni hatası: \(error.localizedDescription)")
            } else {
                print("Bildirim izni reddedildi")
            }
        }
    }
    
    func sendLowBalanceNotification(balance: Double, pedestalName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Düşük Bakiye Uyarısı!"
        content.body = "\(pedestalName) istasyonundaki bakiyeniz ₺\(String(format: "%.2f", balance)) seviyesine düştü. Lütfen bakiye yükleyiniz."
        content.sound = UNNotificationSound.default
        
        // Hemen gönder (1 saniye sonra)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(identifier: "low_balance_\(Date().timeIntervalSince1970)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Bildirim gönderme hatası: \(error.localizedDescription)")
            } else {
                print("Düşük bakiye bildirimi gönderildi!")
            }
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    // Ön planda (uygulama açıkken) bildirim göstermek için gerekli
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Uygulama açıkken de bildirim (alert/banner), ses (sound) gösterilsin
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound])
        } else {
            completionHandler([.alert, .sound])
        }
    }
}
