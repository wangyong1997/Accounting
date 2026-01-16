import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query(sort: \ExpenseItem.date, order: .reverse) private var expenses: [ExpenseItem]
    
    @State private var showCategoryManagement = false
    @State private var showMockDataSheet = false
    @AppStorage("mockDataEnabled") private var mockDataEnabled = false
    
    var body: some View {
        ZStack {
            // 背景色
            Color(red: 0.98, green: 0.98, blue: 0.98)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // 顶部间距
                    Spacer()
                        .frame(height: 64)
                    
                    // 设置列表
                    settingsList
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100)
                }
            }
        }
        .sheet(isPresented: $showCategoryManagement) {
            CategoryManagementView()
        }
        .sheet(isPresented: $showMockDataSheet) {
            MockDataSheet(
                mockDataEnabled: $mockDataEnabled,
                onGenerate: generateMockData,
                onClear: clearMockData
            )
        }
        .onAppear {
            // 检查是否有模拟数据标记
            checkMockDataStatus()
        }
    }
    
    // MARK: - 模拟数据功能
    private func generateMockData() {
        guard !categories.isEmpty, !accounts.isEmpty else {
            print("⚠️ [SettingsView] 无法生成模拟数据：缺少分类或账户")
            return
        }
        
        // 清除现有模拟数据
        clearMockData()
        
        let calendar = Calendar.current
        let now = Date()
        
        // 获取支出和收入分类
        let expenseCategories = categories.filter { $0.categoryType == .expense }
        let incomeCategories = categories.filter { $0.categoryType == .income }
        
        // 生成过去30天的模拟数据
        var mockExpenses: [ExpenseItem] = []
        
        for dayOffset in 0..<30 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            
            // 每天生成1-5笔支出
            let expenseCount = Int.random(in: 1...5)
            for _ in 0..<expenseCount {
                if let randomCategory = expenseCategories.randomElement(),
                   let randomAccount = accounts.randomElement() {
                    let amount = Double.random(in: 5.0...500.0)
                    let titles = [
                        "早餐", "午餐", "晚餐", "咖啡", "零食", "购物", "交通", "娱乐",
                        "电影", "游戏", "书籍", "衣服", "日用品", "药品", "其他"
                    ]
                    
                    let expense = ExpenseItem(
                        amount: (amount * 100).rounded() / 100, // 保留两位小数
                        title: titles.randomElement() ?? "支出",
                        date: calendar.date(byAdding: .hour, value: Int.random(in: 8...22), to: date) ?? date,
                        category: randomCategory.name,
                        accountName: randomAccount.name
                    )
                    
                    mockExpenses.append(expense)
                    modelContext.insert(expense)
                    
                    // 更新账户余额
                    randomAccount.balance -= expense.amount
                }
            }
            
            // 偶尔生成收入（每3-5天一次）
            if dayOffset % Int.random(in: 3...5) == 0,
               let randomCategory = incomeCategories.randomElement(),
               let randomAccount = accounts.randomElement() {
                let amount = Double.random(in: 100.0...5000.0)
                let titles = ["工资", "奖金", "兼职", "投资收益", "其他收入"]
                
                let income = ExpenseItem(
                    amount: (amount * 100).rounded() / 100,
                    title: titles.randomElement() ?? "收入",
                    date: calendar.date(byAdding: .hour, value: Int.random(in: 9...18), to: date) ?? date,
                    category: randomCategory.name,
                    accountName: randomAccount.name
                )
                
                mockExpenses.append(income)
                modelContext.insert(income)
                
                // 更新账户余额
                randomAccount.balance += income.amount
            }
        }
        
        // 保存
        try? modelContext.save()
        print("✅ [SettingsView] 已生成 \(mockExpenses.count) 条模拟数据")
    }
    
    private func clearMockData() {
        // 查找所有标记为模拟数据的账单（通过标题或日期范围判断）
        // 这里我们清除所有数据，或者可以通过添加标记字段来区分
        // 为了安全，我们只清除最近30天的数据
        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        
        let recentExpenses = expenses.filter { $0.date >= thirtyDaysAgo }
        
        // 恢复账户余额
        for expense in recentExpenses {
            if let accountName = expense.accountName,
               let account = accounts.first(where: { $0.name == accountName }) {
                let category = categories.first { $0.name == expense.category }
                let isIncome = category?.categoryType == .income
                
                // 反向操作恢复余额
                if isIncome {
                    account.balance -= expense.amount
                } else {
                    account.balance += expense.amount
                }
            }
        }
        
        // 删除账单
        for expense in recentExpenses {
            modelContext.delete(expense)
        }
        
        try? modelContext.save()
        print("🗑️ [SettingsView] 已清除模拟数据")
    }
    
    private func checkMockDataStatus() {
        // 检查是否有模拟数据（通过数据量判断）
        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recentExpenses = expenses.filter { $0.date >= thirtyDaysAgo }
        
        // 如果最近30天有超过50条数据，可能是模拟数据
        if recentExpenses.count > 50 {
            mockDataEnabled = true
        }
    }
    
    // MARK: - 设置列表
    private var settingsList: some View {
        VStack(spacing: 16) {
            // 账户设置
            settingsSection(title: "账户设置") {
                settingsRow(icon: "person.fill", iconColor: .blue, title: "个人资料")
                settingsRow(icon: "bell.fill", iconColor: .orange, title: "通知设置")
                settingsRow(icon: "lock.fill", iconColor: .red, title: "隐私与安全")
            }
            
            // 应用设置
            settingsSection(title: "应用设置") {
                Button(action: {
                    showCategoryManagement = true
                }) {
                    settingsRow(icon: "tag.fill", iconColor: .blue, title: "分类管理")
                }
                .buttonStyle(PlainButtonStyle())
                
                settingsRow(icon: "paintbrush.fill", iconColor: .purple, title: "主题设置")
                settingsRow(icon: "chart.bar.fill", iconColor: .green, title: "数据导出")
                settingsRow(icon: "arrow.clockwise", iconColor: .blue, title: "备份与恢复")
            }
            
            // 开发工具
            settingsSection(title: "开发工具") {
                Button(action: {
                    showMockDataSheet = true
                }) {
                    HStack(spacing: 16) {
                        Image(systemName: "testtube.2")
                            .foregroundColor(.orange)
                            .font(.system(size: 20))
                            .frame(width: 32)
                        
                        Text("模拟数据")
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Toggle("", isOn: $mockDataEnabled)
                            .labelsHidden()
                            .onChange(of: mockDataEnabled) { oldValue, newValue in
                                if newValue {
                                    generateMockData()
                                } else {
                                    clearMockData()
                                }
                            }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .overlay(
                        Divider()
                            .padding(.leading, 68),
                        alignment: .bottom
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // 关于
            settingsSection(title: "关于") {
                settingsRow(icon: "info.circle.fill", iconColor: .gray, title: "关于 PixelLedger")
                settingsRow(icon: "star.fill", iconColor: .yellow, title: "评价应用")
                settingsRow(icon: "questionmark.circle.fill", iconColor: .blue, title: "帮助与反馈")
            }
        }
    }
    
    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                content()
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
    }
    
    private func settingsRow(icon: String, iconColor: Color, title: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .font(.system(size: 20))
                .frame(width: 32)
            
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .font(.system(size: 14))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.white)
        .overlay(
            Divider()
                .padding(.leading, 68),
            alignment: .bottom
        )
    }
}

// MARK: - 模拟数据设置 Sheet
struct MockDataSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var mockDataEnabled: Bool
    let onGenerate: () -> Void
    let onClear: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("启用模拟数据", isOn: $mockDataEnabled)
                        .onChange(of: mockDataEnabled) { oldValue, newValue in
                            if newValue {
                                onGenerate()
                            } else {
                                onClear()
                            }
                        }
                } header: {
                    Text("模拟数据")
                } footer: {
                    Text("开启后将生成过去30天的模拟账单数据，用于测试应用功能。关闭时会清除这些数据。")
                }
                
                Section {
                    Button(action: {
                        onGenerate()
                    }) {
                        HStack {
                            Text("重新生成数据")
                            Spacer()
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    
                    Button(role: .destructive, action: {
                        mockDataEnabled = false
                        onClear()
                    }) {
                        HStack {
                            Text("清除所有模拟数据")
                            Spacer()
                            Image(systemName: "trash")
                        }
                    }
                } header: {
                    Text("操作")
                }
            }
            .navigationTitle("模拟数据")
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
}

#Preview {
    SettingsView()
        .modelContainer(for: [ExpenseItem.self, Category.self, Account.self], inMemory: true)
}
