import Foundation
import SwiftData

/// AI服务错误类型
enum AIServiceError: LocalizedError {
    case invalidConfiguration
    case networkError(Error)
    case invalidResponse
    case decodingError(Error)
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "AI服务配置无效，请检查API密钥和基础URL"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .invalidResponse:
            return "服务器返回了无效的响应"
        case .decodingError(let error):
            return "解析响应失败: \(error.localizedDescription)"
        case .apiError(let message):
            return "API错误: \(message)"
        }
    }
}

/// AI解析结果
struct AIResult: Codable {
    let amount: Double?
    let categoryName: String?
    let accountName: String?
    let note: String?
    let date: String? // ISO8601格式或相对偏移（如"-1d"表示昨天）
    
    enum CodingKeys: String, CodingKey {
        case amount
        case categoryName = "category_name"
        case accountName = "account_name"
        case note
        case date
    }
}

/// 语音输入解析结果
struct VoiceTransactionResult: Codable {
    let amount: Double?
    let category: String?
    let note: String?
    let date: String? // ISO8601格式
    let account: String?
    
    enum CodingKeys: String, CodingKey {
        case amount
        case category
        case note
        case date
        case account
    }
}

/// 查询意图（用于AI识别用户想要查询的数据）
struct QueryIntent: Codable {
    enum Operation: String, Codable {
        case sum // 计算总和（如"总共花了多少钱"）
        case list // 获取原始记录列表（如"显示我的交易"）
        case count // 计算记录数量（如"多少次"）
        case chat // 普通聊天（需要返回 chatResponse）
        case unknown // 未知操作（向后兼容）
    }
    
    let operation: Operation
    let startDate: String? // ISO8601格式（YYYY-MM-DDTHH:mm:ss）或相对偏移（如"-30d"）
    let endDate: String? // ISO8601格式（YYYY-MM-DDTHH:mm:ss）或相对偏移（如"today"）
    let categoryName: String? // 按分类筛选（如果用户提到，需要匹配可用分类列表）
    let accountName: String? // 按账户筛选（如果用户提到，需要匹配可用账户列表）
    let chatResponse: String? // 仅当 operation 为 "chat" 时使用，提供友好的回复
    
    enum CodingKeys: String, CodingKey {
        case operation
        case startDate = "startDate"
        case endDate = "endDate"
        case categoryName = "category"
        case accountName = "account"
        case chatResponse = "chatResponse"
    }
}

/// AI服务配置
struct AIConfiguration {
    let apiKey: String
    let baseURL: String
    let model: String
    
    static var `default`: AIConfiguration? {
        // 从Info.plist读取配置
        guard let path = Bundle.main.path(forResource: "AIConfig", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let apiKey = plist["APIKey"] as? String,
              let baseURL = plist["BaseURL"] as? String,
              let model = plist["Model"] as? String else {
            return nil
        }
        return AIConfiguration(apiKey: apiKey, baseURL: baseURL, model: model)
    }
    
    // 从Keychain和AppStorage读取（安全方式）
    static func fromSecureStorage() -> AIConfiguration? {
        // 从Keychain读取API Key
        guard let apiKey = KeychainHelper.readAPIKey(), !apiKey.isEmpty else {
            return nil
        }
        
        // 从AppStorage读取baseURL和model
        let baseURL = UserDefaults.standard.string(forKey: "ai_base_url") ?? "https://api.openai.com/v1"
        let model = UserDefaults.standard.string(forKey: "ai_model") ?? "gpt-3.5-turbo"
        
        return AIConfiguration(apiKey: apiKey, baseURL: baseURL, model: model)
    }
    
    // 从UserDefaults读取（向后兼容，已废弃）
    static func fromUserDefaults() -> AIConfiguration? {
        // 先尝试从Keychain读取（新方式）
        if let config = fromSecureStorage() {
            return config
        }
        
        // 如果没有，尝试从UserDefaults读取（旧方式，迁移用）
        let apiKey = UserDefaults.standard.string(forKey: "ai_api_key") ?? ""
        let baseURL = UserDefaults.standard.string(forKey: "ai_base_url") ?? "https://api.openai.com/v1"
        let model = UserDefaults.standard.string(forKey: "ai_model") ?? "gpt-3.5-turbo"
        
        guard !apiKey.isEmpty else {
            return nil
        }
        
        // 如果从UserDefaults读取到，迁移到Keychain
        if KeychainHelper.saveAPIKey(apiKey) {
            // 迁移成功后，从UserDefaults删除（可选）
            UserDefaults.standard.removeObject(forKey: "ai_api_key")
        }
        
        return AIConfiguration(apiKey: apiKey, baseURL: baseURL, model: model)
    }
}

/// AI服务：处理LLM API调用
@MainActor
class AIService {
    // MARK: - Singleton
    static let shared = AIService()
    
    // MARK: - Configuration
    private var configuration: AIConfiguration?
    
    private init() {
        // 优先从Keychain和AppStorage读取，如果没有则从plist读取
        loadConfiguration()
    }
    
    /// 加载配置（从Keychain和AppStorage）
    private func loadConfiguration() {
        configuration = AIConfiguration.fromSecureStorage() ?? AIConfiguration.fromUserDefaults() ?? AIConfiguration.default
    }
    
    // MARK: - Configuration Management
    
