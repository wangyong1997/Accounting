import SwiftUI
import SwiftData

/// 全局悬浮语音助手入口（可拖拽，跨页面可见）
struct FloatingVoiceAssistant: View {
    @State private var showOverlay: Bool = false
    @State private var dragOffset: CGSize = .zero

    @AppStorage("floatingVoicePositionX") private var savedPositionX: Double = 0
    @AppStorage("floatingVoicePositionY") private var savedPositionY: Double = 0

    var body: some View {
        GeometryReader { geometry in
            // 右下角默认位置：避开底部 TabBar（约 80）与安全区
            let safeBottom = geometry.safeAreaInsets.bottom
            let safeTop = geometry.safeAreaInsets.top
            let buttonRadius: CGFloat = 28 // 56 / 2
            let bottomBarHeight: CGFloat = 80
            let bottomMargin: CGFloat = 16
            let rightMargin: CGFloat = 16

            let defaultX = geometry.size.width - rightMargin - buttonRadius
            let defaultY = geometry.size.height - safeBottom - bottomBarHeight - bottomMargin - buttonRadius

            let baseX = savedPositionX > 0 ? savedPositionX : Double(defaultX)
            let baseY = savedPositionY > 0 ? savedPositionY : Double(defaultY)

            let proposedX = CGFloat(baseX) + dragOffset.width
            let proposedY = CGFloat(baseY) + dragOffset.height

            // 约束：不贴边 & 不挡顶部/底部
            let clampedX = min(max(buttonRadius + 8, proposedX), geometry.size.width - buttonRadius - 8)
            let minY = safeTop + 80
            let maxY = geometry.size.height - safeBottom - bottomBarHeight - buttonRadius - 8
            let clampedY = min(max(minY, proposedY), maxY)

            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                showOverlay = true
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 6)

                    Image(systemName: "mic.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
            .position(
                x: clampedX,
                y: clampedY
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        savedPositionX = Double(clampedX)
                        savedPositionY = Double(clampedY)
                        dragOffset = .zero
                    }
            )
        }
        .allowsHitTesting(true)
        .fullScreenCover(isPresented: $showOverlay) {
            VoiceAssistantOverlay(isPresented: $showOverlay)
        }
    }
}

/// 语音助手面板（参考图：待机/聆听/思考/回答）
struct VoiceAssistantOverlay: View {
    enum Phase: Equatable {
        case idle
        case listening
        case thinking
        case answering
        case error(String)
    }

    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    @StateObject private var manager = LLMManager.shared

    @Query(sort: \ExpenseItem.date, order: .reverse) private var recentExpenses: [ExpenseItem]
    @Query private var allCategories: [Category]
    @Query(sort: \Account.name) private var accounts: [Account]

    @State private var phase: Phase = .idle
    @State private var speechManager = SpeechManager()
    @State private var showPermissionAlert = false

    @State private var transcript: String = ""
    @State private var answerText: String = ""
    @State private var speakingText: String = ""          // 打字机效果（speaking）
    @State private var audioLevels: [CGFloat] = Array(repeating: 0.3, count: 12) // 参考 UI：12 条柱
    @State private var waveformTimer: Timer?
    @State private var speakingTimer: Timer?

    // 动画用
    @State private var thinkingDot: Int = 0

    private var activeConfig: LLMConfig? { manager.activeConfig }
    
    // MARK: - Account defaulting
    /// 语音记账时，如果未明确账户，默认记到“现金”（保证资产页/账户统计能看到）
    private func resolveAccountName(userText: String, aiAccountName: String?) -> String? {
        if let ai = aiAccountName, !ai.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ai
        }
        
        let text = userText.lowercased()
        
