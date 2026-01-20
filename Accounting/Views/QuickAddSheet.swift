import SwiftUI
import SwiftData
import Foundation
import StoreKit

struct QuickAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.requestReview) private var requestReview
    
    let selectedCategory: Category
    
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query private var allCategories: [Category] // 用于AI服务
    
    @State private var isCalculatorMode: Bool = false // 是否为计算器模式
    @State private var amount: String = "" // 直接输入金额（默认模式）
    @State private var expression: String = "" // 用户输入的表达式（计算器模式）
    @State private var calculatedAmount: Double = 0.0 // 计算结果
    @State private var title: String = ""
    @State private var selectedAccount: Account? = nil // 选择的支付账户
    @State private var showAccountPicker = false // 是否显示账户选择器
    @State private var showAISmartInput = false // 是否显示AI智能输入
    @State private var aiInputText: String = "" // AI输入文本
    @State private var isAIProcessing: Bool = false // AI处理中
    
    // 语音输入相关
    @State private var speechManager = SpeechManager()
    @State private var isProcessingVoice = false // 是否正在处理语音解析
    @State private var showPermissionAlert = false // 是否显示权限提示
    
    var body: some View {
        GeometryReader { geo in
            NavigationView {
                ZStack {
                    Color(red: 0.98, green: 0.98, blue: 0.98)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        // 顶部固定区域：分类显示和金额显示
                        VStack(spacing: 16) {
                            // 分类显示
                            HStack {
                            Image(systemName: selectedCategory.symbolName)
                                .font(.title3)
                                .foregroundColor(selectedCategory.color)
                            
                            Text(selectedCategory.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            // AI智能输入按钮
                            Button(action: {
                                showAISmartInput = true
                            }) {
                                Image(systemName: "sparkles")
                                    .font(.title3)
                                    .foregroundColor(.purple)
                            }
                            
                            // 语音输入按钮
                            voiceInputButton
                            
                            // 更多按钮（切换计算器模式）
                            Button(action: {
                                withAnimation {
                                    isCalculatorMode.toggle()
                                    // 切换模式时清空输入
                                    if isCalculatorMode {
                                        expression = ""
                                        calculatedAmount = 0.0
                                    } else {
                                        amount = ""
                                    }
                                }
                            }) {
                                Image(systemName: isCalculatorMode ? "keyboard" : "function")
                                    .font(.title3)
                                    .foregroundColor(isCalculatorMode ? selectedCategory.color : .gray)
                            }
                            
                            Button(action: {
                                dismiss()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal, 20)
                        // 使用安全区顶部 + 较大间距，避免在有刘海/状态栏设备上内容被遮挡
                        .padding(.top, geo.safeAreaInsets.top + 16)
                        
                        // 表达式和金额显示
                        amountDisplay
                            .padding(.bottom, 8)
                    }
                    
                    // 减少中间空隙，让支付方式与键盘更紧凑
                    //Spacer(minLength: 0)
                    
                    // 底部固定区域：数字键盘和完成按钮
                    VStack(spacing: 0) {
                        Divider()
                            .opacity(0.2)
                        
                        numberPad
                            .padding(.horizontal, 16)
                            .padding(.top, 8)   // 原 16，缩小与上方的间距
                            .padding(.bottom, 12)
                        
                        // 完成按钮（放在数字键盘下面）
                        doneButton
                            .padding(.bottom, 16)
                            .background(
                                Color(red: 0.98, green: 0.98, blue: 0.98)
                                    .ignoresSafeArea(edges: .bottom)
                            )
                    }
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showAccountPicker) {
                AccountPickerSheet(selectedAccount: $selectedAccount, accounts: accounts)
            }
            .sheet(isPresented: $showAISmartInput) {
                AISmartInputSheet(
                    inputText: $aiInputText,
                    isProcessing: $isAIProcessing,
                    onAnalyze: { config in
                        await analyzeWithAI(config: config)
                    }
                )
            }
            .onChange(of: expression) { oldValue, newValue in
                // 实时计算表达式结果
                if isCalculatorMode {
                    calculateExpression()
                }
            }
            .onAppear {
                // 如果是支出分类，自动选择有余额的账户
                if selectedCategory.categoryType == .expense {
                    selectDefaultAccount()
                }
                
                // 请求语音权限
                Task {
                    await requestSpeechPermissions()
                }
            }
            .onChange(of: speechManager.transcript) { oldValue, newValue in
                // 当录音停止且转录文本更新时，处理语音输入
                if !newValue.isEmpty && !speechManager.isRecording && !isProcessingVoice {
                    processVoiceInput(newValue)
                }
            }
            .overlay {
                // 录音状态覆盖层
                if speechManager.isRecording {
                    recordingOverlay
                }
                
                // 处理语音解析的加载指示器
                if isProcessingVoice {
                    processingOverlay
                }
            }
            .alert("需要权限", isPresented: $showPermissionAlert) {
                Button("去设置") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("需要授予语音识别和麦克风权限才能使用语音输入功能。")
            }
        }
    }
    
    // MARK: - 默认账户选择
    /// 自动选择有余额的账户作为默认支付方式
    private func selectDefaultAccount() {
        // 如果已经选择了账户，不自动选择
        guard selectedAccount == nil else { return }
        
        // 查找有余额的账户（余额 > 0）
        // 按创建时间排序，选择第一个有余额的账户
        if let accountWithBalance = accounts.first(where: { $0.balance > 0 }) {
            selectedAccount = accountWithBalance
            print("✅ [QuickAddSheet] 自动选择账户: \(accountWithBalance.name) (余额: ¥\(accountWithBalance.balance))")
        } else {
            // 如果所有账户都没有余额，选择第一个账户（即使余额为0）
            if let firstAccount = accounts.first {
                selectedAccount = firstAccount
                print("ℹ️ [QuickAddSheet] 所有账户余额为0，选择第一个账户: \(firstAccount.name)")
            }
        }
    }
    
    // MARK: - 金额显示
    private var amountDisplay: some View {
        let isCompactCalculatorHeader = isCalculatorMode && !expression.isEmpty
        
        return VStack(spacing: isCompactCalculatorHeader ? 10 : 16) {
            if isCalculatorMode {
                // 计算器模式：显示表达式
                if !expression.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("输入表达式")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 32)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(expression)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 32)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 44) // 限制表达式区域高度，避免把下方挤得太紧
                }
                
                // 结果金额显示
                Text(calculatedAmount == 0.0 ? "¥0.00" : "¥\(String(format: "%.2f", calculatedAmount))")
                    .font(.system(size: isCompactCalculatorHeader ? 42 : 48, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                // 默认模式：直接输入金额
                Text(amount.isEmpty ? "¥0.00" : "¥\(formatAmount(amount))")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // 描述输入
            TextField("描述", text: $title)
                .font(.system(size: 20, weight: .medium))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                )
                .padding(.horizontal, 32)
            
            // 支付方式选择
            Button(action: {
                showAccountPicker = true
            }) {
                HStack(spacing: 12) {
                    if let account = selectedAccount {
                        // 显示已选择的账户
                        Image(systemName: account.iconName)
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(account.color)
                            .clipShape(Circle())
                        
                        Text(account.name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                    } else {
                        // 未选择账户
                        Image(systemName: "creditcard.fill")
                            .font(.title3)
                            .foregroundColor(.gray)
                        
                        Text("选择支付方式")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                )
                .padding(.horizontal, 32)
            }
        }
        .padding(.vertical, isCompactCalculatorHeader ? 16 : 24)
    }
    
    // MARK: - 数字键盘
    @ViewBuilder
    private var numberPad: some View {
        if isCalculatorMode {
            // 计算器模式键盘
            calculatorPad
        } else {
            // 默认模式键盘（简单数字输入）
            simpleNumberPad
        }
    }
    
    // 默认模式：简单数字键盘
    private var simpleNumberPad: some View {
        VStack(spacing: 12) {
            ForEach(0..<3) { row in
                HStack(spacing: 12) {
                    ForEach(1..<4) { col in
                        let number = row * 3 + col
                        simpleNumberButton(number: "\(number)")
                    }
                }
            }
            
            // 最后一行：0, 删除
            HStack(spacing: 12) {
                simpleNumberButton(number: "0")
                deleteButton()
            }
        }
    }
    
    // 计算器模式键盘
    private var calculatorPad: some View {
        VStack(spacing: 12) {
            // 第一行：运算符
            HStack(spacing: 12) {
                operatorButton("+")
                operatorButton("-")
                operatorButton("×")
                operatorButton("÷")
            }
            
            // 数字行
            ForEach(0..<3) { row in
                HStack(spacing: 12) {
                    ForEach(1..<4) { col in
                        let number = row * 3 + col
                        calculatorNumberButton(number: "\(number)")
                    }
                }
            }
            
            // 最后一行：0, 小数点, 等号, 删除
            HStack(spacing: 12) {
                calculatorNumberButton(number: "0")
                calculatorNumberButton(number: ".")
                calculateButton()
                deleteButton()
            }
        }
    }
    
    // 默认模式的数字按钮
    private func simpleNumberButton(number: String) -> some View {
        Button(action: {
            amount += number
        }) {
            Text(number)
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
    }
    
    // 计算器模式的数字按钮
    private func calculatorNumberButton(number: String) -> some View {
        Button(action: {
            expression += number
            // 实时计算（onChange 也会触发，但这里立即计算可以更快响应）
            calculateExpression()
        }) {
            Text(number)
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
    }
    
    private func operatorButton(_ op: String) -> some View {
        Button(action: {
            // 如果表达式为空或最后一个字符是运算符，不添加
            if expression.isEmpty || ["+", "-", "×", "÷"].contains(String(expression.last ?? Character(""))) {
                return
            }
            // 将 × 和 ÷ 转换为 * 和 / 用于计算
            let displayOp = op
            expression += displayOp
            // 添加运算符后不立即计算，因为表达式还不完整
            // 等用户输入下一个数字时再计算
        }) {
            Text(op)
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
    }
    
    private func calculateButton() -> some View {
        Button(action: {
            calculateExpression()
        }) {
            Text("=")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(selectedCategory.color)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
    }
    
    private func deleteButton() -> some View {
        Button(action: {
            if isCalculatorMode {
                if !expression.isEmpty {
                    expression.removeLast()
                    // onChange 会自动触发计算
                }
            } else {
                if !amount.isEmpty {
                    amount.removeLast()
                }
            }
        }) {
            Image(systemName: "delete.backward.fill")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    // MARK: - 辅助方法
    private func formatAmount(_ amount: String) -> String {
        guard let value = Double(amount) else { return "0.00" }
        return String(format: "%.2f", value / 100.0)
    }
    
    private func calculateExpression() {
        guard !expression.isEmpty else {
            calculatedAmount = 0.0
            return
        }
        
        // 如果表达式以运算符结尾，去掉最后一个运算符再计算（显示中间结果）
        var expressionToCalculate = expression
        if ["+", "-", "×", "÷"].contains(String(expressionToCalculate.last ?? Character(""))) {
            expressionToCalculate = String(expressionToCalculate.dropLast())
        }
        
        guard !expressionToCalculate.isEmpty else {
            calculatedAmount = 0.0
            return
        }
        
        // 将显示用的运算符转换为计算用的运算符
        let calculationExpression = expressionToCalculate
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
        
        // 使用 NSExpression 来计算表达式
        let nsExpression = NSExpression(format: calculationExpression)
        
        if let result = nsExpression.expressionValue(with: nil, context: nil) as? Double {
            calculatedAmount = result
        } else {
            // 如果计算失败，尝试直接解析为数字
            if let value = Double(calculationExpression) {
                calculatedAmount = value
            } else {
                // 如果表达式不完整（例如只有运算符），保持当前计算结果或设为0
                calculatedAmount = 0.0
            }
        }
    }
    
    // MARK: - AI智能输入
    private func analyzeWithAI(config: LLMConfig?) async {
        guard !aiInputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        isAIProcessing = true
        
        do {
            // 检查是否有可用配置
            let manager = LLMManager.shared
            let selectedConfig = config ?? manager.activeConfig
            
            guard let finalConfig = selectedConfig,
                  manager.getAPIKey(for: finalConfig) != nil else {
                // 如果没有配置，提示用户配置AI
                await MainActor.run {
                    isAIProcessing = false
                    print("⚠️ [QuickAddSheet] 未配置AI服务，请先在设置中配置")
                }
                return
            }
            
            // 调用AIService解析（传入配置）
            let result = try await AIService.shared.parseTransaction(
                text: aiInputText,
                categories: allCategories,
                accounts: accounts,
                config: finalConfig
            )
            
            // 自动填充表单
            await MainActor.run {
                // 填充金额
                if let amountValue = result.amount {
                    if isCalculatorMode {
                        // 计算器模式：设置表达式
                        expression = String(format: "%.2f", amountValue)
                        calculateExpression()
                    } else {
                        // 默认模式：转换为分（因为默认模式是按分输入的）
                        let amountInCents = Int(amountValue * 100)
                        amount = String(amountInCents)
                    }
                }
                
                // 填充描述
                if let note = result.note, !note.isEmpty {
                    title = note
                }
                
                // 选择分类（如果AI返回了分类）
                if let categoryName = result.categoryName,
                   let matchedCategory = allCategories.first(where: { $0.name == categoryName }) {
                    // 注意：这里我们不能直接改变 selectedCategory，因为它是 let 常量
                    // 但我们可以提示用户或记录日志
                    print("✅ [QuickAddSheet] AI建议分类: \(categoryName)")
                }
                
                // 选择账户
                if let accountName = result.accountName,
                   let matchedAccount = accounts.first(where: { $0.name == accountName }) {
                    selectedAccount = matchedAccount
                }
                
                // 处理日期（如果需要，可以添加日期选择器状态）
                if let dateString = result.date {
                    if let parsedDate = AIService.parseDate(dateString) {
                        print("✅ [QuickAddSheet] AI解析日期: \(dateString) -> \(parsedDate)")
                        // 注意：当前QuickAddSheet没有日期选择器，所以只记录日志
                    }
                }
                
                isAIProcessing = false
                showAISmartInput = false
                
                // 触觉反馈
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
            }
            
        } catch {
            await MainActor.run {
                isAIProcessing = false
                print("❌ [QuickAddSheet] AI解析失败: \(error.localizedDescription)")
                // 可以显示错误提示
            }
        }
    }
    
    private func saveExpense() {
        let finalAmount: Double
        
        if isCalculatorMode {
            // 计算器模式：使用计算结果
            guard calculatedAmount > 0 else {
                return
            }
            finalAmount = calculatedAmount
        } else {
            // 默认模式：使用直接输入的金额（按分计算）
            guard !amount.isEmpty,
                  let amountValue = Double(amount) else {
                return
            }
            finalAmount = amountValue / 100.0
        }
        
        // 如果描述为空，使用分类名称作为默认描述
        let finalTitle = title.isEmpty ? selectedCategory.name : title
        
        // 创建账单
        let expense = ExpenseItem(
            amount: finalAmount,
            title: finalTitle,
            date: Date(),
            category: selectedCategory.name,
            accountName: selectedAccount?.name
        )
        
        modelContext.insert(expense)
        
        // 增加分类的使用次数
        DataSeeder.incrementCategoryUsage(categoryName: selectedCategory.name, context: modelContext)
        
        // 如果选择了账户，更新账户余额（支出时减少余额）
        if let account = selectedAccount {
            // 根据分类类型判断是支出还是收入
            let isIncome = selectedCategory.categoryType == .income
            
            if isIncome {
                // 收入：增加账户余额
                account.balance += finalAmount
            } else {
                // 支出：减少账户余额
                account.balance -= finalAmount
            }
            
            print("💰 [QuickAddSheet] 更新账户余额: \(account.name) - \(isIncome ? "+" : "-")¥\(String(format: "%.2f", finalAmount))")
        }
        
        // 保存更改
        try? modelContext.save()
        
        // 记录关键操作并检查是否需要请求评价
        ReviewService.shared.logKeyAction()
        ReviewService.shared.requestReviewIfEligible(requestReview: requestReview)
        
        dismiss()
    }
    
    // MARK: - 完成按钮
    private var doneButton: some View {
        Button(action: {
            saveExpense()
        }) {
            HStack {
                Spacer()
                Text("完成")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.vertical, 16)
            .background(
                (isCalculatorMode ? calculatedAmount <= 0 : amount.isEmpty)
                    ? Color.gray.opacity(0.3)
                    : selectedCategory.color
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(isCalculatorMode ? calculatedAmount <= 0 : amount.isEmpty)
        .padding(.horizontal, 20)
    }
    
    // MARK: - 语音输入按钮
    private var voiceInputButton: some View {
        Button(action: {}) {
            Image(systemName: speechManager.isRecording ? "mic.fill" : "mic")
                .font(.title3)
                .foregroundColor(speechManager.isRecording ? .red : .blue)
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.1)
                .onChanged { _ in
                    startVoiceRecording()
                }
                .onEnded { _ in
                    stopVoiceRecording()
                }
        )
    }
    
    // MARK: - 录音覆盖层
    private var recordingOverlay: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // 波形动画
                HStack(spacing: 4) {
                    ForEach(0..<5) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.red)
                            .frame(width: 4, height: 20 + CGFloat(speechManager.audioLevel * 40))
                            .animation(
                                .easeInOut(duration: 0.3)
                                .repeatForever()
                                .delay(Double(index) * 0.1),
                                value: speechManager.audioLevel
                            )
                    }
                }
                .frame(height: 60)
                
                // 提示文字
                Text("正在录音...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("松开手指结束录音")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                
                // 实时转录文本（如果有）
                if !speechManager.transcript.isEmpty {
                    Text(speechManager.transcript)
                        .font(.body)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(12)
                        .padding(.horizontal, 40)
                }
            }
        }
    }
    
    // MARK: - 处理语音解析覆盖层
    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text("正在分析语音...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(40)
            .background(Color.black.opacity(0.6))
            .cornerRadius(20)
        }
    }
    
    // MARK: - 语音输入处理
    
    /// 请求语音权限
    private func requestSpeechPermissions() async {
        let granted = await speechManager.requestPermissions()
        if !granted {
            await MainActor.run {
                showPermissionAlert = true
            }
        }
    }
    
    /// 开始语音录音
    private func startVoiceRecording() {
        guard speechManager.hasAllPermissions else {
            Task {
                await requestSpeechPermissions()
            }
            return
        }
        
        do {
            try speechManager.startRecording()
            // 触觉反馈
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        } catch {
            print("❌ [QuickAddSheet] 开始录音失败: \(error.localizedDescription)")
            if let speechError = error as? SpeechError, speechError == .permissionDenied {
                showPermissionAlert = true
            }
        }
    }
    
    /// 停止语音录音
    private func stopVoiceRecording() {
        speechManager.stopRecording()
        
        // 触觉反馈
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    /// 处理语音输入
    private func processVoiceInput(_ text: String) {
        guard !text.isEmpty else { return }
        
        isProcessingVoice = true
        
        Task {
            do {
                // 获取分类名称列表
                let categoryNames = allCategories.map { $0.name }
                
                // 获取当前配置
                let config = LLMManager.shared.activeConfig
                
                // 解析语音输入
                let result = try await AIService.shared.parseVoiceInput(
                    text,
                    categories: categoryNames,
                    config: config
                )
                
                // 自动填充表单
                await MainActor.run {
                    // 填充金额
                    if let amountValue = result.amount {
                        if isCalculatorMode {
                            expression = String(format: "%.2f", amountValue)
                            calculateExpression()
                        } else {
                            let amountInCents = Int(amountValue * 100)
                            amount = String(amountInCents)
                        }
                    }
                    
                    // 填充描述
                    if let note = result.note, !note.isEmpty {
                        title = note
                    }
                    
                    // 选择账户（如果AI返回了账户）
                    if let accountName = result.account,
                       let matchedAccount = accounts.first(where: { $0.name == accountName }) {
                        selectedAccount = matchedAccount
                    }
                    
                    // 注意：分类和日期在当前实现中可能无法直接修改
                    // 因为 selectedCategory 是 let 常量
                    // 如果需要，可以显示提示或记录日志
                    if let categoryName = result.category {
                        print("✅ [QuickAddSheet] AI建议分类: \(categoryName)")
                    }
                    
                    if let dateString = result.date {
                        if let parsedDate = AIService.parseDate(dateString) {
                            print("✅ [QuickAddSheet] AI解析日期: \(dateString) -> \(parsedDate)")
                        }
                    }
                    
                    isProcessingVoice = false
                    
                    // 成功触觉反馈
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.success)
                }
                
            } catch {
                await MainActor.run {
                    isProcessingVoice = false
                    print("❌ [QuickAddSheet] 语音解析失败: \(error.localizedDescription)")
                    
                    // 错误触觉反馈
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.error)
                }
            }
        }
    }
}

// MARK: - 账户选择器 Sheet
struct AccountPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedAccount: Account?
    let accounts: [Account]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.98, green: 0.98, blue: 0.98)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 12) {
                        // 不选择账户选项
                        Button(action: {
                            selectedAccount = nil
                            dismiss()
                        }) {
                            accountRow(account: nil, isSelected: selectedAccount == nil)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // 账户列表
                        ForEach(accounts) { account in
                            Button(action: {
                                selectedAccount = account
                                dismiss()
                            }) {
                                accountRow(account: account, isSelected: selectedAccount?.id == account.id)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("选择支付方式")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func accountRow(account: Account?, isSelected: Bool) -> some View {
        HStack(spacing: 16) {
            if let account = account {
                // 账户图标
                ZStack {
                    Circle()
                        .fill(account.color)
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: account.iconName)
                        .foregroundColor(.white)
                        .font(.system(size: 24))
                }
                
                // 账户信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(account.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("余额: ¥\(account.balance, specifier: "%.2f")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 选中标记
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
            } else {
                // 不选择账户选项
                Image(systemName: "xmark.circle")
                    .foregroundColor(.gray)
                    .font(.title2)
                    .frame(width: 48, height: 48)
                
                Text("不选择支付方式")
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - AI智能输入Sheet
struct AISmartInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = LLMManager.shared
    @Binding var inputText: String
    @Binding var isProcessing: Bool
    var onAnalyze: (LLMConfig?) async -> Void
    
    @State private var selectedConfig: LLMConfig?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // 说明文字和配置选择
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 40))
                        .foregroundColor(.purple)
                    
                    Text("AI智能输入")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("描述你的支出，AI会自动识别金额、分类等信息")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // 配置选择器
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
                            HStack {
                                Image(systemName: "server.rack")
                                    .font(.caption)
                                Text(selectedConfig?.name ?? manager.activeConfig?.name ?? "选择配置")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.top, 20)
                .onAppear {
                    selectedConfig = manager.activeConfig
                }
                
                // 输入框
                VStack(alignment: .leading, spacing: 8) {
                    Text("描述")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("例如：昨天打车回家花了50元", text: $inputText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                        .disabled(isProcessing)
                }
                .padding(.horizontal)
                
                // 示例提示
                VStack(alignment: .leading, spacing: 4) {
                    Text("示例：")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        exampleButton("昨天打车回家花了50元")
                        exampleButton("午餐30块，用微信支付")
                        exampleButton("7天前买衣服200元")
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // 分析按钮
                Button(action: {
                    Task {
                        await onAnalyze(selectedConfig ?? manager.activeConfig)
                    }
                }) {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("分析中...")
                        } else {
                            Image(systemName: "sparkles")
                            Text("智能分析")
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isProcessing)
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("AI智能输入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func exampleButton(_ text: String) -> some View {
        Button(action: {
            inputText = text
        }) {
            HStack {
                Text(text)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "arrow.up.left")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: ExpenseItem.self, Category.self, Account.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = ModelContext(container)
    DataSeeder.ensureDefaults(context: context)
    
    let categories = try! context.fetch(FetchDescriptor<Category>())
    let sampleCategory = categories.first { $0.categoryType == .expense } ?? categories.first!
    
    return QuickAddSheet(selectedCategory: sampleCategory)
        .modelContainer(container)
}
