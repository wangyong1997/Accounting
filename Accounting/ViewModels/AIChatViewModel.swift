import Foundation
import SwiftUI
import SwiftData
import Observation

/// 聊天消息模型
struct ChatMessageModel: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
    
    init(content: String, isUser: Bool, timestamp: Date = Date()) {
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
    }
}

/// AI 聊天视图模型（使用新的 RAG 系统）
@Observable
final class AIChatViewModel {
    // MARK: - Published Properties
    
    var messages: [ChatMessageModel] = []
    var isLoading: Bool = false
    var errorMessage: String?
    
    // MARK: - Dependencies
    
    private let aiService = AIService.shared
    private var activeConfig: LLMConfig?
    
    // MARK: - Initialization
    
    init() {
        // 设置默认配置
        activeConfig = LLMManager.shared.activeConfig
    }
    
    // MARK: - Public Methods
    
    /// 发送消息
    /// - Parameters:
    ///   - text: 用户输入的文本
    ///   - context: SwiftData 模型上下文
    @MainActor
    func sendMessage(_ text: String, context: ModelContext) async {
        // 添加用户消息
        let userMessage = ChatMessageModel(content: text, isUser: true)
        messages.append(userMessage)
        
        // 设置加载状态
        isLoading = true
        errorMessage = nil
        
        do {
            // 步骤 1: 获取所有分类和账户名称（用于构建提示词）
            let categories = try fetchCategories(context: context)
            let accounts = try fetchAccounts(context: context)
            
            let categoryNames = categories.map { $0.name }
            let accountNames = accounts.map { $0.name }
            
            // 步骤 2: 检查是否有可用的 AI 配置
            guard let config = activeConfig ?? LLMManager.shared.activeConfig,
                  LLMManager.shared.getAPIKey(for: config) != nil else {
                let errorMsg = "请先在设置中配置 AI 服务。"
                let errorMessage = ChatMessageModel(content: errorMsg, isUser: false)
                messages.append(errorMessage)
                isLoading = false
                return
            }
            
            // 步骤 3: 调用 AIService 解析 AIQueryIntent
            let intent = try await aiService.parseAIQueryIntent(
                text: text,
                categories: categories,
                accounts: accounts,
                config: config
            )
            
            // 步骤 4: 执行本地查询
            let result = try LocalQueryService.executeQuery(intent: intent, context: context)
            
            // 步骤 5: 添加 AI 回复消息
            let aiMessage = ChatMessageModel(content: result, isUser: false)
            messages.append(aiMessage)
            
        } catch {
            // 处理错误
            let errorMsg = "处理您的请求时出现错误：\(error.localizedDescription)"
            errorMessage = errorMsg
            let errorMessage = ChatMessageModel(content: errorMsg, isUser: false)
            messages.append(errorMessage)
            print("❌ [AIChatViewModel] 错误: \(error)")
        }
        
        isLoading = false
    }
    
    /// 设置活动配置
    func setActiveConfig(_ config: LLMConfig?) {
        activeConfig = config
    }
    
    /// 清除消息历史
    func clearMessages() {
        messages.removeAll()
    }
    
    // MARK: - Private Methods
    
    /// 获取所有分类
    private func fetchCategories(context: ModelContext) throws -> [Category] {
        let descriptor = FetchDescriptor<Category>()
        return try context.fetch(descriptor)
    }
    
    /// 获取所有账户
    private func fetchAccounts(context: ModelContext) throws -> [Account] {
        let descriptor = FetchDescriptor<Account>()
        return try context.fetch(descriptor)
    }
}
