import SwiftUI
import SwiftData

struct HistoryExpensesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExpenseItem.date, order: .reverse) private var items: [ExpenseItem]
    @State private var isAddDialogPresented = false
    @State private var selectedMonth: Date = Date()

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
                    
                    // 月份选择器
                    monthSelector
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
    }
    
    // MARK: - 月份选择器
    private var monthSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(action: {
                    withAnimation {
                        selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .semibold))
                }
                
                Spacer()
                
                Text(monthYearString(selectedMonth))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
                        if nextMonth <= Date() {
                            selectedMonth = nextMonth
                        }
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .semibold))
                        .opacity(Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? Date() > Date() ? 0.5 : 1.0)
                }
                .disabled(Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? Date() > Date())
            }
            
            Text("¥\(monthTotal, specifier: "%.2f")")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
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
        let monthItems = items.filter { Calendar.current.isDate($0.date, equalTo: selectedMonth, toGranularity: .month) }
        let groupedExpenses = groupExpensesByDate(monthItems)
        let sortedDates = groupedExpenses.keys.sorted(by: >)
        
        if monthItems.isEmpty {
            return AnyView(
                VStack(spacing: 16) {
                    Image(systemName: "tray")
                        .font(.system(size: 64))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("暂无记录")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 100)
            )
        }
        
        return AnyView(
            VStack(spacing: 24) {
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
        )
    }
    
    // MARK: - 计算属性
    private var monthTotal: Double {
        let monthItems = items.filter { Calendar.current.isDate($0.date, equalTo: selectedMonth, toGranularity: .month) }
        return monthItems.reduce(0) { $0 + $1.amount }
    }
    
    // MARK: - 辅助方法
    private func monthYearString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月"
        return formatter.string(from: date)
    }
    
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
}

#Preview {
    HistoryExpensesView()
        .modelContainer(for: [ExpenseItem.self], inMemory: true)
}