        // 1) 先按关键词匹配（让用户一句话里不同笔可选不同支付方式）
        // 这里做“包含匹配”，兼容用户账户名称是“微信支付/微信零钱/微信”等
        let keywordToPreferredAccountName: [(keywords: [String], candidates: [String])] = [
            (["微信", "wx", "wechat"], ["微信支付", "微信零钱", "微信"]),
            (["支付宝", "alipay", "zhifubao"], ["支付宝"]),
            (["银行卡", "储蓄卡", "借记卡", "debit"], ["银行卡"]),
            (["信用卡", "花呗", "白条", "credit"], ["信用卡/花呗", "信用卡"]),
            (["现金", "cash"], ["现金"])
        ]
        
        for entry in keywordToPreferredAccountName {
            if entry.keywords.contains(where: { text.contains($0.lowercased()) }) {
                // 优先找 candidates 完整命中
                for c in entry.candidates {
                    if let matched = accounts.first(where: { $0.name.contains(c) }) {
                        return matched.name
                    }
                }
                // 再找任意包含关键词的账户
                if let matched = accounts.first(where: { acc in
                    entry.keywords.contains(where: { acc.name.lowercased().contains($0.lowercased()) })
                }) {
                    return matched.name
                }
            }
        }
        
        // 2) 默认现金（如果存在）
        if let cash = accounts.first(where: { $0.name == "现金" }) {
            return cash.name
        }
        // 兼容可能的英文命名
        if let cash = accounts.first(where: { $0.name.lowercased() == "cash" }) {
            return cash.name
        }
        