    /// 更新配置
    /// - Parameters:
    ///   - apiKey: API密钥
    ///   - baseURL: 基础URL（可选，默认使用OpenAI）
    ///   - model: 模型名称（可选，默认gpt-3.5-turbo）
    func updateConfiguration(apiKey: String, baseURL: String? = nil, model: String? = nil) {
        // 处理baseURL：移除尾部斜杠，确保格式正确
        var finalBaseURL = baseURL ?? UserDefaults.standard.string(forKey: "ai_base_url") ?? "https://api.openai.com/v1"
        finalBaseURL = finalBaseURL.trimmingCharacters(in: .whitespaces)
        if finalBaseURL.hasSuffix("/") {
            finalBaseURL = String(finalBaseURL.dropLast())
        }
        
        let finalModel = model ?? UserDefaults.standard.string(forKey: "ai_model") ?? "gpt-3.5-turbo"
        
        // 保存API Key到Keychain（安全存储）
        guard KeychainHelper.saveAPIKey(apiKey) else {
            print("❌ [AIService] 保存API Key到Keychain失败")
            return
        }
        
        // 保存baseURL和model到AppStorage（非敏感信息）
        UserDefaults.standard.set(finalBaseURL, forKey: "ai_base_url")
        UserDefaults.standard.set(finalModel, forKey: "ai_model")
        
        // 更新内存中的配置
        configuration = AIConfiguration(apiKey: apiKey, baseURL: finalBaseURL, model: finalModel)
        
        print("✅ [AIService] 配置已更新")
    }
    
    /// 获取当前配置（用于测试时临时保存和外部访问）
    func getCurrentConfigurationForTesting() -> AIConfiguration? {
        return configuration
    }
    
    /// 检查配置是否有效
    var isConfigured: Bool {
        return loadCurrentConfiguration() != nil
    }
    
    /// 加载当前配置（动态读取）
    private func loadCurrentConfiguration() -> AIConfiguration? {
        // 每次请求时动态读取，确保使用最新配置
        return AIConfiguration.fromSecureStorage() ?? AIConfiguration.fromUserDefaults() ?? AIConfiguration.default
    }
    
    /// 测试连接（使用指定配置）
    /// - Parameters:
    ///   - config: LLM 配置
    ///   - apiKey: API 密钥
    /// - Returns: 是否连接成功
    func testConnection(config: LLMConfig, apiKey: String) async throws -> Bool {
        // 构建请求URL
        var baseURL = config.baseURL.trimmingCharacters(in: .whitespaces)
        if baseURL.hasSuffix("/") {
            baseURL = String(baseURL.dropLast())
        }
        
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw AIServiceError.invalidConfiguration
        }
        
        // 构建简单的测试请求
        let requestBody: [String: Any] = [
            "model": config.modelName,
            "messages": [
                [
                    "role": "user",
                    "content": "test"
                ]
            ],
            "max_tokens": 5
        ]
        
        // 创建请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0 // 10秒超时
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw AIServiceError.decodingError(error)
        }
        
        // 发送请求
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            // 检查HTTP状态码
            if let httpResponse = response as? HTTPURLResponse {
                // 200-299 表示成功，400-499 表示配置问题，500+ 表示服务器错误
                // 对于测试，只要不是网络错误，都认为配置可能有效
                return (200...499).contains(httpResponse.statusCode)
            }
            
