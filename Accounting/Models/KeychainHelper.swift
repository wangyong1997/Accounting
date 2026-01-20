import Foundation
import Security

/// Keychain 辅助类：安全存储敏感信息
class KeychainHelper {
    // MARK: - Constants
    private static let service = "com.pixelledger.ai"
    private static let apiKeyKey = "ai_api_key"
    
    // MARK: - Save API Key
    
    /// 保存 API Key 到 Keychain
    /// - Parameter apiKey: API 密钥
    /// - Returns: 是否保存成功
    @discardableResult
    static func saveAPIKey(_ apiKey: String) -> Bool {
        // 先删除旧的（如果存在）
        deleteAPIKey()
        
        guard let data = apiKey.data(using: .utf8) else {
            print("❌ [KeychainHelper] 无法将 API Key 转换为 Data")
            return false
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            print("✅ [KeychainHelper] API Key 已保存到 Keychain")
            return true
        } else {
            print("❌ [KeychainHelper] 保存失败: \(status)")
            return false
        }
    }
    
    // MARK: - Read API Key
    
    /// 从 Keychain 读取 API Key
    /// - Returns: API 密钥，如果不存在则返回 nil
    static func readAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let apiKey = String(data: data, encoding: .utf8) {
            return apiKey
        } else if status == errSecItemNotFound {
            print("ℹ️ [KeychainHelper] Keychain 中未找到 API Key")
            return nil
        } else {
            print("❌ [KeychainHelper] 读取失败: \(status)")
            return nil
        }
    }
    
    // MARK: - Delete API Key
    
    /// 从 Keychain 删除 API Key
    /// - Returns: 是否删除成功
    @discardableResult
    static func deleteAPIKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyKey
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status == errSecSuccess || status == errSecItemNotFound {
            print("✅ [KeychainHelper] API Key 已从 Keychain 删除")
            return true
        } else {
            print("❌ [KeychainHelper] 删除失败: \(status)")
            return false
        }
    }
    
    // MARK: - Check if API Key exists
    
    /// 检查 Keychain 中是否存在 API Key
    /// - Returns: 是否存在
    static func hasAPIKey() -> Bool {
        return readAPIKey() != nil
    }
}
