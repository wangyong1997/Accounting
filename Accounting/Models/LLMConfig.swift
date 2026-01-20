import Foundation

/// LLM 提供商类型
enum LLMProviderType: String, Codable, CaseIterable {
    case openAI = "OpenAI"
    case deepSeek = "DeepSeek"
    case qwen = "Qwen"
    case ernie = "ERNIE"
    case glm = "GLM"
    case moonshot = "Moonshot"
    case yi = "Yi"
    case doubao = "Doubao"
    case baichuan = "Baichuan"
    case minimax = "MiniMax"
    case siliconFlow = "SiliconFlow"
    case ollama = "Ollama"
    case custom = "Custom"
    
    var displayName: String {
        switch self {
        case .openAI: return "OpenAI"
        case .deepSeek: return "DeepSeek"
        case .qwen: return "通义千问"
        case .ernie: return "文心一言"
        case .glm: return "智谱AI"
        case .moonshot: return "月之暗面"
        case .yi: return "零一万物"
        case .doubao: return "豆包"
        case .baichuan: return "百川智能"
        case .minimax: return "MiniMax"
        case .siliconFlow: return "SiliconFlow"
        case .ollama: return "Ollama"
        case .custom: return "自定义"
        }
    }
}

/// LLM 配置模型（不包含 API Key）
struct LLMConfig: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var providerType: LLMProviderType
    var baseURL: String
    var modelName: String
    var createdAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        providerType: LLMProviderType,
        baseURL: String,
        modelName: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.providerType = providerType
        self.baseURL = baseURL
        self.modelName = modelName
        self.createdAt = createdAt
    }
    
    // 预设配置
    static func preset(for provider: LLMProviderType) -> LLMConfig {
        switch provider {
        case .openAI:
            return LLMConfig(
                name: "OpenAI",
                providerType: .openAI,
                baseURL: "https://api.openai.com/v1",
                modelName: "gpt-4o"
            )
        case .deepSeek:
            return LLMConfig(
                name: "DeepSeek",
                providerType: .deepSeek,
                baseURL: "https://api.deepseek.com",
                modelName: "deepseek-chat"
            )
        case .qwen:
            return LLMConfig(
                name: "通义千问",
                providerType: .qwen,
                baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1",
                modelName: "qwen-plus"
            )
        case .ernie:
            return LLMConfig(
                name: "文心一言",
                providerType: .ernie,
                baseURL: "https://aip.baidubce.com/rpc/2.0/ai_custom/v1/wenxinworkshop/chat",
                modelName: "ernie-bot-4"
            )
        case .glm:
            return LLMConfig(
                name: "智谱AI",
                providerType: .glm,
                baseURL: "https://open.bigmodel.cn/api/paas/v4",
                modelName: "glm-4"
            )
        case .moonshot:
            return LLMConfig(
                name: "月之暗面",
                providerType: .moonshot,
                baseURL: "https://api.moonshot.cn/v1",
                modelName: "moonshot-v1-8k"
            )
        case .yi:
            return LLMConfig(
                name: "零一万物",
                providerType: .yi,
                baseURL: "https://api.lingyiwanwu.com/v1",
                modelName: "yi-34b-chat"
            )
        case .doubao:
            return LLMConfig(
                name: "豆包",
                providerType: .doubao,
                baseURL: "https://ark.cn-beijing.volces.com/api/v3",
                modelName: "doubao-pro-4k"
            )
        case .baichuan:
            return LLMConfig(
                name: "百川智能",
                providerType: .baichuan,
                baseURL: "https://api.baichuan-ai.com/v1",
                modelName: "baichuan2-turbo"
            )
        case .minimax:
            return LLMConfig(
                name: "MiniMax",
                providerType: .minimax,
                baseURL: "https://api.minimax.chat/v1",
                modelName: "abab5.5-chat"
            )
        case .siliconFlow:
            return LLMConfig(
                name: "SiliconFlow",
                providerType: .siliconFlow,
                baseURL: "https://api.siliconflow.cn/v1",
                modelName: "deepseek-ai/DeepSeek-V3"
            )
        case .ollama:
            return LLMConfig(
                name: "Ollama",
                providerType: .ollama,
                baseURL: "http://localhost:11434/v1",
                modelName: "llama3"
            )
        case .custom:
            return LLMConfig(
                name: "自定义",
                providerType: .custom,
                baseURL: "https://api.openai.com/v1",
                modelName: "gpt-3.5-turbo"
            )
        }
    }
}
