import SwiftUI
import SwiftData

struct CurrentExpensesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExpenseItem.date, order: .reverse) private var items: [ExpenseItem]
    @State private var isAddDialogPresented = false

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
                    
                    // Material Design 头部卡片
                    headerCard
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    
                    // 费用列表
                    expenseList
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100)
                }
            }
            
            // 浮动操作按钮 (FAB)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation {
                            isAddDialogPresented = true
                        }
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 64, height: 64)
                            .background(
                                LinearGradient(
                                    colors: [Color.indigo, Color.purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 100)
                }
            }
            
            // 添加费用对话框
            AddExpenseDialog(isPresented: $isAddDialogPresented)
        }
        .task {
            seedIfNeeded()
        }
    }
    
    // MARK: - 头部卡片
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Total Expenses")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.9))
            
            Text("¥\(totalSpent, specifier: "%.2f")")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.white)
            
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
                            .onTapGesture {
                                // 可以添加点击效果
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    deleteExpense(expense)
                                } label: {
                                    Label("Delete", systemImage: "trash")
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
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月"
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
        modelContext.delete(expense)
    }
    
    private func seedIfNeeded() {
        guard items.isEmpty else { return }
        
        let sampleExpenses = [
            ExpenseItem(amount: 84.5, title: "Grocery Shopping", date: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(), category: "Food"),
            ExpenseItem(amount: 15.99, title: "Netflix Subscription", date: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(), category: "Entertainment"),
            ExpenseItem(amount: 45.0, title: "Gas Station", date: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(), category: "Transport"),
            ExpenseItem(amount: 6.5, title: "Coffee Shop", date: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(), category: "Food"),
            ExpenseItem(amount: 23.75, title: "Pharmacy", date: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(), category: "Health")
        ]
        
        for expense in sampleExpenses {
            modelContext.insert(expense)
        }
    }
}

#Preview {
    CurrentExpensesView()
        .modelContainer(for: [ExpenseItem.self], inMemory: true)
}