            return false
        } catch {
            throw AIServiceError.networkError(error)
        }
    }
    
    /// 测试连接（使用当前配置）
    /// - Returns: 是否连接成功
    func testConnection() async throws -> Bool {
        guard let config = loadCurrentConfiguration() else {
            throw AIServiceError.invalidConfiguration
        }
        
        // 构建请求URL
        var baseURL = config.baseURL.trimmingCharacters(in: .whitespaces)
        if baseURL.hasSuffix("/") {
            baseURL = String(baseURL.dropLast())
        }
        
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw AIServiceError.invalidConfiguration
        }
        
        // 构建简单的测试请求
        let requestBody: [String: Any] = [
            "model": config.model,
            "messages": [
                [
                    "role": "user",
                    "content": "test"
                ]
            ],
            "max_tokens": 5
        ]
        
        // 创建请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0 // 10秒超时
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw AIServiceError.decodingError(error)
        }
        
        // 发送请求
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            // 检查HTTP状态码
            if let httpResponse = response as? HTTPURLResponse {
                // 200-299 表示成功，400-499 表示配置问题，500+ 表示服务器错误
                // 对于测试，只要不是网络错误，都认为配置可能有效
                return (200...499).contains(httpResponse.statusCode)
            }
            
            return false
        } catch {
            throw AIServiceError.networkError(error)
        }
    }
    
    // MARK: - API Request
    
    /// 解析交易文本（使用Category和Account对象，支持指定配置）
    /// - Parameters:
    ///   - text: 用户输入的文本
    ///   - categories: 当前可用的分类列表
    ///   - accounts: 当前可用的账户列表
    ///   - config: LLM 配置（可选，如果为 nil 则使用当前配置）
    /// - Returns: AI解析结果
    func parseTransaction(
        text: String,
        categories: [Category],
        accounts: [Account],
        config: LLMConfig? = nil
    ) async throws -> AIResult {
        let llmConfig: LLMConfig
        let apiKey: String
        
        if let providedConfig = config {
            // 使用提供的配置
            llmConfig = providedConfig
            // 从 Keychain 读取 API Key
            guard let key = LLMManager.shared.getAPIKey(for: providedConfig) else {
                throw AIServiceError.invalidConfiguration
            }
            apiKey = key // getAPIKey 已经清理过了 // getAPIKey 已经清理过了
        } else {
            // 使用当前配置（向后兼容）
            guard let currentConfig = loadCurrentConfiguration() else {
                throw AIServiceError.invalidConfiguration
            }
            llmConfig = LLMConfig(
                name: "Current",
                providerType: .custom,
                baseURL: currentConfig.baseURL,
                modelName: currentConfig.model
            )
            // 清理 API Key（去除前后空格和换行符）
            apiKey = currentConfig.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // 构建请求URL（处理尾部斜杠）
        var baseURL = llmConfig.baseURL.trimmingCharacters(in: .whitespaces)
        if baseURL.hasSuffix("/") {
            baseURL = String(baseURL.dropLast())
        }
        
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw AIServiceError.invalidConfiguration
        }
        
        // 使用新的generatePrompt函数构建提示词
        let systemPrompt = generatePrompt(input: text, categories: categories, accounts: accounts)
        let userPrompt = text
        
        return try await performAPIRequestWithKey(url: url, systemPrompt: systemPrompt, userPrompt: userPrompt, modelName: llmConfig.modelName, apiKey: apiKey)
    }
    
    // MARK: - Voice Input Parsing
    
    /// 解析语音输入文本为结构化交易数据
    /// - Parameters:
    ///   - text: 语音转录的文本
    ///   - categories: 可用的分类名称列表（字符串数组）
    ///   - config: LLM 配置（可选）
    /// - Returns: 语音交易解析结果
    func parseVoiceInput(
        _ text: String,
        categories: [String],
        config: LLMConfig? = nil
    ) async throws -> VoiceTransactionResult {
        let llmConfig: LLMConfig
        let apiKey: String
        
        if let providedConfig = config {
            llmConfig = providedConfig
            guard let key = LLMManager.shared.getAPIKey(for: providedConfig) else {
                throw AIServiceError.invalidConfiguration
            }
            apiKey = key
        } else {
            guard let currentConfig = loadCurrentConfiguration() else {
                throw AIServiceError.invalidConfiguration
            }
            llmConfig = LLMConfig(
                name: "Current",
                providerType: .custom,
                baseURL: currentConfig.baseURL,
                modelName: currentConfig.model
            )
            apiKey = currentConfig.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // 构建请求URL
        var baseURL = llmConfig.baseURL.trimmingCharacters(in: .whitespaces)
        if baseURL.hasSuffix("/") {
            baseURL = String(baseURL.dropLast())
        }
        
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw AIServiceError.invalidConfiguration
        }
        
        // 生成语音输入解析的系统提示词
        let systemPrompt = generateVoiceInputPrompt(categories: categories)
        let userPrompt = "User said: '\(text)'"
        
        return try await performVoiceInputRequest(url: url, systemPrompt: systemPrompt, userPrompt: userPrompt, modelName: llmConfig.modelName, apiKey: apiKey)
    }
    
    /// 生成语音输入解析的系统提示词
    /// - Parameter categories: 可用的分类名称列表
    /// - Returns: 系统提示词字符串
    private func generateVoiceInputPrompt(categories: [String]) -> String {
        let categoriesList = categories.joined(separator: ", ")
        
        // 格式化日期为 ISO8601
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withTimeZone]
        let todayString = iso8601Formatter.string(from: Date())
        
        // 计算常用日期
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let yesterdayString = iso8601Formatter.string(from: yesterday)
        
        return """
        You are a transaction parser for a bookkeeping app. Extract structured data from the user's spoken input.
        
        **Today is:** \(todayString)
        **Yesterday is:** \(yesterdayString)
        
        **Available Categories:** [\(categoriesList)]
        
        **Extract the following fields into JSON:**
        - `amount`: Double (Required. If missing or cannot be determined, return null).
        - `category`: String (Find the best match from Available Categories. If no match found, use '其他' or 'Others').
        - `note`: String (Keep the original context from user's input, e.g., 'Lunch', '午饭', '打车').
        - `date`: String (ISO8601 format. Handle relative dates: 'yesterday'/'昨天' -> yesterday's date, 'last night'/'昨晚' -> yesterday's date, 'today'/'今天' -> today's date. If not mentioned, use today's date).
        - `account`: String (Guess from context: 'WeChat'/'微信' -> '微信支付', 'Alipay'/'支付宝' -> '支付宝', 'Cash'/'现金' -> '现金'. If not mentioned, return null).
        
        **Output Format:**
        Return ONLY raw JSON. No markdown, no explanations, no code blocks, no backticks.
        The JSON must be valid and parseable.
        
        **Required JSON Structure:**
        {
            "amount": <number or null>,
            "category": "<string from available categories or '其他'>",
            "note": "<string or null>",
            "date": "<ISO8601 date string>",
            "account": "<string or null>"
        }
        
        **Example Input:** "刚刚吃了午饭花了13"
        **Example Output:** {"amount": 13.0, "category": "餐饮", "note": "午饭", "date": "\(todayString)", "account": null}
        
        **Example Input:** "昨天打车回家花了50块，用微信付的"
        **Example Output:** {"amount": 50.0, "category": "出租车", "note": "打车回家", "date": "\(yesterdayString)", "account": "微信支付"}
        
        **Example Input:** "买了一杯咖啡15元"
        **Example Output:** {"amount": 15.0, "category": "零食", "note": "咖啡", "date": "\(todayString)", "account": null}
        
        **Important Rules:**
        1. amount is REQUIRED if a number is mentioned, otherwise return null
        2. category must be from the provided list or '其他'/'Others'
        3. note should preserve the original meaning from user's input
        4. date must be in ISO8601 format (YYYY-MM-DDTHH:mm:ssZ)
        5. account should be guessed from context or null
        6. Return ONLY the JSON object, nothing else
        """
    }
    
    /// 执行语音输入解析的 API 请求
    private func performVoiceInputRequest(
        url: URL,
        systemPrompt: String,
        userPrompt: String,
        modelName: String,
        apiKey: String
    ) async throws -> VoiceTransactionResult {
        // 构建请求体
        let requestBody: [String: Any] = [
            "model": modelName,
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user",
                    "content": userPrompt
                ]
            ],
            "temperature": 0.1, // 低温度以获得更一致的结果
            "max_tokens": 200
        ]
        
        // 创建请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw AIServiceError.decodingError(error)
        }
        
        // 发送请求
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // 检查HTTP状态码
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIServiceError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw AIServiceError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
            }
            
            // 解析响应
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                throw AIServiceError.invalidResponse
            }
            
            // 清理内容（移除可能的markdown代码块）
            var cleanedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanedContent.hasPrefix("```json") {
                cleanedContent = String(cleanedContent.dropFirst(7))
            } else if cleanedContent.hasPrefix("```") {
                cleanedContent = String(cleanedContent.dropFirst(3))
            }
            if cleanedContent.hasSuffix("```") {
                cleanedContent = String(cleanedContent.dropLast(3))
            }
            cleanedContent = cleanedContent.trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard let contentData = cleanedContent.data(using: .utf8) else {
                throw AIServiceError.invalidResponse
            }
            
            // 解析JSON内容
            let decoder = JSONDecoder()
            let result = try decoder.decode(VoiceTransactionResult.self, from: contentData)
            
            print("✅ [AIService] 语音输入解析成功: \(result)")
            return result
            
        } catch let error as AIServiceError {
            throw error
        } catch {
            throw AIServiceError.networkError(error)
        }
    }
    
    /// 执行API请求（使用指定的配置和API Key）
    private func performAPIRequestWithKey(
        url: URL,
        systemPrompt: String,
        userPrompt: String,
        modelName: String,
        apiKey: String
    ) async throws -> AIResult {
        // 构建请求体
        let requestBody: [String: Any] = [
            "model": modelName,
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user",
                    "content": userPrompt
                ]
            ],
            "temperature": 0.3,
            "response_format": [
                "type": "json_object"
            ]
        ]
        
        // 创建请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw AIServiceError.decodingError(error)
        }
        
        // 发送请求
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // 检查HTTP状态码
            if let httpResponse = response as? HTTPURLResponse {
                guard (200...299).contains(httpResponse.statusCode) else {
                    // 尝试解析错误信息
                    if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = errorData["error"] as? [String: Any],
                       let message = errorMessage["message"] as? String {
                        throw AIServiceError.apiError(message)
                    }
                    throw AIServiceError.apiError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            // 解析响应
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                throw AIServiceError.invalidResponse
            }
            
            // 清理内容：移除可能的markdown代码块标记
            var cleanedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanedContent.hasPrefix("```json") {
                cleanedContent = String(cleanedContent.dropFirst(7))
            }
            if cleanedContent.hasPrefix("```") {
                cleanedContent = String(cleanedContent.dropFirst(3))
            }
            if cleanedContent.hasSuffix("```") {
                cleanedContent = String(cleanedContent.dropLast(3))
            }
            cleanedContent = cleanedContent.trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard let contentData = cleanedContent.data(using: .utf8) else {
                throw AIServiceError.invalidResponse
            }
            
            // 解析JSON内容
            let decoder = JSONDecoder()
            let result = try decoder.decode(AIResult.self, from: contentData)
            
            print("✅ [AIService] 解析成功: \(result)")
            return result
            
        } catch let error as AIServiceError {
            throw error
        } catch {
            throw AIServiceError.networkError(error)
        }
    }
    
    /// 解析交易文本（使用字符串数组，向后兼容）
    /// - Parameters:
    ///   - text: 用户输入的文本
    ///   - currentCategories: 当前可用的分类列表（字符串）
    ///   - currentAccounts: 当前可用的账户列表（字符串）
    /// - Returns: AI解析结果
    func parseTransaction(
        text: String,
        currentCategories: [String],
        currentAccounts: [String]
    ) async throws -> AIResult {
        // 动态读取配置
        guard let config = loadCurrentConfiguration() else {
            throw AIServiceError.invalidConfiguration
        }
        
        // 构建请求URL（处理尾部斜杠）
        var baseURL = config.baseURL.trimmingCharacters(in: .whitespaces)
        if baseURL.hasSuffix("/") {
            baseURL = String(baseURL.dropLast())
        }
        
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw AIServiceError.invalidConfiguration
        }
        
        // 使用旧的buildSystemPrompt方法（向后兼容）
        let systemPrompt = buildSystemPrompt(categories: currentCategories, accounts: currentAccounts)
        let userPrompt = text
        
        return try await performAPIRequest(url: url, systemPrompt: systemPrompt, userPrompt: userPrompt, config: config)
    }
    
    /// 执行API请求（内部方法）
    private func performAPIRequest(
        url: URL,
        systemPrompt: String,
        userPrompt: String,
        config: AIConfiguration
    ) async throws -> AIResult {
        
        // 构建请求体
        let requestBody: [String: Any] = [
            "model": config.model,
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user",
                    "content": userPrompt
                ]
            ],
            "temperature": 0.3,
            "response_format": [
                "type": "json_object"
            ]
        ]
        
        // 创建请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw AIServiceError.decodingError(error)
        }
        
        // 发送请求
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // 检查HTTP状态码
            if let httpResponse = response as? HTTPURLResponse {
                guard (200...299).contains(httpResponse.statusCode) else {
                    // 尝试解析错误信息
                    if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = errorData["error"] as? [String: Any],
                       let message = errorMessage["message"] as? String {
                        throw AIServiceError.apiError(message)
                    }
                    throw AIServiceError.apiError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            // 解析响应
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                throw AIServiceError.invalidResponse
            }
            
            // 清理内容：移除可能的markdown代码块标记
            var cleanedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanedContent.hasPrefix("```json") {
                cleanedContent = String(cleanedContent.dropFirst(7))
            }
            if cleanedContent.hasPrefix("```") {
                cleanedContent = String(cleanedContent.dropFirst(3))
            }
            if cleanedContent.hasSuffix("```") {
                cleanedContent = String(cleanedContent.dropLast(3))
            }
            cleanedContent = cleanedContent.trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard let contentData = cleanedContent.data(using: .utf8) else {
                throw AIServiceError.invalidResponse
            }
            
            // 解析JSON内容
            let decoder = JSONDecoder()
            let result = try decoder.decode(AIResult.self, from: contentData)
            
            print("✅ [AIService] 解析成功: \(result)")
            return result
            
        } catch let error as AIServiceError {
            throw error
        } catch {
            throw AIServiceError.networkError(error)
        }
    }
    
    // MARK: - Helper Methods
    
    /// 生成系统提示词
    /// - Parameters:
    ///   - input: 用户输入（可选，用于上下文）
    ///   - categories: 分类列表
    ///   - accounts: 账户列表
    /// - Returns: 系统提示词字符串
    func generatePrompt(input: String = "", categories: [Category], accounts: [Account]) -> String {
        // 格式化当前日期
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        let todayString = dateFormatter.string(from: Date())
        
        // 获取分类名称列表
        let categoryNames = categories.map { $0.name }
        let categoriesList = categoryNames.joined(separator: ", ")
        
        // 获取账户名称列表
        let accountNames = accounts.map { $0.name }
        let accountsList = accountNames.joined(separator: ", ")
        
        // 检查是否有"其他"分类，如果没有则添加说明
        let hasOthersCategory = categoryNames.contains { $0.contains("其他") || $0.contains("Other") }
        let categoryFallback = hasOthersCategory ? "使用'其他'分类" : "返回null"
        
        // 检查是否有"现金"账户，如果没有则使用第一个账户作为默认值
        let hasCashAccount = accountNames.contains { $0.contains("现金") || $0.contains("Cash") }
        let defaultAccount = hasCashAccount ? "现金" : (accountNames.first ?? "第一个账户")
        
        return """
        You are a bookkeeping assistant. Extract transaction details from the user's input.
        
        **Category Matching:**
        Map the input to the closest match in this list: [\(categoriesList)]
        If unsure or no match found, \(categoryFallback).
        You must select from the provided list only. Do not create new categories.
        
        **Account Matching:**
        Map to this list: [\(accountsList)]
        If the user does not specify an account, default to "\(defaultAccount)".
        You must select from the provided list only. Do not create new accounts.
        
        **Time Handling:**
        Today is \(todayString).
        - If user says "yesterday", calculate the date as \(dateFormatter.string(from: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()))
        - If user says "today" or "今天", use \(todayString)
        - If user says "7 days ago" or "一周前", calculate accordingly
        - Return date in ISO8601 format (YYYY-MM-DD) or relative offset like "-1d" for yesterday, "-7d" for 7 days ago
        - If no date is mentioned, return null
        
        **Output Format:**
        Return ONLY raw JSON. No markdown, no explanations, no code blocks, no backticks.
        The JSON must be valid and parseable.
        
        **Required JSON Structure:**
        {
            "amount": <number>,
            "category_name": "<string or null>",
            "account_name": "<string or null>",
            "note": "<string or null>",
            "date": "<ISO8601 date string or relative offset like '-1d' or null>"
        }
        
        **Example Input:** "Yesterday I spent 50 yuan on lunch"
        **Example Output:** {"amount": 50.0, "category_name": "餐饮", "account_name": "\(defaultAccount)", "note": "Lunch", "date": "-1d"}
        
        **Example Input:** "今天打车花了30块，用微信支付"
        **Example Output:** {"amount": 30.0, "category_name": "出租车", "account_name": "微信支付", "note": "打车", "date": "\(todayString)"}
        
        **Important Rules:**
        1. amount is REQUIRED and must be a number
        2. category_name must be from the provided list or null
        3. account_name must be from the provided list or "\(defaultAccount)" if unspecified
        4. note is optional, extract meaningful description from input
        5. date must be ISO8601 format (YYYY-MM-DD) or relative offset (-Nd for N days ago)
        6. Return ONLY the JSON object, nothing else
        """
    }
    
    /// 构建系统提示词（向后兼容的旧方法）
    private func buildSystemPrompt(categories: [String], accounts: [String]) -> String {
        let categoriesList = categories.joined(separator: ", ")
        let accountsList = accounts.joined(separator: ", ")
        
        return """
        你是一个智能记账助手。用户会输入交易描述，你需要解析并返回JSON格式的结果。
        
        可用分类：\(categoriesList)
        可用账户：\(accountsList)
        
        请根据用户输入，提取以下信息：
        1. amount: 金额（数字，必需）
        2. category_name: 分类名称（从可用分类中选择最匹配的，如果没有匹配的则返回null）
        3. account_name: 账户名称（从可用账户中选择最匹配的，如果没有指定则返回null）
        4. note: 交易备注/描述（可选）
        5. date: 日期（ISO8601格式，如"2024-01-15"，或相对偏移如"-1d"表示昨天，"-7d"表示7天前。如果未指定则返回null）
        
        示例输入："昨天午餐花了50元"
        示例输出：
        {
            "amount": 50.0,
            "category_name": "餐饮",
            "account_name": null,
            "note": "午餐",
            "date": "-1d"
        }
        
        重要规则：
        - 必须返回有效的JSON对象
        - 金额必须是数字类型
        - 分类和账户必须从提供的列表中选择，如果没有匹配的返回null
        - 日期可以是ISO8601格式或相对偏移（如"-1d", "-7d"）
        - 如果信息不完整，尽量推断，无法推断的字段返回null
        """
    }
    
    // MARK: - Query Intent Recognition
    
    /// 解析查询意图（识别用户想要查询什么数据）
    /// - Parameters:
    ///   - text: 用户输入的查询文本
    ///   - categories: 当前可用的分类列表
    ///   - accounts: 当前可用的账户列表
    ///   - config: LLM 配置（可选）
    /// - Returns: 查询意图
    func parseQueryIntent(
        text: String,
        categories: [Category],
        accounts: [Account],
        config: LLMConfig? = nil
    ) async throws -> QueryIntent {
        let llmConfig: LLMConfig
        let apiKey: String
        
        if let providedConfig = config {
            llmConfig = providedConfig
            guard let key = LLMManager.shared.getAPIKey(for: providedConfig) else {
                throw AIServiceError.invalidConfiguration
            }
            apiKey = key // getAPIKey 已经清理过了
        } else {
            guard let currentConfig = loadCurrentConfiguration() else {
                throw AIServiceError.invalidConfiguration
            }
            llmConfig = LLMConfig(
                name: "Current",
                providerType: .custom,
                baseURL: currentConfig.baseURL,
                modelName: currentConfig.model
            )
            // 清理 API Key（去除前后空格和换行符）
            apiKey = currentConfig.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // 构建请求URL
        var baseURL = llmConfig.baseURL.trimmingCharacters(in: .whitespaces)
        if baseURL.hasSuffix("/") {
            baseURL = String(baseURL.dropLast())
        }
        
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw AIServiceError.invalidConfiguration
        }
        
        // 生成查询意图识别的系统提示
        let systemPrompt = generateQueryIntentPrompt(categories: categories, accounts: accounts)
        let userPrompt = text
        
        return try await performQueryIntentRequest(url: url, systemPrompt: systemPrompt, userPrompt: userPrompt, modelName: llmConfig.modelName, apiKey: apiKey)
    }
    
    /// 生成查询意图识别的系统提示
    private func generateQueryIntentPrompt(categories: [Category], accounts: [Account]) -> String {
        let categoriesList = categories.map { $0.name }.joined(separator: ", ")
        let accountsList = accounts.map { $0.name }.joined(separator: ", ")
        
        let today = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayString = dateFormatter.string(from: today)
        
        // 计算本月第一天
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: today)
        let monthStart = calendar.date(from: components) ?? today
        let monthStartString = dateFormatter.string(from: monthStart)
        
        return """
        You are a query intent recognition assistant for a bookkeeping app. When a user asks a question about their financial data, you should NOT answer directly. Instead, return a JSON command that tells the app what data to fetch from the local database.
        
        **Available Categories:** [\(categoriesList)]
        **Available Accounts:** [\(accountsList)]
        
        **Today's Date:** \(todayString)
        **This Month Start:** \(monthStartString)
        
        **Operation Types:**
        - "sum": When user asks for totals, sums, or calculations (e.g., "How much did I spend?", "Total expense this month")
        - "list": When user asks to see records, transactions, or lists (e.g., "Show me my transactions", "List all expenses")
        - "unknown": When user is just chatting or asking non-data questions (e.g., "Tell me a joke", "What can you do?")
        
        **Date Handling:**
        - "today" or "今天" -> start_date: "\(todayString)", end_date: "\(todayString)"
        - "yesterday" or "昨天" -> start_date: "-1d", end_date: "-1d"
        - "this month" or "这个月" or "本月" -> start_date: "\(monthStartString)", end_date: "\(todayString)"
        - "last month" or "上个月" -> Calculate first and last day of previous month
        - "this week" or "这周" -> Calculate start of current week (Monday) to today
        - "last 7 days" or "最近7天" -> start_date: "-7d", end_date: "\(todayString)"
        - "last 30 days" or "最近30天" -> start_date: "-30d", end_date: "\(todayString)"
        - If no date mentioned, set both to null
        
        **Category/Account Filtering:**
        - If user mentions a category name, match it to the available categories list
        - If user mentions an account name, match it to the available accounts list
        - If not mentioned, set to null
        
        **Output Format:**
        Return ONLY raw JSON. No markdown, no explanations, no code blocks, no backticks.
        The JSON must be valid and parseable.
        
        **Required JSON Structure:**
        {
            "operation": "<sum|list|unknown>",
            "start_date": "<ISO8601 date string or relative offset like '-7d' or null>",
            "end_date": "<ISO8601 date string or 'today' or null>",
            "category_name": "<string from available categories or null>",
            "account_name": "<string from available accounts or null>"
        }
        
        **Example Input:** "How much did I spend on food this month?"
        **Example Output:** {"operation": "sum", "start_date": "\(monthStartString)", "end_date": "\(todayString)", "category_name": "餐饮", "account_name": null}
        
        **Example Input:** "Show me all transactions from yesterday"
        **Example Output:** {"operation": "list", "start_date": "-1d", "end_date": "-1d", "category_name": null, "account_name": null}
        
        **Example Input:** "What's the total expense?"
        **Example Output:** {"operation": "sum", "start_date": null, "end_date": null, "category_name": null, "account_name": null}
        
        **Example Input:** "Tell me a joke"
        **Example Output:** {"operation": "unknown", "start_date": null, "end_date": null, "category_name": null, "account_name": null}
        
        **Important Rules:**
        1. operation is REQUIRED and must be one of: "sum", "list", "unknown"
        2. start_date and end_date can be ISO8601 format (YYYY-MM-DD), relative offset (-Nd for N days ago), "today", or null
        3. category_name must be from the provided list or null
        4. account_name must be from the provided list or null
        5. Return ONLY the JSON object, nothing else
        """
    }
    
    // MARK: - AIQueryIntent Recognition (New RAG System)
    
    /// 解析 AIQueryIntent（新的 RAG 系统）
    /// - Parameters:
    ///   - text: 用户输入的查询文本
    ///   - categories: 当前可用的分类列表
    ///   - accounts: 当前可用的账户列表
    ///   - config: LLM 配置（可选）
    /// - Returns: AIQueryIntent
    func parseAIQueryIntent(
        text: String,
        categories: [Category],
        accounts: [Account],
        config: LLMConfig? = nil
    ) async throws -> AIQueryIntent {
        let llmConfig: LLMConfig
        let apiKey: String
        
        if let providedConfig = config {
            llmConfig = providedConfig
            guard let key = LLMManager.shared.getAPIKey(for: providedConfig) else {
                throw AIServiceError.invalidConfiguration
            }
            apiKey = key
        } else {
            guard let currentConfig = loadCurrentConfiguration() else {
                throw AIServiceError.invalidConfiguration
            }
            llmConfig = LLMConfig(
                name: "Current",
                providerType: .custom,
                baseURL: currentConfig.baseURL,
                modelName: currentConfig.model
            )
            apiKey = currentConfig.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // 构建请求URL
        var baseURL = llmConfig.baseURL.trimmingCharacters(in: .whitespaces)
        if baseURL.hasSuffix("/") {
            baseURL = String(baseURL.dropLast())
        }
        
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw AIServiceError.invalidConfiguration
        }
        
        // 获取分类和账户名称列表
        let categoryNames = categories.map { $0.name }
        let accountNames = accounts.map { $0.name }
        
        // 生成系统提示词
        let systemPrompt = AIPromptBuilder.buildSystemPrompt(
            currentDate: Date(),
            categories: categoryNames,
            accounts: accountNames
        )
        let userPrompt = text
        
        // 调用 API 并解析 JSON
        let jsonString = try await performAIQueryIntentRequest(
            url: url,
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            modelName: llmConfig.modelName,
            apiKey: apiKey
        )
        
        // 解析 JSON 为 AIQueryIntent
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw AIServiceError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        let intent = try decoder.decode(AIQueryIntent.self, from: jsonData)
        
        print("✅ [AIService] AIQueryIntent 解析成功: \(intent)")
        return intent
    }
    
    /// 执行 AIQueryIntent 识别的 API 请求（返回 JSON 字符串）
    private func performAIQueryIntentRequest(
        url: URL,
        systemPrompt: String,
        userPrompt: String,
        modelName: String,
        apiKey: String
    ) async throws -> String {
        // 构建请求体
        let requestBody: [String: Any] = [
            "model": modelName,
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user",
                    "content": userPrompt
                ]
            ],
            "temperature": 0.1, // 低温度以获得更一致的结果
            "max_tokens": 300
        ]
        
        // 创建请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw AIServiceError.decodingError(error)
        }
        
        // 发送请求
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // 检查HTTP状态码
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIServiceError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw AIServiceError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
            }
            
            // 解析响应
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                throw AIServiceError.invalidResponse
            }
            
            // 清理内容（移除可能的markdown代码块）
            var cleanedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanedContent.hasPrefix("```json") {
                cleanedContent = String(cleanedContent.dropFirst(7))
            } else if cleanedContent.hasPrefix("```") {
                cleanedContent = String(cleanedContent.dropFirst(3))
            }
            if cleanedContent.hasSuffix("```") {
                cleanedContent = String(cleanedContent.dropLast(3))
            }
            cleanedContent = cleanedContent.trimmingCharacters(in: .whitespacesAndNewlines)
            
            return cleanedContent
            
        } catch let error as AIServiceError {
            throw error
        } catch {
            throw AIServiceError.networkError(error)
        }
    }
    
    /// 执行查询意图识别的API请求
    private func performQueryIntentRequest(
        url: URL,
        systemPrompt: String,
        userPrompt: String,
        modelName: String,
        apiKey: String
    ) async throws -> QueryIntent {
        // 构建请求体
        let requestBody: [String: Any] = [
            "model": modelName,
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user",
                    "content": userPrompt
                ]
            ],
            "temperature": 0.1, // 低温度以获得更一致的结果
            "max_tokens": 200
        ]
        
        // 创建请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw AIServiceError.decodingError(error)
        }
        
        // 发送请求
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // 检查HTTP状态码
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIServiceError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw AIServiceError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
            }
            
            // 解析响应
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                throw AIServiceError.invalidResponse
            }
            
            // 清理内容（移除可能的markdown代码块）
            var cleanedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanedContent.hasPrefix("```json") {
                cleanedContent = String(cleanedContent.dropFirst(7))
            } else if cleanedContent.hasPrefix("```") {
                cleanedContent = String(cleanedContent.dropFirst(3))
            }
            if cleanedContent.hasSuffix("```") {
                cleanedContent = String(cleanedContent.dropLast(3))
            }
            cleanedContent = cleanedContent.trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard let contentData = cleanedContent.data(using: .utf8) else {
                throw AIServiceError.invalidResponse
            }
            
            // 解析JSON内容
            let decoder = JSONDecoder()
            let intent = try decoder.decode(QueryIntent.self, from: contentData)
            
            print("✅ [AIService] 查询意图识别成功: \(intent)")
            return intent
            
        } catch let error as AIServiceError {
            throw error
        } catch {
            throw AIServiceError.networkError(error)
        }
    }
    
    // MARK: - Final Answer Generation
    
    /// 生成最终答案（第二次 AI 调用）
    /// - Parameters:
    ///   - userQuery: 用户的原始问题
    ///   - dataResult: 数据库查询结果（来自 LocalDataService）
    ///   - config: LLM 配置（可选）
    /// - Returns: 友好的文本答案
    func generateFinalAnswer(
        userQuery: String,
        dataResult: String,
        config: LLMConfig? = nil
    ) async throws -> String {
        let llmConfig: LLMConfig
        let apiKey: String
        
        if let providedConfig = config {
            llmConfig = providedConfig
            guard let key = LLMManager.shared.getAPIKey(for: providedConfig) else {
                throw AIServiceError.invalidConfiguration
            }
            apiKey = key // getAPIKey 已经清理过了
        } else {
            guard let currentConfig = loadCurrentConfiguration() else {
                throw AIServiceError.invalidConfiguration
            }
            llmConfig = LLMConfig(
                name: "Current",
                providerType: .custom,
                baseURL: currentConfig.baseURL,
                modelName: currentConfig.model
            )
            // 清理 API Key（去除前后空格和换行符）
            apiKey = currentConfig.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // 构建请求URL
        var baseURL = llmConfig.baseURL.trimmingCharacters(in: .whitespaces)
        if baseURL.hasSuffix("/") {
            baseURL = String(baseURL.dropLast())
        }
        
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw AIServiceError.invalidConfiguration
        }
        
        // 生成提示词
        let systemPrompt = generateFinalResponsePrompt(userQuery: userQuery, dataResult: dataResult)
        let userPrompt = userQuery
        
        return try await performFinalAnswerRequest(url: url, systemPrompt: systemPrompt, userPrompt: userPrompt, modelName: llmConfig.modelName, apiKey: apiKey)
    }
    
    /// 生成最终答案的系统提示词
    /// - Parameters:
    ///   - userQuery: 用户的原始问题
    ///   - dataResult: 数据库查询结果
    /// - Returns: 系统提示词字符串
    func generateFinalResponsePrompt(userQuery: String, dataResult: String) -> String {
        return """
        You are a helpful bookkeeping assistant. Your role is to answer the user's question based on the provided database query results.
        
        **User Question:** \(userQuery)
        
        **Database Result:**
        \(dataResult)
        
        **Instructions:**
        1. Answer the user's question based STRICTLY on the provided database result.
        2. If the result is empty or shows "No records found", politely inform the user that no matching records were found.
        3. Be concise and friendly in your response.
        4. Use natural language to explain the data (e.g., "You spent ¥150.00 on food this month" instead of just "Total: 150.00").
        5. If the result contains a list of transactions, summarize the key information rather than listing every single item.
        6. Respond in the same language as the user's question (Chinese if the question is in Chinese, English if in English).
        
        **Important:**
        - Do NOT make up data that is not in the database result.
        - Do NOT provide financial advice beyond what the data shows.
        - Keep your response brief and to the point.
        """
    }
    
    /// 执行最终答案生成的 API 请求
    private func performFinalAnswerRequest(
        url: URL,
        systemPrompt: String,
        userPrompt: String,
        modelName: String,
        apiKey: String
    ) async throws -> String {
        // 构建请求体
        let requestBody: [String: Any] = [
            "model": modelName,
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user",
                    "content": userPrompt
                ]
            ],
            "temperature": 0.7, // 稍高的温度以获得更自然的回答
            "max_tokens": 500
        ]
        
        // 创建请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw AIServiceError.decodingError(error)
        }
        
        // 发送请求
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // 检查HTTP状态码
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIServiceError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw AIServiceError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
            }
            
            // 解析响应
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                throw AIServiceError.invalidResponse
            }
            
            // 清理内容（移除可能的markdown代码块）
            var cleanedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanedContent.hasPrefix("```") {
                // 移除代码块标记
                let lines = cleanedContent.components(separatedBy: "\n")
                if lines.count > 1 {
                    cleanedContent = lines.dropFirst().dropLast().joined(separator: "\n")
                } else {
                    cleanedContent = cleanedContent.replacingOccurrences(of: "```", with: "")
                }
            }
            cleanedContent = cleanedContent.trimmingCharacters(in: .whitespacesAndNewlines)
            
            print("✅ [AIService] 最终答案生成成功")
            return cleanedContent
            
        } catch let error as AIServiceError {
            throw error
        } catch {
            throw AIServiceError.networkError(error)
        }
    }
    
    /// 解析日期字符串
    /// - Parameter dateString: 日期字符串（ISO8601或相对偏移）
    /// - Returns: Date对象
    static func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        
        // 处理相对偏移（如"-1d"表示昨天）
        if dateString.hasPrefix("-") || dateString.hasPrefix("+") {
            let isNegative = dateString.hasPrefix("-")
            let numberString = String(dateString.dropFirst())
            
            if numberString.hasSuffix("d") {
                let daysString = String(numberString.dropLast())
                if let days = Int(daysString) {
                    let calendar = Calendar.current
                    let offset = isNegative ? -days : days
                    return calendar.date(byAdding: .day, value: offset, to: Date())
                }
            }
        }
        
        // 尝试解析ISO8601格式
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        // 尝试不带秒的格式
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        // 尝试简单日期格式
        let simpleFormatter = DateFormatter()
        simpleFormatter.dateFormat = "yyyy-MM-dd"
        if let date = simpleFormatter.date(from: dateString) {
            return date
        }
        
        return nil
    }
}
