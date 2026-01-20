import SwiftUI
import SwiftData

/// 消息模型
struct ChatMessage: Identifiable {
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

/// 全局悬浮AI助手按钮
struct FloatingAIAssistant: View {
    @Binding var showAIAssistant: Bool
    
    @State private var dragOffset: CGSize = .zero
    
    // 从UserDefaults读取保存的位置（默认在右侧中间）
    @AppStorage("floatingAIPositionX") private var savedPositionX: Double = 0
    @AppStorage("floatingAIPositionY") private var savedPositionY: Double = 0
    
    // 初始化默认位置
    private var defaultPosition: CGPoint {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        return CGPoint(
            x: screenWidth - 80,
            y: screenHeight * 0.4
        )
    }
    
    // 计算实际位置
    private var currentPosition: CGPoint {
        let baseX = savedPositionX > 0 ? savedPositionX : defaultPosition.x
        let baseY = savedPositionY > 0 ? savedPositionY : defaultPosition.y
        return CGPoint(
            x: baseX + dragOffset.width,
            y: baseY + dragOffset.height
        )
    }
    
    var body: some View {
        GeometryReader { geometry in
            // 悬浮按钮
            Button(action: {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                showAIAssistant = true
            }) {
                ZStack {
                    // 渐变背景
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.purple, Color.blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                        .shadow(color: Color.purple.opacity(0.4), radius: 12, x: 0, y: 6)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    // AI图标
                    Image(systemName: "sparkles")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .position(
                x: min(max(60, currentPosition.x), geometry.size.width - 60),
                y: min(max(100, currentPosition.y), geometry.size.height - 150)
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        // 保存新位置
                        let baseX = savedPositionX > 0 ? savedPositionX : defaultPosition.x
                        let baseY = savedPositionY > 0 ? savedPositionY : defaultPosition.y
                        
                        savedPositionX = baseX + value.translation.width
                        savedPositionY = baseY + value.translation.height
                        dragOffset = .zero
                    }
            )
        }
        .allowsHitTesting(true)
    }
}

/// AI聊天窗口
struct AIAssistantView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var manager = LLMManager.shared
    @Query(sort: \ExpenseItem.date, order: .reverse) private var recentExpenses: [ExpenseItem]
    @Query private var allCategories: [Category]
    @Query(sort: \Account.name) private var accounts: [Account]
    
    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isTyping: Bool = false
    @FocusState private var isInputFocused: Bool
    @State private var selectedConfig: LLMConfig?
    
    // 语音输入相关
    @State private var speechManager = SpeechManager()
    @State private var isProcessingVoice = false
    @State private var showPermissionAlert = false
    @State private var isPressingMic = false // 是否正在按压麦克风按钮
    
    // 滚动到底部的ID
    @State private var scrollToBottomID: UUID?

    // MARK: - 语音 UI 辅助（避免 Float/Double/CGFloat 混用导致编译器超时）
    private var audioLevelCGFloat: CGFloat { CGFloat(speechManager.audioLevel) }
    private var audioLevelDouble: Double { Double(speechManager.audioLevel) }

