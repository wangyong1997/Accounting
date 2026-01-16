import SwiftUI
import SwiftData
import Foundation

struct QuickAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let selectedCategory: Category
    
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    
    @State private var isCalculatorMode: Bool = false // 是否为计算器模式
    @State private var amount: String = "" // 直接输入金额（默认模式）
    @State private var expression: String = "" // 用户输入的表达式（计算器模式）
    @State private var calculatedAmount: Double = 0.0 // 计算结果
    @State private var title: String = ""
    @State private var selectedAccount: Account? = nil // 选择的支付账户
    @State private var showAccountPicker = false // 是否显示账户选择器
    
    var body: some View {
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
                        .padding(.top, 16)
                        
                        // 表达式和金额显示
                        amountDisplay
                            .padding(.bottom, 16)
                    }
                    
                    Spacer(minLength: 0)
                    
                    // 底部固定区域：数字键盘和完成按钮
                    VStack(spacing: 0) {
                        Divider()
                            .opacity(0.2)
                        
                        numberPad
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
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
            .navigationBarHidden(true)
            .sheet(isPresented: $showAccountPicker) {
                AccountPickerSheet(selectedAccount: $selectedAccount, accounts: accounts)
            }
            .onChange(of: expression) { oldValue, newValue in
                // 实时计算表达式结果
                if isCalculatorMode {
                    calculateExpression()
                }
            }
        }
    }
    
    // MARK: - 金额显示
    private var amountDisplay: some View {
        VStack(spacing: 16) {
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
                }
                
                // 结果金额显示
                Text(calculatedAmount == 0.0 ? "¥0.00" : "¥\(String(format: "%.2f", calculatedAmount))")
                    .font(.system(size: 48, weight: .bold))
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
        .padding(.vertical, 24)
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

#Preview {
    let container = try! ModelContainer(for: ExpenseItem.self, Category.self, Account.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = ModelContext(container)
    DataSeeder.ensureDefaults(context: context)
    
    let categories = try! context.fetch(FetchDescriptor<Category>())
    let sampleCategory = categories.first { $0.categoryType == .expense } ?? categories.first!
    
    return QuickAddSheet(selectedCategory: sampleCategory)
        .modelContainer(container)
}
