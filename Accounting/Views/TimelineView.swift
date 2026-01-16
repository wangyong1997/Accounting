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
                        
                        // 顶部间距
                        Spacer()
                            .frame(height: 64)
                        
                        // 头部卡片
                        headerCard
                            .padding(.horizontal, 16)
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
        VStack(alignment: .leading, spacing: 8) {
            Text("月度收支")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.9))
            
            Text("¥\(totalSpent, specifier: "%.2f")")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .fixedSize(horizontal: false, vertical: true)
            
            Text(currentMonthYear)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(
            LinearGradient(
                colors: [Color.indigo, Color.purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 4)
    }
    
    // MARK: - 费用列表
    private var expenseList: some View {
        let currentMonthItems = items.filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month) }
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
    private var totalSpent: Double {
        let currentMonthItems = items.filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month) }
        return currentMonthItems.reduce(0) { $0 + $1.amount }
    }
    
    private var currentMonthYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月"
        return formatter.string(from: Date())
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