    private func waveHeight(for index: Int) -> CGFloat {
        // index: 0...6
        let base: CGFloat = 12
        let minH: CGFloat = 8
        let attenuation = max(0.1, 1.0 - CGFloat(index) * 0.15)
        return max(minH, base + audioLevelCGFloat * 50 * attenuation)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 消息列表
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // 欢迎消息
                            if messages.isEmpty {
                                welcomeMessage
                            }
                            
                            // 消息列表
                            ForEach(messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                            
                            // AI正在输入指示器
                            if isTyping {
                                TypingIndicator()
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: isTyping) { _ in
                        if isTyping {
                            scrollToBottom(proxy: proxy)
                        }
                    }
                    .onChange(of: scrollToBottomID) { id in
                        if let id = id {
                            withAnimation {
                                proxy.scrollTo(id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // 输入区域
                inputBar
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("AI智能助手")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !manager.configs.isEmpty {
                        Menu {
                            ForEach(manager.configs) { config in
                                Button(action: {
                                    selectedConfig = config
                                    manager.setActiveConfig(config)
                                }) {
                                    HStack {
                                        Text(config.name)
                                        if selectedConfig?.id == config.id || (selectedConfig == nil && manager.activeConfigId == config.id.uuidString) {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "server.rack")
                                    .font(.caption)
                                Text(selectedConfig?.name ?? manager.activeConfig?.name ?? "配置")
                                    .font(.caption)
                            }
                            .foregroundColor(.blue)
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // 设置默认配置
                selectedConfig = manager.activeConfig
                
                // 添加欢迎消息
                if messages.isEmpty {
                    addWelcomeMessage()
                }
            }
        }
    }
    
    // MARK: - 欢迎消息
    private var welcomeMessage: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            Text("你好！我是你的AI记账助手")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("我可以帮你：\n• 快速记账\n• 查询账单\n• 分析支出\n• 提供建议")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - 输入栏
    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                // 语音输入按钮
                Button(action: {}) {
                    ZStack {
                        // 背景圆形（录音时显示脉冲效果）
                        if speechManager.isRecording {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [Color.red.opacity(0.3), Color.red.opacity(0.1)],
                                        center: .center,
                                        startRadius: 10,
                                        endRadius: 25
                                    )
                                )
                                .frame(width: 44, height: 44)
                                .scaleEffect(1 + audioLevelCGFloat * 0.3)
                                .opacity(0.5 + audioLevelDouble * 0.5)
                                .animation(.easeInOut(duration: 0.15), value: speechManager.audioLevel)
                        } else {
                            // 未录音时的背景
                            Circle()
                                .fill(Color.blue.opacity(isPressingMic ? 0.15 : 0.05))
                                .frame(width: 44, height: 44)
                                .scaleEffect(isPressingMic ? 1.1 : 1.0)
                                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressingMic)
                        }
                        
                        // 麦克风图标
                        Image(systemName: speechManager.isRecording ? "mic.fill" : "mic")
                            .font(.system(size: 22, weight: speechManager.isRecording ? .semibold : .medium))
                            .foregroundColor(speechManager.isRecording ? .red : (isPressingMic ? .blue.opacity(0.8) : .blue))
                            .scaleEffect(isPressingMic ? 0.85 : (speechManager.isRecording ? 1.0 : 1.0))
                            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressingMic)
                            .animation(.easeInOut(duration: 0.2), value: speechManager.isRecording)
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            // 按下时立即响应
                            if !isPressingMic {
                                isPressingMic = true
                                // 立即开始录音，不等待长按
                                startVoiceRecording()
                            }
                        }
                        .onEnded { value in
                            // 松开时立即停止
                            isPressingMic = false
                            // 如果正在录音，则停止
                            if speechManager.isRecording {
                                stopVoiceRecording()
                            }
                        }
                )
                
                // 输入框
                TextField("输入消息或长按麦克风说话...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .focused($isInputFocused)
                    .lineLimit(1...5)
                
                // 发送按钮
                Button(action: {
                    sendMessage()
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(inputText.isEmpty ? .gray : .blue)
                }
                .disabled(inputText.isEmpty || isTyping)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
        .overlay(
            // 录音覆盖层
            Group {
                if speechManager.isRecording {
                    recordingOverlay
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: speechManager.isRecording)
                }
                if isProcessingVoice {
                    processingOverlay
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isProcessingVoice)
                }
            }
        )
        .alert("需要权限", isPresented: $showPermissionAlert) {
            Button("去设置", role: .none) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("需要授予语音识别和麦克风权限才能使用语音输入功能。")
        }
        .onChange(of: speechManager.isRecording) { isRecording in
            // 当录音停止时，自动处理语音输入
            if !isRecording && !speechManager.transcript.isEmpty {
                // 延迟一小段时间，确保转录完成
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    processVoiceInput()
                }
            }
        }
        .onAppear {
            Task {
                await requestSpeechPermissions()
            }
        }
    }
    
    // MARK: - 消息气泡
    struct MessageBubble: View {
        let message: ChatMessage
        
        var body: some View {
            HStack {
                if message.isUser {
                    Spacer(minLength: 50)
                }
                
                VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                    Text(message.content)
                        .font(.system(size: 16))
                        .foregroundColor(message.isUser ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            message.isUser
                                ? LinearGradient(
                                    colors: [Color.blue, Color.purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                : LinearGradient(
                                    colors: [Color(.systemGray5), Color(.systemGray5)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                        )
                        .cornerRadius(18)
                    
                    Text(message.timestamp, style: .time)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                }
                
                if !message.isUser {
                    Spacer(minLength: 50)
                }
            }
        }
    }
    
    // MARK: - 正在输入指示器
    struct TypingIndicator: View {
        @State private var dot1Opacity: Double = 0.3
        @State private var dot2Opacity: Double = 0.3
        @State private var dot3Opacity: Double = 0.3
        
        var body: some View {
            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 8, height: 8)
                        .opacity(dot1Opacity)
                    
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 8, height: 8)
                        .opacity(dot2Opacity)
                    
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 8, height: 8)
                        .opacity(dot3Opacity)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray5))
                .cornerRadius(18)
                
                Spacer(minLength: 50)
            }
            .onAppear {
                animateDots()
            }
        }
        
