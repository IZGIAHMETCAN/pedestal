import Foundation
import Security

// Keychain'e güvenli veri saklama ve okuma için
final class KeychainHelper {
    
    static let shared = KeychainHelper()
    private init() {}
    
    // MARK: - Save
    
    // Keychain'e string değer kaydet
    func save(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        return save(data, forKey: key)
    }
    
    // Keychain'e Data kaydet
    func save(_ data: Data, forKey key: String) -> Bool {
        // Önce mevcut varsa sil
        delete(forKey: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    // MARK: - Retrieve
    
    func getString(forKey key: String) -> String? {
        guard let data = getData(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    
    func getData(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }
    
    // MARK: - Delete
    
    @discardableResult
    func delete(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // MARK: - Clear All
    
    // Tüm keychain verilerini sil logout için
    @discardableResult
    func clearAll() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

// MARK: - Convenience Keys

extension KeychainHelper {
    /// Token için özel key
    private static let tokenKey = "com.marina.authToken"
    
    /// Token kaydet
    func saveToken(_ token: String) -> Bool {
        return save(token, forKey: Self.tokenKey)
    }
    
    /// Token oku
    func getToken() -> String? {
        return getString(forKey: Self.tokenKey)
    }
    
    /// Token sil
    func deleteToken() -> Bool {
        return delete(forKey: Self.tokenKey)
    }
}
