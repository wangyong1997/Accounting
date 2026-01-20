import SwiftUI

/// LLM 配置列表视图
struct LLMListSettingsView: View {
    @StateObject private var manager = LLMManager.shared
    @State private var showEditView = false
    @State private var editingConfig: LLMConfig?
    
    var body: some View {
        List {
            if manager.configs.isEmpty {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text("暂无配置")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("点击右上角 + 按钮添加第一个配置")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            } else {
                ForEach(manager.configs) { config in
                    LLMConfigRow(
                        config: config,
                        isActive: manager.activeConfigId == config.id.uuidString,
                        onTap: {
                            manager.setActiveConfig(config)
                        },
                        onEdit: {
                            editingConfig = config
                            showEditView = true
                        }
                    )
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        manager.deleteConfig(manager.configs[index])
                    }
                }
            }
        }
        .navigationTitle("AI 配置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    editingConfig = nil
                    showEditView = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showEditView) {
            if let config = editingConfig {
                LLMEditView(config: config)
            } else {
                LLMEditView()
            }
        }
    }
}

/// LLM 配置行视图
struct LLMConfigRow: View {
    let config: LLMConfig
    let isActive: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(config.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if isActive {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        Text(config.providerType.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(4)
                        
                        Text(config.modelName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// LLM 编辑视图
struct LLMEditView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = LLMManager.shared
    
    let existingConfig: LLMConfig?
    
    @State private var name: String = ""
    @State private var providerType: LLMProviderType = .custom
    @State private var baseURL: String = ""
    @State private var modelName: String = ""
    @State private var apiKey: String = ""
    @State private var showAPIKey: Bool = false
    
    @State private var isTesting: Bool = false
    @State private var testResult: TestResult?
    
    enum TestResult {
        case success
        case failure(String)
    }
    
    init(config: LLMConfig? = nil) {
        self.existingConfig = config
    }
    
    var body: some View {
        NavigationStack {
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
                                presetButton(.qwen)
                                presetButton(.ernie)
                                presetButton(.glm)
                                presetButton(.moonshot)
                                presetButton(.yi)
                                presetButton(.doubao)
                                presetButton(.baichuan)
                                presetButton(.minimax)
                            }
                            .padding(.horizontal, 4)
                            
                            // 国外大模型
                            Text("国外大模型")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 4)
                                .padding(.top, 8)
                            
                            HStack(spacing: 12) {
                                presetButton(.deepSeek)
                                presetButton(.openAI)
                                presetButton(.siliconFlow)
                                presetButton(.ollama)
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                } header: {
                    Text("预设配置")
                } footer: {
                    Text("点击预设按钮快速填充配置")
                }
                
                // 输入字段
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("配置名称")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("例如：我的 DeepSeek", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }
                    
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
                    Text("配置信息")
                } footer: {
                    Text("API Key 将安全存储在 Keychain 中")
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
                }
            }
            .navigationTitle(existingConfig == nil ? "添加配置" : "编辑配置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveConfig()
                    }
                    .disabled(name.isEmpty || apiKey.isEmpty)
                }
            }
            .onAppear {
                loadExistingConfig()
            }
        }
    }
    
    // MARK: - Preset Buttons
    
    private func presetButton(_ provider: LLMProviderType) -> some View {
        Button(action: {
            let preset = LLMConfig.preset(for: provider)
            name = preset.name
            providerType = provider
            baseURL = preset.baseURL
            modelName = preset.modelName
        }) {
            VStack(spacing: 4) {
                Text(provider.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Configuration Management
    
    private func loadExistingConfig() {
        if let config = existingConfig {
            name = config.name
            providerType = config.providerType
            baseURL = config.baseURL
            modelName = config.modelName
            
            // 从 Keychain 读取 API Key
            if let savedKey = manager.getAPIKey(for: config) {
                apiKey = savedKey
            }
        }
    }
    
    private func saveConfig() {
        let config: LLMConfig
        if let existing = existingConfig {
            // 更新现有配置
            config = LLMConfig(
                id: existing.id,
                name: name,
                providerType: providerType,
                baseURL: baseURL.trimmingCharacters(in: .whitespaces),
                modelName: modelName,
                createdAt: existing.createdAt
            )
        } else {
            // 创建新配置
            config = LLMConfig(
                name: name,
                providerType: providerType,
                baseURL: baseURL.trimmingCharacters(in: .whitespaces),
                modelName: modelName
            )
        }
        
        // 保存配置和 API Key
        manager.saveConfig(config, apiKey: apiKey)
        
        // 触觉反馈
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        dismiss()
    }
    
    // MARK: - Test Connection
    
    private func testConnection() async {
        isTesting = true
        testResult = nil
        
        // 创建临时配置用于测试
        let tempConfig = LLMConfig(
            name: name.isEmpty ? "Test" : name,
            providerType: providerType,
            baseURL: baseURL.trimmingCharacters(in: .whitespaces),
            modelName: modelName
        )
        
        do {
            let success = try await AIService.shared.testConnection(
                config: tempConfig,
                apiKey: apiKey
            )
            
            await MainActor.run {
                if success {
                    testResult = .success
                } else {
                    testResult = .failure("连接失败：无法验证配置")
                }
                isTesting = false
            }
        } catch {
            await MainActor.run {
                testResult = .failure("连接失败：\(error.localizedDescription)")
                isTesting = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        LLMListSettingsView()
    }
}