        private func animateDots() {
            withAnimation(.easeInOut(duration: 0.6).repeatForever()) {
                dot1Opacity = 1.0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeInOut(duration: 0.6).repeatForever()) {
                    dot2Opacity = 1.0
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeInOut(duration: 0.6).repeatForever()) {
                    dot3Opacity = 1.0
                }
            }
        }
    }
    
    // MARK: - 消息处理
    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let userMessage = ChatMessage(content: inputText, isUser: true)
        messages.append(userMessage)
        
        let messageContent = inputText
        inputText = ""
        isInputFocused = false
        
        // AI思考
        isTyping = true
        
        // 使用AIService处理消息
        Task {
            do {
                let aiResponse = try await generateAIResponse(for: messageContent)
                let aiMessage = ChatMessage(content: aiResponse, isUser: false)
                await MainActor.run {
                    messages.append(aiMessage)
                    isTyping = false
                }
            } catch {
                await MainActor.run {
                    let errorMessage = ChatMessage(
                        content: "抱歉，处理您的请求时出现错误：\(error.localizedDescription)",
                        isUser: false
                    )
                    messages.append(errorMessage)
                    isTyping = false
                }
            }
        }
    }
    
    private func addWelcomeMessage() {
        let welcome = ChatMessage(
            content: "你好！我是你的AI记账助手。我可以帮你快速记账、查询账单、分析支出。试试问我：'帮我记一笔午餐50元' 或 '今天花了多少钱？'",
            isUser: false
        )
        messages.append(welcome)
    }
    
    // MARK: - AI回复生成
    private func generateAIResponse(for userMessage: String) async throws -> String {
        let lowercased = userMessage.lowercased()
        
        // 记账相关 - 使用AIService解析并执行记账
        if lowercased.contains("记") || lowercased.contains("记账") || lowercased.contains("花了") || lowercased.contains("支出") || lowercased.contains("买了") {
            return try await processExpenseRecordingWithAI(userMessage)
        }
        
        // 查询相关 - 使用三步流程：意图识别 -> 本地查询 -> 生成最终答案
        let config = selectedConfig ?? manager.activeConfig
        if let finalConfig = config, manager.getAPIKey(for: finalConfig) != nil {
            // 步骤 1: 使用 AI 识别查询意图
            do {
                let intent = try await AIService.shared.parseQueryIntent(
                    text: userMessage,
                    categories: allCategories,
                    accounts: accounts,
                    config: finalConfig
                )
                
                // 如果是未知操作，直接返回默认回复
                if intent.operation == .unknown {
                    return "我理解你的问题。我可以帮你：\n1. 快速记账（如：'记一笔午餐50元'）\n2. 查询账单（如：'今天花了多少钱？'）\n3. 分析支出（如：'本月支出统计'）\n4. 提供建议\n\n试试问我这些问题吧！"
                }
                
                // 步骤 2: 执行本地查询（使用 LocalDataService）
                let dataResult = LocalDataService.executeIntent(intent, context: modelContext)
                
                // 如果查询结果为空，直接返回
                if dataResult.isEmpty {
                    return "抱歉，没有找到符合条件的记录。"
                }
                
                // 步骤 3: 使用 AI 生成最终答案（第二次 AI 调用）
                do {
                    let finalAnswer = try await AIService.shared.generateFinalAnswer(
                        userQuery: userMessage,
                        dataResult: dataResult,
                        config: finalConfig
                    )
                    return finalAnswer
                } catch {
                    // 如果生成最终答案失败，返回格式化后的查询结果作为后备
                    print("⚠️ [AIAssistantView] 生成最终答案失败，使用格式化结果: \(error.localizedDescription)")
                    return formatQueryResultForDisplay(dataResult, intent: intent)
                }
                
            } catch {
                // AI 识别失败，使用本地后备方案
                print("⚠️ [AIAssistantView] 意图识别失败，使用本地后备方案: \(error.localizedDescription)")
                return generateLocalResponse(for: userMessage)
            }
        } else {
            // 没有 AI 配置，使用本地后备方案
            return generateLocalResponse(for: userMessage)
        }
    }
    
    // MARK: - 本地后备回复（当AI不可用时）
    private func generateLocalResponse(for userMessage: String) -> String {
        let lowercased = userMessage.lowercased()
        
        if lowercased.contains("今天") || lowercased.contains("今日") {
            return getTodayExpenses()
        }
        
        if lowercased.contains("昨天") {
            return getYesterdayExpenses()
        }
        
        if lowercased.contains("本月") || lowercased.contains("这个月") {
            return getMonthExpenses()
        }
        
        if lowercased.contains("收入") {
            return getIncomeSummary()
        }
        
        if lowercased.contains("分类") || lowercased.contains("类别") {
            return getCategoryInfo()
        }
        
        if lowercased.contains("建议") || lowercased.contains("推荐") {
            return getSuggestions()
        }
        
        return "我理解你的问题。我可以帮你：\n1. 快速记账（如：'记一笔午餐50元'）\n2. 查询账单（如：'今天花了多少钱？'）\n3. 分析支出（如：'本月支出统计'）\n4. 提供建议\n\n试试问我这些问题吧！"
    }
    
    // MARK: - 执行查询意图
    private func executeQueryIntent(_ intent: QueryIntent) -> String {
        // 使用 LocalDataService 执行查询
        let rawResult = LocalDataService.executeIntent(intent, context: modelContext)
        
        // 如果返回空字符串（unknown 操作），返回默认回复
        if rawResult.isEmpty {
            return "我理解你的问题。我可以帮你：\n1. 快速记账（如：'记一笔午餐50元'）\n2. 查询账单（如：'今天花了多少钱？'）\n3. 分析支出（如：'本月支出统计'）\n4. 提供建议\n\n试试问我这些问题吧！"
        }
        
        // 将 LocalDataService 的简洁格式转换为更友好的中文格式
        return formatQueryResultForDisplay(rawResult, intent: intent)
    }
    
    // MARK: - 格式化查询结果用于显示
    private func formatQueryResultForDisplay(_ rawResult: String, intent: QueryIntent) -> String {
        // 如果是 sum 操作，转换为友好的中文格式
        if intent.operation == .sum {
            // 解析 "Total: 150.00\nRecords: 5" 格式
            var result = "📊 查询结果：\n\n"
            
            if let totalMatch = rawResult.range(of: #"Total: ([\d.]+)"#, options: .regularExpression) {
                let totalStr = String(rawResult[totalMatch])
                if let totalValue = Double(totalStr.replacingOccurrences(of: "Total: ", with: "")) {
                    result += "💰 总金额：¥\(String(format: "%.2f", totalValue))\n"
                }
            }
            
            if let recordsMatch = rawResult.range(of: #"Records: (\d+)"#, options: .regularExpression) {
                let recordsStr = String(rawResult[recordsMatch])
                if let recordsValue = Int(recordsStr.replacingOccurrences(of: "Records: ", with: "")) {
                    result += "📝 记录数：\(recordsValue)笔\n"
                }
            }
            
            // 添加筛选条件
            if rawResult.contains("Filters:") {
                let filtersPart = rawResult.components(separatedBy: "Filters: ").last ?? ""
                if !filtersPart.isEmpty {
                    result += "\n筛选条件：\n"
                    let filters = filtersPart.components(separatedBy: ", ")
                    for filter in filters {
                        result += "• \(filter)\n"
                    }
                }
            }
            
            return result
        }
        
        // 如果是 list 操作，解析 CSV 格式并转换为友好显示
        if intent.operation == .list {
            let lines = rawResult.components(separatedBy: "\n")
            guard lines.count > 1 else {
                return rawResult
            }
            
            var result = "📋 查询结果：\n\n"
            
            // 跳过 CSV 标题行
            let dataLines = Array(lines.dropFirst())
            let count = dataLines.filter { !$0.isEmpty && !$0.contains("...") }.count
            
            result += "📝 共找到 \(count) 条记录\n\n"
            
            if count == 0 {
                result += "暂无符合条件的记录"
            } else {
                result += "最近记录：\n"
                
                for (index, line) in dataLines.prefix(20).enumerated() {
                    if line.isEmpty || line.contains("...") {
                        continue
                    }
                    
                    let components = line.components(separatedBy: ",")
                    if components.count >= 3 {
                        let dateStr = components[0].trimmingCharacters(in: .whitespaces)
                        let nameStr = components[1].trimmingCharacters(in: .whitespaces)
                        let amountStr = components[2].trimmingCharacters(in: .whitespaces)
                        let categoryStr = components.count > 3 ? components[3].trimmingCharacters(in: .whitespaces) : ""
                        let accountStr = components.count > 4 ? components[4].trimmingCharacters(in: .whitespaces) : ""
                        
                        result += "\(index + 1). \(nameStr) - ¥\(amountStr)\n"
                        result += "   \(dateStr)"
                        if !categoryStr.isEmpty {
                            result += " | \(categoryStr)"
                        }
                        if !accountStr.isEmpty {
                            result += " | \(accountStr)"
                        }
                        result += "\n\n"
                    }
                }
                
                if count > 20 {
                    result += "... 还有 \(count - 20) 条记录"
                }
            }
            
            return result
        }
        
        // 其他情况，直接返回原始结果
        return rawResult
    }
    
    // MARK: - 旧版执行查询意图（已废弃，保留作为参考）
    private func executeQueryIntent_OLD(_ intent: QueryIntent) -> String {
        // 解析日期范围
        let startDate = parseIntentDate(intent.startDate)
        let endDate = parseIntentDate(intent.endDate)
        
        // 构建SwiftData查询
        let descriptor: FetchDescriptor<ExpenseItem>
        
        // 根据筛选条件构建谓词
        if let start = startDate, let end = endDate {
            // 日期范围 + 分类 + 账户
            if let categoryName = intent.categoryName, let accountName = intent.accountName {
                descriptor = FetchDescriptor<ExpenseItem>(
                    predicate: #Predicate<ExpenseItem> { item in
                        item.date >= start && item.date <= end &&
                        item.category == categoryName &&
                        item.accountName == accountName
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            } else if let categoryName = intent.categoryName {
                descriptor = FetchDescriptor<ExpenseItem>(
                    predicate: #Predicate<ExpenseItem> { item in
                        item.date >= start && item.date <= end &&
                        item.category == categoryName
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            } else if let accountName = intent.accountName {
                descriptor = FetchDescriptor<ExpenseItem>(
                    predicate: #Predicate<ExpenseItem> { item in
                        item.date >= start && item.date <= end &&
                        item.accountName == accountName
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            } else {
                descriptor = FetchDescriptor<ExpenseItem>(
                    predicate: #Predicate<ExpenseItem> { item in
                        item.date >= start && item.date <= end
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            }
        } else if let start = startDate {
            // 只有开始日期
            if let categoryName = intent.categoryName, let accountName = intent.accountName {
                descriptor = FetchDescriptor<ExpenseItem>(
                    predicate: #Predicate<ExpenseItem> { item in
                        item.date >= start &&
                        item.category == categoryName &&
                        item.accountName == accountName
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            } else if let categoryName = intent.categoryName {
                descriptor = FetchDescriptor<ExpenseItem>(
                    predicate: #Predicate<ExpenseItem> { item in
                        item.date >= start && item.category == categoryName
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            } else if let accountName = intent.accountName {
                descriptor = FetchDescriptor<ExpenseItem>(
                    predicate: #Predicate<ExpenseItem> { item in
                        item.date >= start && item.accountName == accountName
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            } else {
                descriptor = FetchDescriptor<ExpenseItem>(
                    predicate: #Predicate<ExpenseItem> { item in
                        item.date >= start
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            }
        } else if let end = endDate {
            // 只有结束日期
            if let categoryName = intent.categoryName, let accountName = intent.accountName {
                descriptor = FetchDescriptor<ExpenseItem>(
                    predicate: #Predicate<ExpenseItem> { item in
                        item.date <= end &&
                        item.category == categoryName &&
                        item.accountName == accountName
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            } else if let categoryName = intent.categoryName {
                descriptor = FetchDescriptor<ExpenseItem>(
                    predicate: #Predicate<ExpenseItem> { item in
                        item.date <= end && item.category == categoryName
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            } else if let accountName = intent.accountName {
                descriptor = FetchDescriptor<ExpenseItem>(
                    predicate: #Predicate<ExpenseItem> { item in
                        item.date <= end && item.accountName == accountName
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            } else {
                descriptor = FetchDescriptor<ExpenseItem>(
                    predicate: #Predicate<ExpenseItem> { item in
                        item.date <= end
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            }
        } else {
            // 没有日期范围，只有分类或账户筛选
            if let categoryName = intent.categoryName, let accountName = intent.accountName {
                descriptor = FetchDescriptor<ExpenseItem>(
                    predicate: #Predicate<ExpenseItem> { item in
                        item.category == categoryName && item.accountName == accountName
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            } else if let categoryName = intent.categoryName {
                descriptor = FetchDescriptor<ExpenseItem>(
                    predicate: #Predicate<ExpenseItem> { item in
                        item.category == categoryName
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            } else if let accountName = intent.accountName {
                descriptor = FetchDescriptor<ExpenseItem>(
                    predicate: #Predicate<ExpenseItem> { item in
                        item.accountName == accountName
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            } else {
                // 没有筛选条件，获取所有记录
                descriptor = FetchDescriptor<ExpenseItem>(
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            }
        }
        
        guard let expenses = try? modelContext.fetch(descriptor) else {
            return "❌ 查询数据时出现错误"
        }
        
        // 根据操作类型返回结果
        switch intent.operation {
        case .sum:
            return formatSumResult(expenses: expenses, intent: intent)
        case .list:
            return formatListResult(expenses: expenses, intent: intent)
        case .count:
            let count = expenses.count
            return "📊 查询结果：\n\n📝 共找到 \(count) 条记录"
        case .chat:
            return intent.chatResponse ?? "你好！我是你的AI记账助手，可以帮你查询和分析财务数据。"
        case .unknown:
            return "我理解你的问题。我可以帮你：\n1. 快速记账（如：'记一笔午餐50元'）\n2. 查询账单（如：'今天花了多少钱？'）\n3. 分析支出（如：'本月支出统计'）\n4. 提供建议\n\n试试问我这些问题吧！"
        }
    }
    
    // MARK: - 解析意图日期
    private func parseIntentDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        
        // 处理"today"
        if dateString.lowercased() == "today" || dateString.lowercased() == "今天" {
            return Calendar.current.startOfDay(for: Date())
        }
        
        // 处理相对偏移（如"-7d"）
        if dateString.hasPrefix("-") || dateString.hasPrefix("+") {
            let isNegative = dateString.hasPrefix("-")
            let numberString = String(dateString.dropFirst())
            
            if numberString.hasSuffix("d") {
                let daysString = String(numberString.dropLast())
                if let days = Int(daysString) {
                    let calendar = Calendar.current
                    let offset = isNegative ? -days : days
                    let date = calendar.date(byAdding: .day, value: offset, to: Date()) ?? Date()
                    return calendar.startOfDay(for: date)
                }
            }
        }
        
        // 尝试解析ISO8601格式
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            return Calendar.current.startOfDay(for: date)
        }
        
        // 尝试简单日期格式
        let simpleFormatter = DateFormatter()
        simpleFormatter.dateFormat = "yyyy-MM-dd"
        if let date = simpleFormatter.date(from: dateString) {
            return Calendar.current.startOfDay(for: date)
        }
        
        return nil
    }
    
    // MARK: - 格式化结果
    private func formatSumResult(expenses: [ExpenseItem], intent: QueryIntent) -> String {
        let total = expenses.reduce(0.0) { $0 + $1.amount }
        let count = expenses.count
        
        var result = "📊 查询结果：\n\n"
        result += "💰 总金额：¥\(String(format: "%.2f", total))\n"
        result += "📝 记录数：\(count)笔\n"
        
        // 添加筛选条件说明
        var filters: [String] = []
        if intent.startDate != nil || intent.endDate != nil {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            if let start = parseIntentDate(intent.startDate), let end = parseIntentDate(intent.endDate) {
                filters.append("日期：\(dateFormatter.string(from: start)) 至 \(dateFormatter.string(from: end))")
            } else if let start = parseIntentDate(intent.startDate) {
                filters.append("日期：从 \(dateFormatter.string(from: start))")
            } else if let end = parseIntentDate(intent.endDate) {
                filters.append("日期：至 \(dateFormatter.string(from: end))")
            }
        }
        if let category = intent.categoryName {
            filters.append("分类：\(category)")
        }
        if let account = intent.accountName {
            filters.append("账户：\(account)")
        }
        
        if !filters.isEmpty {
            result += "\n筛选条件：\n" + filters.map { "• \($0)" }.joined(separator: "\n")
        }
        
        return result
    }
    
    private func formatListResult(expenses: [ExpenseItem], intent: QueryIntent) -> String {
        let count = expenses.count
        
        var result = "📋 查询结果：\n\n"
        result += "📝 共找到 \(count) 条记录\n\n"
        
        if expenses.isEmpty {
            result += "暂无符合条件的记录"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MM-dd HH:mm"
            
            result += "最近记录：\n"
            for (index, expense) in expenses.prefix(10).enumerated() {
                result += "\(index + 1). \(expense.title) - ¥\(String(format: "%.2f", expense.amount))\n"
                result += "   \(dateFormatter.string(from: expense.date)) | \(expense.category)"
                if let account = expense.accountName {
                    result += " | \(account)"
                }
                result += "\n\n"
            }
            
            if expenses.count > 10 {
                result += "... 还有 \(expenses.count - 10) 条记录"
            }
        }
        
        return result
    }
    
    // MARK: - 本地处理记账（后备方案）
    private func processExpenseRecordingLocal(_ input: String) -> String {
        let (amount, title, category) = parseAIInput(input)
        
        if let amount = amount, let category = category {
            // 创建账单
            let expense = ExpenseItem(
                amount: amount,
                title: title ?? "AI智能记账",
                date: Date(),
                category: category.name,
                accountName: nil
            )
            
            modelContext.insert(expense)
            
            // 增加分类使用次数
            DataSeeder.incrementCategoryUsage(categoryName: category.name, context: modelContext)
            
            // 保存
            try? modelContext.save()
            
            // 触觉反馈
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            return "✅ 已成功记录：\n💰 金额：¥\(String(format: "%.2f", amount))\n📝 描述：\(title ?? "AI智能记账")\n🏷️ 分类：\(category.name)"
        } else {
            return "抱歉，我没有理解你的记账信息。请尝试这样输入：\n• '午餐50元'\n• '打车30块'\n• '买衣服200元'"
        }
    }
    
    // MARK: - 查询功能
    private func getTodayExpenses() -> String {
        let today = Calendar.current.startOfDay(for: Date())
        let todayExpenses = recentExpenses.filter { Calendar.current.isDate($0.date, inSameDayAs: Date()) }
        let total = todayExpenses.reduce(0) { $0 + $1.amount }
        
        return "📊 今日支出统计：\n💰 总金额：¥\(String(format: "%.2f", total))\n📝 记录数：\(todayExpenses.count)笔\n\n" + (todayExpenses.isEmpty ? "今天还没有支出记录" : "最近记录：\n" + todayExpenses.prefix(3).map { "• \($0.title) ¥\(String(format: "%.2f", $0.amount))" }.joined(separator: "\n"))
    }
    
    private func getYesterdayExpenses() -> String {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let yesterdayExpenses = recentExpenses.filter { Calendar.current.isDate($0.date, inSameDayAs: yesterday) }
        let total = yesterdayExpenses.reduce(0) { $0 + $1.amount }
        
        return "📊 昨日支出统计：\n💰 总金额：¥\(String(format: "%.2f", total))\n📝 记录数：\(yesterdayExpenses.count)笔"
    }
    
    private func getMonthExpenses() -> String {
        let monthExpenses = recentExpenses.filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month) }
        let total = monthExpenses.reduce(0) { $0 + $1.amount }
        
        return "📊 本月支出统计：\n💰 总金额：¥\(String(format: "%.2f", total))\n📝 记录数：\(monthExpenses.count)笔"
    }
    
    private func getExpenseSummary() -> String {
        let total = recentExpenses.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
        return "💰 总支出：¥\(String(format: "%.2f", total))\n📝 总记录数：\(recentExpenses.count)笔"
    }
    
    private func getIncomeSummary() -> String {
        // 这里需要根据实际数据计算收入
        return "📈 收入统计功能开发中..."
    }
    
    private func getCategoryInfo() -> String {
        let categories = allCategories.prefix(5).map { "• \($0.name)" }.joined(separator: "\n")
        return "🏷️ 常用分类：\n\(categories)"
    }
    
    private func getSuggestions() -> String {
        return "💡 智能建议：\n1. 定期查看支出统计，了解消费习惯\n2. 设置预算，控制支出\n3. 及时记录每笔支出，保持账本准确\n4. 定期分析分类支出，优化消费结构"
    }
    
    // MARK: - 解析输入
    private func parseAIInput(_ input: String) -> (amount: Double?, title: String?, category: Category?) {
        var amount: Double?
        var title: String?
        var category: Category?
        
        // 提取金额
        let amountPattern = #"(\d+(?:\.\d+)?)\s*[元块]?"#
        if let range = input.range(of: amountPattern, options: .regularExpression) {
            let amountStr = String(input[range])
                .replacingOccurrences(of: "元", with: "")
                .replacingOccurrences(of: "块", with: "")
                .replacingOccurrences(of: "¥", with: "")
                .trimmingCharacters(in: .whitespaces)
            amount = Double(amountStr)
        }
        
        // 提取标题
        title = input
            .replacingOccurrences(of: amountPattern, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        
        // 智能匹配分类
        category = matchCategory(from: input)
        
        return (amount, title, category)
    }
    
    private func matchCategory(from input: String) -> Category? {
        let lowercased = input.lowercased()
        
        let keywordMap: [String: [String]] = [
            "餐饮": ["餐", "饭", "吃", "餐厅", "食堂", "外卖", "午餐", "晚餐", "早餐"],
            "零食": ["零食", "小吃", "饮料", "奶茶", "咖啡"],
            "杂货": ["超市", "购物", "买", "杂货"],
            "公共交通": ["公交", "地铁", "交通", "出行"],
            "出租车": ["打车", "出租", "滴滴", "的士"],
            "衣服": ["衣服", "服装", "买衣服"],
            "电影": ["电影", "影院", "看片"],
            "游戏": ["游戏", "充值", "氪金"],
            "医疗": ["医院", "看病", "药", "医疗"],
            "社交": ["聚会", "聚餐", "请客", "社交"]
        ]
        
        for (categoryName, keywords) in keywordMap {
            if keywords.contains(where: { lowercased.contains($0) }) {
                return allCategories.first { $0.name == categoryName }
            }
        }
        
        return allCategories.first { $0.name == "其他" } ?? allCategories.first
    }
    
    // MARK: - 滚动到底部
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = messages.last {
            withAnimation {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
    
    // MARK: - 记账处理
    private func processExpenseRecordingWithAI(_ userMessage: String) async throws -> String {
        let config = selectedConfig ?? manager.activeConfig
        guard let finalConfig = config, manager.getAPIKey(for: finalConfig) != nil else {
            return "⚠️ 请先在设置中配置AI服务才能使用智能记账功能。"
        }
        
        // 使用AIService解析交易信息
        let result = try await AIService.shared.parseTransaction(
            text: userMessage,
            categories: allCategories,
            accounts: accounts,
            config: finalConfig
        )
        
        // 检查是否有金额
        guard let amount = result.amount, amount > 0 else {
            return "抱歉，我没有识别到金额信息。请告诉我具体的金额，例如：'记一笔午餐50元'"
        }
        
        // 确定分类
        let category: Category
        if let categoryName = result.categoryName,
           let matchedCategory = allCategories.first(where: { $0.name == categoryName }) {
            category = matchedCategory
        } else {
            // 使用默认分类
            category = allCategories.first(where: { $0.name == "其他" }) ?? allCategories.first!
        }
        
        // 确定账户
        let account: Account?
        if let accountName = result.accountName {
            account = accounts.first(where: { $0.name == accountName })
        } else {
            account = accounts.first
        }
        
        // 确定日期
        let expenseDate: Date
        if let dateString = result.date,
           let parsedDate = AIService.parseDate(dateString) {
            expenseDate = parsedDate
        } else {
            expenseDate = Date()
        }
        
        // 确定标题
        let title = result.note?.trimmingCharacters(in: .whitespaces) ?? category.name
        
        // 创建账单
        await MainActor.run {
            let expense = ExpenseItem(
                amount: amount,
                title: title,
                date: expenseDate,
                category: category.name,
                accountName: account?.name
            )
            
            modelContext.insert(expense)
            
            // 增加分类的使用次数
            DataSeeder.incrementCategoryUsage(categoryName: category.name, context: modelContext)
            
            // 更新账户余额
            if let account = account {
                let isIncome = category.categoryType == .income
                if isIncome {
                    account.balance += amount
                } else {
                    account.balance -= amount
                }
            }
            
            // 保存更改
            try? modelContext.save()
        }
        
        // 返回成功消息
        var response = "✅ 记账成功！\n\n"
        response += "💰 金额：¥\(String(format: "%.2f", amount))\n"
        response += "🏷️ 分类：\(category.name)\n"
        if let account = account {
            response += "💳 账户：\(account.name)\n"
        }
        response += "📝 备注：\(title)\n"
        response += "📅 日期：\(expenseDate.formatted(date: .abbreviated, time: .shortened))"
        
        return response
    }
    
    // MARK: - 语音输入处理
    private func requestSpeechPermissions() async {
        let granted = await speechManager.requestPermissions()
        if !granted {
            await MainActor.run {
                showPermissionAlert = true
            }
        }
    }
    
    private func startVoiceRecording() {
        // 如果已经在录音，不重复开始
        guard !speechManager.isRecording else { return }
        
        guard speechManager.hasAllPermissions else {
            Task {
                await requestSpeechPermissions()
            }
            return
        }
        
        do {
            try speechManager.startRecording()
            
            // 触觉反馈：开始录音
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.prepare()
            impactFeedback.impactOccurred()
            
            // 轻微震动反馈
            let selectionFeedback = UISelectionFeedbackGenerator()
            selectionFeedback.selectionChanged()
        } catch {
            print("❌ [AIAssistantView] 开始录音失败: \(error.localizedDescription)")
            if let speechError = error as? SpeechError, speechError == .permissionDenied {
                showPermissionAlert = true
            }
        }
    }
    
    private func stopVoiceRecording() {
        // 如果不在录音，直接返回
        guard speechManager.isRecording else { return }
        
        speechManager.stopRecording()
        
        // 触觉反馈：停止录音
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
        
        // 重置按压状态
        isPressingMic = false
    }
    
    private func processVoiceInput() {
        let transcript = speechManager.transcript
        guard !transcript.isEmpty else { return }
        
        isProcessingVoice = true
        
        Task {
            do {
                // 使用AIService解析语音输入
                let config = selectedConfig ?? manager.activeConfig
                guard let finalConfig = config, manager.getAPIKey(for: finalConfig) != nil else {
                    await MainActor.run {
                        isProcessingVoice = false
                        // 如果没有配置，直接使用转录文本作为输入
                        inputText = transcript
                    }
                    return
                }
                
                let result = try await AIService.shared.parseTransaction(
                    text: transcript,
                    categories: allCategories,
                    accounts: accounts,
                    config: finalConfig
                )
                
                await MainActor.run {
                    isProcessingVoice = false
                    
                    // 构建输入文本，直接使用转录文本
                    inputText = transcript
                    isInputFocused = true
                    
                    // 自动发送消息（AI会自动识别记账意图）
                    sendMessage()
                }
            } catch {
                await MainActor.run {
                    isProcessingVoice = false
                    // 如果解析失败，直接使用转录文本
                    inputText = transcript
                    isInputFocused = true
                }
            }
        }
    }
    
    // MARK: - 录音覆盖层
    private var recordingOverlay: some View {
        ZStack {
            // 渐变背景，更柔和
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .transition(.opacity)
            
            VStack(spacing: 28) {
                // 中央麦克风图标（带脉冲动画）
                ZStack {
                    // 外圈脉冲动画
                    Circle()
                        .stroke(Color.red.opacity(0.4), lineWidth: 3)
                        .frame(width: 100, height: 100)
                        .scaleEffect(1 + audioLevelCGFloat * 0.3)
                        .opacity(0.6 + audioLevelDouble * 0.4)
                        .animation(.easeInOut(duration: 0.2), value: speechManager.audioLevel)
                    
                    // 内圈
                    Circle()
                        .fill(Color.red.opacity(0.2))
                        .frame(width: 80, height: 80)
                        .scaleEffect(1 + audioLevelCGFloat * 0.2)
                        .animation(.easeInOut(duration: 0.2), value: speechManager.audioLevel)
                    
                    // 麦克风图标
                    Image(systemName: "mic.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.bottom, 8)
                
                // 波形动画（改进版）
                HStack(spacing: 3) {
                    ForEach(0..<7) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: [Color.red, Color.orange],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(
                                width: 3,
                                height: waveHeight(for: index)
                            )
                            .animation(
                                .spring(response: 0.15, dampingFraction: 0.5)
                                .delay(Double(index) * 0.05),
                                value: speechManager.audioLevel
                            )
                    }
                }
                .frame(height: 60)
                
                // 提示文字
                VStack(spacing: 8) {
                    Text("正在录音...")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("松开手指结束录音")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                // 实时转录文本（改进显示）
                if !speechManager.transcript.isEmpty {
                    Text(speechManager.transcript)
                        .font(.body)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.black.opacity(0.6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 40)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .animation(.spring(response: 0.3), value: speechManager.transcript)
                }
            }
            .padding(.vertical, 60)
        }
    }
    
    // MARK: - 处理语音解析覆盖层
    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // 改进的加载指示器
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 4)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                        .animation(
                            .linear(duration: 1.0)
                            .repeatForever(autoreverses: false),
                            value: isProcessingVoice
                        )
                }
                
                Text("正在分析语音...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                if !speechManager.transcript.isEmpty {
                    Text(speechManager.transcript)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.1)
            .ignoresSafeArea()
        
        FloatingAIAssistant(showAIAssistant: .constant(false))
    }
    .modelContainer(for: [ExpenseItem.self, Category.self], inMemory: true)
}

#Preview("AI聊天窗口") {
    AIAssistantView()
        .modelContainer(for: [ExpenseItem.self, Category.self], inMemory: true)
}
