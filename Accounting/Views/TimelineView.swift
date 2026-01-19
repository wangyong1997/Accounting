import SwiftUI
import SwiftData

struct TimelineView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExpenseItem.date, order: .reverse) private var items: [ExpenseItem]
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query private var allCategories: [Category]
    @Binding var scrollToTopTrigger: Bool
    
    var body: some View {
        ZStack {
            // 背景色
            Color(red: 0.98, green: 0.98, blue: 0.98)
                .ignoresSafeArea()
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        // 顶部锚点
                        Color.clear
                            .frame(height: 1)
                            .id("top")
                        
                        // 头部卡片
                        headerCard
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 24)
                        
                        // 费用列表
                        expenseList
                            .padding(.horizontal, 16)
                            .padding(.bottom, 100)
                    }
                }
                .onChange(of: scrollToTopTrigger) {
                    withAnimation {
                        proxy.scrollTo("top", anchor: .top)
                    }
                }
            }
        }
    }
    
    // MARK: - 头部卡片
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 顶部：标题、日期和百分比变化
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.title3)
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("月度统计")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(currentMonthYear)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // 百分比变化（与上月对比）
                if let percentageChange = percentageChangeFromLastMonth {
                    HStack(spacing: 4) {
                        Image(systemName: percentageChange >= 0 ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis")
                            .font(.caption)
                            .foregroundColor(percentageChange >= 0 ? .green : .red)
                        
                        Text("\(percentageChange >= 0 ? "+" : "")\(String(format: "%.1f", percentageChange))%")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(percentageChange >= 0 ? .green : .red)
                    }
                }
            }
            
            // 本月结余
            VStack(alignment: .leading, spacing: 4) {
                Text("本月结余")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("¥\(netBalance, specifier: "%.2f")")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .padding(.vertical, 8)
            
            // 收入和支出卡片
            HStack(spacing: 16) {
                // 收入卡片
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title3)
                            .foregroundColor(.green)
                        
                        Text("收入")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    
                    Text("¥\(totalIncome, specifier: "%.2f")")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.green)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.green.opacity(0.1))
                )
                
                // 支出卡片
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "circle.fill")
                            .font(.title3)
                            .foregroundColor(.red)
                        
                        Text("支出")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    
                    Text("¥\(totalExpense, specifier: "%.2f")")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.red)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.red.opacity(0.1))
                )
            }
            
            // 收支比例
            if totalIncome > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("收支比例")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // 背景条
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 12)
                                
                                // 支出比例条
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.red, Color.red.opacity(0.7)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * expenseRatio, height: 12)
                            }
                        }
                        .frame(height: 12)
                        
                        Text("\(String(format: "%.1f", expenseRatio * 100))% 已支出")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 4)
        )
    }
    
    // MARK: - 费用列表
    private var expenseList: some View {
        let groupedExpenses = groupExpensesByDate(currentMonthItems)
        let sortedDates = groupedExpenses.keys.sorted(by: >)
        
        return VStack(spacing: 24) {
            ForEach(sortedDates, id: \.self) { dateKey in
                VStack(alignment: .leading, spacing: 12) {
                    // 日期标题
                    Text(formatDate(dateKey))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                    
                    // 费用卡片组
                    VStack(spacing: 0) {
                        ForEach(Array(groupedExpenses[dateKey]!.enumerated()), id: \.element.id) { index, expense in
                            ExpenseRowView(
                                expense: expense,
                                isLast: index == groupedExpenses[dateKey]!.count - 1,
                                onDelete: {
                                    deleteExpense(expense)
                                }
                            )
                            .contextMenu {
                                Button(role: .destructive) {
                                    deleteExpense(expense)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                }
            }
        }
    }
    
    // MARK: - 计算属性
    private var currentMonthItems: [ExpenseItem] {
        items.filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month) }
    }
    
    private var totalIncome: Double {
        currentMonthItems
            .filter { expense in
                let category = allCategories.first { $0.name == expense.category }
                return category?.categoryType == .income
            }
            .reduce(0) { $0 + $1.amount }
    }
    
    private var totalExpense: Double {
        currentMonthItems
            .filter { expense in
                let category = allCategories.first { $0.name == expense.category }
                return category?.categoryType == .expense
            }
            .reduce(0) { $0 + $1.amount }
    }
    
    private var currentMonthYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: Date())
    }
    
    // 本月净余额（收入 - 支出）
    private var netBalance: Double {
        totalIncome - totalExpense
    }
    
    // 支出比例（支出 / 收入）
    private var expenseRatio: Double {
        guard totalIncome > 0 else { return 0 }
        return min(totalExpense / totalIncome, 1.0)
    }
    
    // 与上月对比的百分比变化
    private var percentageChangeFromLastMonth: Double? {
        let calendar = Calendar.current
        let now = Date()
        
        // 获取上个月的同一天
        guard let lastMonth = calendar.date(byAdding: .month, value: -1, to: now) else {
            return nil
        }
        
        // 计算上月的收入和支出
        let lastMonthItems = items.filter { 
            calendar.isDate($0.date, equalTo: lastMonth, toGranularity: .month) 
        }
        
        let lastMonthIncome = lastMonthItems
            .filter { expense in
                let category = allCategories.first { $0.name == expense.category }
                return category?.categoryType == .income
            }
            .reduce(0) { $0 + $1.amount }
        
        let lastMonthExpense = lastMonthItems
            .filter { expense in
                let category = allCategories.first { $0.name == expense.category }
                return category?.categoryType == .expense
            }
            .reduce(0) { $0 + $1.amount }
        
        let lastMonthNet = lastMonthIncome - lastMonthExpense
        let currentMonthNet = netBalance
        
        // 如果上月净余额为0，无法计算百分比
        guard lastMonthNet != 0 else {
            return currentMonthNet != 0 ? 100 : nil
        }
        
        // 计算百分比变化
        let change = ((currentMonthNet - lastMonthNet) / abs(lastMonthNet)) * 100
        return change
    }
    
    // MARK: - 辅助方法
    private func groupExpensesByDate(_ expenses: [ExpenseItem]) -> [Date: [ExpenseItem]] {
        let calendar = Calendar.current
        var grouped: [Date: [ExpenseItem]] = [:]
        
        for expense in expenses {
            let dateKey = calendar.startOfDay(for: expense.date)
            if grouped[dateKey] == nil {
                grouped[dateKey] = []
            }
            grouped[dateKey]?.append(expense)
        }
        
        return grouped
    }
    
    private func deleteExpense(_ expense: ExpenseItem) {
        // 如果账单关联了账户，需要恢复账户余额
        if let accountName = expense.accountName,
           let account = accounts.first(where: { $0.name == accountName }) {
            // 查找分类以判断是收入还是支出
            let category = allCategories.first { $0.name == expense.category }
            let isIncome = category?.categoryType == .income
            
            // 恢复账户余额（反向操作）
            if isIncome {
                // 原为收入，删除时减少余额
                account.balance -= expense.amount
            } else {
                // 原为支出，删除时增加余额
                account.balance += expense.amount
            }
            
            print("🔄 [TimelineView] 删除账单，恢复账户余额: \(account.name) - \(isIncome ? "-" : "+")¥\(String(format: "%.2f", expense.amount))")
        }
        
        modelContext.delete(expense)
        try? modelContext.save()
    }
}

#Preview {
    TimelineView(scrollToTopTrigger: .constant(false))
        .modelContainer(for: [ExpenseItem.self], inMemory: true)
}
