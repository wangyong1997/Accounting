import Foundation
import SwiftUI
import Security
import Combine

/// LLM 配置管理器
@MainActor
class LLMManager: ObservableObject {
    // MARK: - Singleton
    static let shared = LLMManager()
    
    // MARK: - Published Properties
    @Published var configs: [LLMConfig] = []
    @AppStorage("llm_active_config_id") var activeConfigId: String = ""
    
    // MARK: - Constants
    private let configsKey = "llm_configs"
    
    private init() {
        loadConfigs()
    }
    
    // MARK: - Load Configs
    
    /// 从 AppStorage 加载配置列表
    private func loadConfigs() {
        guard let data = UserDefaults.standard.data(forKey: configsKey),
              let decoded = try? JSONDecoder().decode([LLMConfig].self, from: data) else {
            // 如果没有保存的配置，创建默认配置
            configs = []
            return
        }
        configs = decoded
    }
    
    /// 保存配置列表到 AppStorage
    private func saveConfigs() {
        if let encoded = try? JSONEncoder().encode(configs) {
            UserDefaults.standard.set(encoded, forKey: configsKey)
        }
    }
    
    // MARK: - CRUD Operations
    
    /// 保存配置（元数据到 AppStorage，API Key 到 Keychain）
    /// - Parameters:
    ///   - config: LLM 配置
    ///   - apiKey: API 密钥
    func saveConfig(_ config: LLMConfig, apiKey: String) {
        // 保存 API Key 到 Keychain（使用 config.id 作为 key）
        let keychainKey = "llm_api_key_\(config.id.uuidString)"
        guard saveAPIKeyToKeychain(apiKey, key: keychainKey) else {
            print("❌ [LLMManager] 保存 API Key 到 Keychain 失败")
            return
        }
        
        // 更新或添加配置
        if let index = configs.firstIndex(where: { $0.id == config.id }) {
            configs[index] = config
        } else {
            configs.append(config)
        }
        
        saveConfigs()
        
        // 如果这是第一个配置，自动设置为活动配置
        if activeConfigId.isEmpty {
            activeConfigId = config.id.uuidString
        }
        
        print("✅ [LLMManager] 配置已保存: \(config.name)")
    }
    
    /// 删除配置
    /// - Parameter config: 要删除的配置
    func deleteConfig(_ config: LLMConfig) {
        // 从 Keychain 删除 API Key
        let keychainKey = "llm_api_key_\(config.id.uuidString)"
        deleteAPIKeyFromKeychain(key: keychainKey)
        
        // 从列表中删除
        configs.removeAll { $0.id == config.id }
        saveConfigs()
        
        // 如果删除的是活动配置，切换到第一个配置（如果有）
        if activeConfigId == config.id.uuidString {
            activeConfigId = configs.first?.id.uuidString ?? ""
        }
        
        print("✅ [LLMManager] 配置已删除: \(config.name)")
    }
    
    /// 获取活动配置
    var activeConfig: LLMConfig? {
        guard let activeId = UUID(uuidString: activeConfigId) else {
            return configs.first
        }
        return configs.first { $0.id == activeId } ?? configs.first
    }
    
    /// 设置活动配置
    func setActiveConfig(_ config: LLMConfig) {
        activeConfigId = config.id.uuidString
        print("✅ [LLMManager] 活动配置已切换: \(config.name)")
    }
    
    /// 获取配置的 API Key（从 Keychain）
    /// - Parameter config: LLM 配置
    /// - Returns: API 密钥，如果不存在则返回 nil（已清理空格和换行符）
    func getAPIKey(for config: LLMConfig) -> String? {
        let keychainKey = "llm_api_key_\(config.id.uuidString)"
        guard let key = readAPIKeyFromKeychain(key: keychainKey) else {
            return nil
        }
        // 清理 API Key（去除前后空格和换行符），避免认证失败
        return key.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Keychain Helpers
    
    private func saveAPIKeyToKeychain(_ apiKey: String, key: String) -> Bool {
        // 先删除旧的（如果存在）
        deleteAPIKeyFromKeychain(key: key)
        
        guard let data = apiKey.data(using: .utf8) else {
            return false
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.pixelledger.llm",
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    private func readAPIKeyFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.pixelledger.llm",
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let apiKey = String(data: data, encoding: .utf8) {
            return apiKey
        }
        
        return nil
    }
    
    private func deleteAPIKeyFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.pixelledger.llm",
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}
