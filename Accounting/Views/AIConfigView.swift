import SwiftUI

/// AI配置视图
struct AIConfigView: View {
    @Environment(\.dismiss) private var dismiss
    
    // 配置字段
    @AppStorage("ai_base_url") private var baseURL: String = "https://api.openai.com/v1"
    @AppStorage("ai_model") private var modelName: String = "gpt-3.5-turbo"
    @State private var apiKey: String = ""
    @State private var showAPIKey: Bool = false
    
    // UI状态
    @State private var isTesting: Bool = false
    @State private var testResult: TestResult?
    
    enum TestResult {
        case success
        case failure(String)
    }
    
    var body: some View {
        Form {
            // 预设配置
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        // 国内大模型
                        Text("国内大模型")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                        
                        HStack(spacing: 12) {
                            presetButton(
                                title: "通义千问",
                                url: "https://dashscope.aliyuncs.com/compatible-mode/v1",
                                model: "qwen-plus"
                            )
                            
                            presetButton(
                                title: "文心一言",
                                url: "https://aip.baidubce.com/rpc/2.0/ai_custom/v1/wenxinworkshop/chat",
                                model: "ernie-bot-4"
                            )
                            
                            presetButton(
                                title: "智谱AI",
                                url: "https://open.bigmodel.cn/api/paas/v4",
                                model: "glm-4"
                            )
                            
                            presetButton(
                                title: "月之暗面",
                                url: "https://api.moonshot.cn/v1",
                                model: "moonshot-v1-8k"
                            )
                            
                            presetButton(
                                title: "零一万物",
                                url: "https://api.lingyiwanwu.com/v1",
                                model: "yi-34b-chat"
                            )
                            
                            presetButton(
                                title: "豆包",
                                url: "https://ark.cn-beijing.volces.com/api/v3",
                                model: "doubao-pro-4k"
                            )
                            
                            presetButton(
                                title: "百川智能",
                                url: "https://api.baichuan-ai.com/v1",
                                model: "baichuan2-turbo"
                            )
                            
                            presetButton(
                                title: "MiniMax",
                                url: "https://api.minimax.chat/v1",
                                model: "abab5.5-chat"
                            )
                        }
                        .padding(.horizontal, 4)
                        
                        // 国外大模型
                        Text("国外大模型")  
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.top, 8)
                        
                        HStack(spacing: 12) {
                            presetButton(
                                title: "DeepSeek",
                                url: "https://api.deepseek.com",
                                model: "deepseek-chat"
                            )
                            
                            presetButton(
                                title: "OpenAI",
                                url: "https://api.openai.com/v1",
                                model: "gpt-4o"
                            )
                            
                            presetButton(
                                title: "SiliconFlow",
                                url: "https://api.siliconflow.cn/v1",
                                model: "deepseek-ai/DeepSeek-V3"
                            )
                            
                            presetButton(
                                title: "Local/Ollama",
                                url: "http://localhost:11434/v1",
                                model: "llama3"
                            )
                        }
                        .padding(.horizontal, 4)
                    }
                }
            } header: {
                Text("预设配置")
            } footer: {
                Text("点击预设按钮快速配置常用服务。中国大模型服务需要相应的API密钥。")
            }
            
            // 输入字段
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Base URL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("https://api.openai.com/v1", text: $baseURL)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("API Key")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(action: {
                            showAPIKey.toggle()
                        }) {
                            Image(systemName: showAPIKey ? "eye.slash.fill" : "eye.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if showAPIKey {
                        TextField("sk-...", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    } else {
                        SecureField("sk-...", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Model Name")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("gpt-3.5-turbo", text: $modelName)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
            } header: {
                Text("自定义配置")
            } footer: {
                Text("输入你的 API Key 和配置信息。API Key 将安全存储在 Keychain 中。")
            }
            
            // 测试连接
            Section {
                Button(action: {
                    Task {
                        await testConnection()
                    }
                }) {
                    HStack {
                        if isTesting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            if let result = testResult {
                                switch result {
                                case .success:
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                case .failure:
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                            } else {
                                Image(systemName: "network")
                            }
                        }
                        
                        Text(isTesting ? "测试中..." : "测试连接")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(isTesting || apiKey.isEmpty || baseURL.isEmpty || modelName.isEmpty)
                
                if let result = testResult, case .failure(let message) = result {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            } header: {
                Text("连接测试")
            } footer: {
                Text("测试配置是否正确，确保可以连接到 AI 服务")
            }
        }
        .navigationTitle("AI 配置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("取消") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存") {
                    saveConfiguration()
                }
                .disabled(apiKey.isEmpty)
            }
        }
        .onAppear {
            loadConfiguration()
        }
    }
    
    // MARK: - Preset Buttons
    
    private func presetButton(title: String, url: String, model: String) -> some View {
        Button(action: {
            baseURL = url
            modelName = model
        }) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Configuration Management
    
    private func loadConfiguration() {
        // 从 Keychain 读取 API Key
        if let savedAPIKey = KeychainHelper.readAPIKey() {
            apiKey = savedAPIKey
        }
        
        // baseURL 和 modelName 已通过 @AppStorage 自动加载
    }
    
    private func saveConfiguration() {
        // 保存 API Key 到 Keychain
        guard KeychainHelper.saveAPIKey(apiKey) else {
            print("❌ [AIConfigView] 保存 API Key 失败")
            return
        }
        
        // baseURL 和 modelName 已通过 @AppStorage 自动保存
        
        // 更新 AIService 配置
        AIService.shared.updateConfiguration(
            apiKey: apiKey,
            baseURL: baseURL,
            model: modelName
        )
        
        // 触觉反馈
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        dismiss()
    }
    
    // MARK: - Test Connection
    
    private func testConnection() async {
        isTesting = true
        testResult = nil
        
        // 临时更新配置用于测试
        let originalConfig = AIService.shared.getCurrentConfigurationForTesting()
        
        // 保存到Keychain和AppStorage（临时）
        KeychainHelper.saveAPIKey(apiKey)
        UserDefaults.standard.set(baseURL, forKey: "ai_base_url")
        UserDefaults.standard.set(modelName, forKey: "ai_model")
        
        do {
            // 发送一个简单的测试请求
            let testResult = try await AIService.shared.testConnection()
            
            await MainActor.run {
                if testResult {
                    self.testResult = .success
                } else {
                    self.testResult = .failure("连接失败：无法验证配置")
                }
                isTesting = false
            }
        } catch {
            await MainActor.run {
                self.testResult = .failure("连接失败：\(error.localizedDescription)")
                isTesting = false
            }
        }
        
        // 恢复原始配置（如果存在）
        if let original = originalConfig {
            KeychainHelper.saveAPIKey(original.apiKey)
            UserDefaults.standard.set(original.baseURL, forKey: "ai_base_url")
            UserDefaults.standard.set(original.model, forKey: "ai_model")
        }
    }
}

#Preview {
    NavigationStack {
        AIConfigView()
    }
}