        // 3) 退化：使用第一个账户（避免 nil 导致资产不更新）
        return accounts.first?.name
    }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                header
                Spacer()

                centerContent
                    .padding(.horizontal, 24)

                Spacer()

                bottomControls
                    .padding(.bottom, 28)
            }
        }
        .onAppear {
            Task {
                let granted = await speechManager.requestPermissions()
                if !granted {
                    showPermissionAlert = true
                }
            }
            updateWaveformTimer()
        }
        .onDisappear {
            waveformTimer?.invalidate()
            speakingTimer?.invalidate()
            waveformTimer = nil
            speakingTimer = nil
        }
        .onChange(of: speechManager.isRecording) { isRecording in
            if isRecording {
                phase = .listening
                answerText = ""
                speakingText = ""
            } else {
                // 录音结束：拿最终转写去分析
                let text = speechManager.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                transcript = text
                if !text.isEmpty {
                    analyze(text: text)
                } else if phase == .listening {
                    phase = .idle
                }
            }
        }
        .onChange(of: phase) { _ in
            updateWaveformTimer()
        }
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
    }

    private var background: some View {
        ZStack {
            // 模拟 React：bg-foreground/95 + backdrop-blur-xl
            Color.black.opacity(0.95).ignoresSafeArea()
            // SwiftUI 的 blur 会影响自身，这里用轻微雾化层模拟
            Rectangle()
                .fill(Color.white.opacity(0.02))
                .ignoresSafeArea()
                .blur(radius: 24)
        }
    }

    private var header: some View {
        HStack {
            Spacer()
            Button(action: {
                isPresented = false
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.top, 18)
            .padding(.trailing, 18)
        }
    }

    private var centerContent: some View {
        VStack(spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(listeningColor)
                Text("财务AI助手")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(.white)
            }

            Text(statusText)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.white.opacity(0.8))

            orb
                .padding(.top, 8)

            if !answerText.isEmpty {
                Text(answerText)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .padding(.horizontal, 18)
                    .padding(.top, 4)
            }

            Text("支持语音查询收支、预算分析等")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.45))
                .padding(.top, 10)
        }
    }

    private var orb: some View {
        ZStack {
            // Glow effect（参考 React）
            Circle()
                .fill(glowColor.opacity(0.25))
                .frame(width: 260, height: 260)
                .blur(radius: 48)
                .scaleEffect(phase == .idle ? 1.0 : 1.15)
                .animation(.easeInOut(duration: 0.5), value: phase)

            // Main Orb
            Circle()
                .fill(mainOrbColor)
                .frame(width: 160, height: 160)
                .scaleEffect(phase == .idle ? 1.0 : 1.1)
                .animation(.easeInOut(duration: 0.5), value: phase)

            // Inner Ring
            Circle()
                .stroke(ringColor, lineWidth: 2)
                .frame(width: 128, height: 128)

            // Waveform
            waveformBars

            // Ripple effects when listening
            if phase == .listening {
                ripple
            }
        }
    }

    private var waveform: some View {
        // 旧实现保留但不使用
        EmptyView()
    }

    private var waveformBars: some View {
        let color = barColor
        return HStack(spacing: 4) {
            ForEach(0..<audioLevels.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(color)
                    .frame(width: 4, height: max(10, audioLevels[i] * 60))
                    .opacity(phase == .idle ? 0.5 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: audioLevels[i])
            }
        }
    }

    private var ripple: some View {
        ZStack {
            Circle()
                .stroke(listeningColor.opacity(0.28), lineWidth: 2)
                .frame(width: 170, height: 170)
                .scaleEffect(1.0)
                .opacity(0.9)
                .modifier(PingEffect(duration: 2.0, delay: 0.0))

            Circle()
                .stroke(listeningColor.opacity(0.18), lineWidth: 1)
                .frame(width: 170, height: 170)
                .scaleEffect(1.0)
                .opacity(0.9)
                .modifier(PingEffect(duration: 2.5, delay: 0.5))
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 14) {
            Button(action: {
                toggleRecording()
            }) {
                ZStack {
                    Circle()
                        .fill(buttonColor)
                        .frame(width: 92, height: 92)
                        .shadow(color: buttonColor.opacity(0.35), radius: 16, x: 0, y: 10)

                    if phase == .thinking || phase == .answering {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundColor(.white)
                            .opacity(phase == .answering ? 1.0 : 0.9)
                            .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: phase)
                    } else {
                        Image(systemName: buttonIcon)
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            Text(buttonHint)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.4))

            // Transcript / Response 区域（对齐 React）
            Group {
                switch phase {
                case .listening:
                    if !transcript.isEmpty {
                        Text(transcript + " |")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .transition(.opacity)
                    }
                case .thinking:
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color.amber)
                            .frame(width: 8, height: 8)
                            .offset(y: thinkingDot == 0 ? -4 : 0)
                        Circle()
                            .fill(Color.amber)
                            .frame(width: 8, height: 8)
                            .offset(y: thinkingDot == 1 ? -4 : 0)
                        Circle()
                            .fill(Color.amber)
                            .frame(width: 8, height: 8)
                            .offset(y: thinkingDot == 2 ? -4 : 0)
                    }
                    .onAppear {
                        startThinkingDots()
                    }
                case .answering:
                    if !speakingText.isEmpty {
                        Text(speakingText)
                            .font(.system(size: 17))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .transition(.opacity)
                    }
                case .idle:
                    if !answerText.isEmpty {
                        Text(answerText.prefix(50) + "…")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                    }
                case .error(let msg):
                    Text(msg)
                        .font(.system(size: 14))
                        .foregroundColor(.red.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
            }
            .frame(minHeight: 48)
        }
    }

    private var statusText: String {
        switch phase {
        case .idle:
            return "点击麦克风开始对话"
        case .listening:
            return "正在聆听..."
        case .thinking:
            return "正在思考..."
        case .answering:
            return "正在回答..."
        case .error(let msg):
            return "出错了：\(msg)"
        }
    }

    private var buttonColor: Color {
        switch phase {
        case .idle, .listening:
            return listeningColor
        case .thinking:
            return .amber
        case .answering:
            return speakingColor
        case .error:
            return .red
        }
    }

    private var buttonIcon: String {
        switch phase {
        case .listening:
            return "stop.fill"
        default:
            return "mic.fill"
        }
    }

    private var buttonHint: String {
        switch phase {
        case .listening:
            return "再次点击停止"
        default:
            return "点击开始"
        }
    }

    // MARK: - 颜色（对应 React income/expense/amber/blue）
    /// 与应用整体更搭配：Listening 用主蓝色，Answering 用偏紫以区分状态
    private var listeningColor: Color { Color.blue }
    private var speakingColor: Color { Color.purple }
    private var glowColor: Color {
        switch phase {
        case .listening: return listeningColor
        case .answering: return speakingColor
        case .thinking: return .amber
        case .idle: return listeningColor
        case .error: return .red
        }
    }
    private var mainOrbColor: Color {
        switch phase {
        case .listening: return listeningColor.opacity(0.18)
        case .answering: return speakingColor.opacity(0.18)
        case .thinking: return Color.amber.opacity(0.20)
        case .idle: return Color.white.opacity(0.10)
        case .error: return Color.red.opacity(0.20)
        }
    }
    private var ringColor: Color {
        switch phase {
        case .listening: return listeningColor.opacity(0.45)
        case .answering: return speakingColor.opacity(0.45)
        case .thinking: return Color.amber.opacity(0.50)
        case .idle: return Color.white.opacity(0.20)
        case .error: return Color.red.opacity(0.50)
        }
    }
    private var barColor: Color {
        switch phase {
        case .listening: return listeningColor.opacity(0.95)
        case .answering: return speakingColor.opacity(0.85)
        case .thinking: return Color.amber.opacity(0.85)
        case .idle: return Color.white.opacity(0.30)
        case .error: return Color.red.opacity(0.85)
        }
    }

    private func toggleRecording() {
        // listening 时点击停止；其他状态点击开始（若正在思考/回答则重新开始一次）
        if speechManager.isRecording {
            speechManager.stopRecording()
            return
        }

        do {
            transcript = ""
            answerText = ""
            speakingText = ""
            phase = .idle
            try speechManager.startRecording()
        } catch {
            showPermissionAlert = true
        }
    }

    private func analyze(text: String) {
        phase = .thinking
        speakingText = ""
        answerText = ""

        // 没有配置则走本地后备（简单）
        guard let cfg = activeConfig, manager.getAPIKey(for: cfg) != nil else {
            let final = localFallback(text)
            phase = .answering
            startSpeaking(text: final)
            return
        }

        Task {
            do {
                let final = try await generateVoiceAnswer(userText: text, config: cfg)
                await MainActor.run {
                    phase = .answering
                    startSpeaking(text: final)
                }
            } catch {
                await MainActor.run {
                    phase = .error(error.localizedDescription)
                }
            }
        }
    }

    // 复用你现有链路：Intent -> LocalDataService -> FinalAnswer（并支持“记账”）
    private func generateVoiceAnswer(userText: String, config: LLMConfig) async throws -> String {
        let lowercased = userText.lowercased()

        // 记账：直接解析并写入
        if lowercased.contains("记") || lowercased.contains("记账") || lowercased.contains("花了") || lowercased.contains("支出") || lowercased.contains("买了") {
            return try await recordExpensesWithAI(userText, config: config)
        }

        let intent = try await AIService.shared.parseQueryIntent(
            text: userText,
            categories: allCategories,
            accounts: accounts,
            config: config
        )

        if intent.operation == .unknown {
            return "我可以帮你查询收支、统计本月花费，或者帮你记账。你可以说：\n“今天花了多少？”\n“本月餐饮支出多少？”\n“记一笔午餐50元”"
        }

        let dataResult = LocalDataService.executeIntent(intent, context: modelContext)
        if dataResult.isEmpty {
            return "没有找到符合条件的记录。"
        }

        return try await AIService.shared.generateFinalAnswer(
            userQuery: userText,
            dataResult: dataResult,
            config: config
        )
    }

    private func recordExpenseWithAI(_ userText: String, config: LLMConfig) async throws -> String {
        let result = try await AIService.shared.parseTransaction(
            text: userText,
            categories: allCategories,
            accounts: accounts,
            config: config
        )

        guard let amount = result.amount, amount > 0 else {
            return "我没有识别到金额。你可以说：'记一笔午餐50元'。"
        }

        let categoryName = result.categoryName ?? (allCategories.first(where: { $0.name == "其他" })?.name ?? allCategories.first?.name) ?? "其他"
        let accountName = resolveAccountName(userText: userText, aiAccountName: result.accountName)
        let title = (result.note?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? (result.note ?? "") : "语音记账"
        let date = AIService.parseDate(result.date) ?? Date()

        await MainActor.run {
            let expense = ExpenseItem(
                amount: amount,
                title: title,
                date: date,
                category: categoryName,
                accountName: accountName
            )
            modelContext.insert(expense)
            DataSeeder.incrementCategoryUsage(categoryName: categoryName, context: modelContext)
            if let accountName, let account = accounts.first(where: { $0.name == accountName }) {
                // 按分类类型处理余额
                let isIncome = allCategories.first(where: { $0.name == categoryName })?.categoryType == .income
                if isIncome {
                    account.balance += amount
                } else {
                    account.balance -= amount
                }
            }
            try? modelContext.save()
        }

        return "已为你记录：¥\(String(format: "%.2f", amount))，分类：\(categoryName)。"
    }

    /// 支持一段话多笔记账：切分后逐条解析并写入
    private func recordExpensesWithAI(_ userText: String, config: LLMConfig) async throws -> String {
        let segments = splitIntoTransactionSegments(userText)

        // 如果没切出多段，就退化为单笔
        if segments.count <= 1 {
            return try await recordExpenseWithAI(userText, config: config)
        }

        var created: [(amount: Double, category: String, title: String)] = []
        var failedSegments: [String] = []

        for seg in segments {
            let trimmed = seg.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            do {
                // 给模型一点提示：这是“记一笔”
                let hintText = "记一笔：\(trimmed)"
                let result = try await AIService.shared.parseTransaction(
                    text: hintText,
                    categories: allCategories,
                    accounts: accounts,
                    config: config
                )

                guard let amount = result.amount, amount > 0 else {
                    failedSegments.append(trimmed)
                    continue
                }

                let categoryName = result.categoryName
                    ?? (allCategories.first(where: { $0.name == "其他" })?.name ?? allCategories.first?.name)
                    ?? "其他"

                let accountName = resolveAccountName(userText: trimmed, aiAccountName: result.accountName)
                let title = (result.note?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                    ? (result.note ?? "")
                    : trimmed

                let date = AIService.parseDate(result.date) ?? Date()

                await MainActor.run {
                    let expense = ExpenseItem(
                        amount: amount,
                        title: title,
                        date: date,
                        category: categoryName,
                        accountName: accountName
                    )
                    modelContext.insert(expense)
                    DataSeeder.incrementCategoryUsage(categoryName: categoryName, context: modelContext)
                    if let accountName,
                       let account = accounts.first(where: { $0.name == accountName }) {
                        let isIncome = allCategories.first(where: { $0.name == categoryName })?.categoryType == .income
                        if isIncome {
                            account.balance += amount
                        } else {
                            account.balance -= amount
                        }
                    }
                    try? modelContext.save()
                }

                created.append((amount: amount, category: categoryName, title: title))
            } catch {
                failedSegments.append(trimmed)
            }
        }

        if created.isEmpty {
            return "我没能识别出可记录的金额。你可以说：\n“午餐15元，买药20元，买水3元，帮我记三笔”。"
        }

        let total = created.reduce(0.0) { $0 + $1.amount }
        var reply = "✅ 已为你记录 \(created.count) 笔，合计 ¥\(String(format: "%.2f", total))。\n"
        for (idx, item) in created.prefix(5).enumerated() {
            reply += "\(idx + 1). \(item.title)  ¥\(String(format: "%.2f", item.amount))  (\(item.category))\n"
        }
        if created.count > 5 {
            reply += "… 还有 \(created.count - 5) 笔\n"
        }
        if !failedSegments.isEmpty {
            reply += "\n⚠️ 以下片段未识别成功（可再说一遍金额）：\n"
            reply += failedSegments.prefix(3).map { "• \($0)" }.joined(separator: "\n")
        }
        return reply.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 将一段话拆成多笔记账片段（按中文标点/连接词）
    private func splitIntoTransactionSegments(_ text: String) -> [String] {
        let cleaned = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "；", with: "，")
            .replacingOccurrences(of: "。", with: "，")
            .replacingOccurrences(of: ";", with: "，")
            .replacingOccurrences(of: ".", with: "，")

        // 把常见连接词也当分隔（尽量不误伤）
        let connectors = ["，然后", "然后", "，再", "再", "，又", "又", "，另外", "另外", "以及", "还有"]
        var normalized = cleaned
        for c in connectors {
            normalized = normalized.replacingOccurrences(of: c, with: "，")
        }

        let parts = normalized
            .split(separator: "，")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // 只保留“看起来像交易”的片段（含数字/金额单位）
        return parts.filter { part in
            part.range(of: #"\d"#, options: .regularExpression) != nil
            || part.contains("元")
            || part.contains("块")
        }
    }

    private func localFallback(_ text: String) -> String {
        // 极简后备：避免没配置时也能有反馈
        if text.contains("今天") {
            let todayExpenses = recentExpenses.filter { Calendar.current.isDate($0.date, inSameDayAs: Date()) }
            let total = todayExpenses.reduce(0) { $0 + $1.amount }
            return "今日共 \(todayExpenses.count) 笔，合计 ¥\(String(format: "%.2f", total))。"
        }
        if text.contains("本月") || text.contains("这个月") {
            let monthExpenses = recentExpenses.filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month) }
            let total = monthExpenses.reduce(0) { $0 + $1.amount }
            return "本月共 \(monthExpenses.count) 笔，合计 ¥\(String(format: "%.2f", total))。"
        }
        return "请先在设置里配置 AI 模型，或换个问法试试：'今天花了多少？'。"
    }

    // MARK: - 动画驱动
    private func updateWaveformTimer() {
        let shouldAnimate = (phase == .listening || phase == .answering)
        waveformTimer?.invalidate()
        waveformTimer = nil

        if shouldAnimate {
            waveformTimer = Timer.scheduledTimer(withTimeInterval: 0.10, repeats: true) { _ in
                // speaking/listening 用随机波形更像参考 UI（SpeechManager 也会更新 audioLevel）
                let base: CGFloat = 0.2
                let span: CGFloat = 0.8
                audioLevels = (0..<12).map { _ in base + CGFloat.random(in: 0...span) }
            }
        } else {
            audioLevels = Array(repeating: 0.3, count: 12)
        }
    }

    private func startThinkingDots() {
        thinkingDot = 0
        Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { timer in
            if phase == .thinking {
                thinkingDot = (thinkingDot + 1) % 3
            } else {
                timer.invalidate()
            }
        }
    }

    private func startSpeaking(text: String) {
        speakingTimer?.invalidate()
        speakingTimer = nil
        speakingText = ""
        answerText = text

        var idx = 0
        let chars = Array(text)
        speakingTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { timer in
            if phase != .answering {
                timer.invalidate()
                return
            }
            if idx <= chars.count {
                speakingText = String(chars.prefix(idx))
                idx += 1
            } else {
                timer.invalidate()
                // speaking 完成后回到 idle（保留最后一句摘要）
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if phase == .answering {
                        phase = .idle
                    }
                }
            }
        }
    }
}

// MARK: - 小工具
private extension Color {
    static var amber: Color { Color(red: 245/255, green: 158/255, blue: 11/255) } // 类似 Tailwind amber-500
}

/// 类似 Tailwind animate-ping 的圆环扩散
private struct PingEffect: ViewModifier {
    let duration: Double
    let delay: Double
    @State private var animate: Bool = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(animate ? 1.25 : 1.0)
            .opacity(animate ? 0.0 : 1.0)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.easeOut(duration: duration).repeatForever(autoreverses: false)) {
                        animate = true
                    }
                }
            }
    }
}

#Preview("FloatingVoiceAssistant") {
    ZStack {
        Color.gray.opacity(0.1).ignoresSafeArea()
        FloatingVoiceAssistant()
    }
    .modelContainer(for: [ExpenseItem.self, Category.self, Account.self], inMemory: true)
}

