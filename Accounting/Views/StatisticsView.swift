import SwiftUI
import SwiftData
import Charts

struct StatisticsView: View {
    @Query(sort: \ExpenseItem.date, order: .reverse) private var items: [ExpenseItem]
    @Query(sort: \Category.name) private var allCategories: [Category]
    @State private var selectedPeriod: TimePeriod = .month

    enum TimePeriod: String, CaseIterable {
        case week = "本周"
        case month = "本月"
        case year = "本年"
    }

    var body: some View {
        ZStack {
            // 背景色
            Color(red: 0.98, green: 0.98, blue: 0.98)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // 顶部间距
                    Spacer()
                        .frame(height: 64)
                    
                    // 统计卡片
                    statisticsCards
                        .padding(.horizontal, 16)
                    
                    // 分类统计
                    categoryStatistics
                        .padding(.horizontal, 16)
                    
                    // 趋势图表
                    trendChart
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100)
                }
            }
        }
    }
    
    // MARK: - 统计卡片
    private var statisticsCards: some View {
        VStack(spacing: 16) {
            // 时间段选择器
            Picker("时间段", selection: $selectedPeriod) {
                ForEach(TimePeriod.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
            
            // 收入和支出卡片
            HStack(spacing: 16) {
                // 总收入卡片
                VStack(alignment: .leading, spacing: 8) {
                    Text("总收入")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.9))
                    
                    Text("¥\(totalIncome, specifier: "%.2f")")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("\(incomeItems.count) 笔")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(
                    LinearGradient(
                        colors: [Color.green, Color.mint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                
                // 总支出卡片
                VStack(alignment: .leading, spacing: 8) {
                    Text("总支出")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.9))
                    
                    Text("¥\(totalExpense, specifier: "%.2f")")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("\(expenseItems.count) 笔")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(
                    LinearGradient(
                        colors: [Color.red, Color.pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            }
            
            // 净收入卡片
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("净收入")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.9))
                    
                    Spacer()
                    
                    Image(systemName: netIncome >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .foregroundColor(.white.opacity(0.9))
                        .font(.title3)
                }
                
                Text("¥\(netIncome, specifier: "%.2f")")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                Text("收入 - 支出")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .background(
                LinearGradient(
                    colors: netIncome >= 0 ? [Color.blue, Color.indigo] : [Color.orange, Color.red],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 4)
            
            // 平均和最大金额卡片
            HStack(spacing: 16) {
                statCard(
                    title: "平均收入",
                    value: String(format: "¥%.2f", averageIncome),
                    icon: "chart.bar.fill",
                    color: .green
                )
                
                statCard(
                    title: "平均支出",
                    value: String(format: "¥%.2f", averageExpense),
                    icon: "chart.bar.fill",
                    color: .red
                )
            }
        }
    }
    
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title2)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - 分类统计
    private var categoryStatistics: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("分类统计")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            let incomeCategoryData = getCategoryStatistics(for: .income)
            let expenseCategoryData = getCategoryStatistics(for: .expense)
            
            if incomeCategoryData.isEmpty && expenseCategoryData.isEmpty {
                Text("暂无数据")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                VStack(spacing: 20) {
                    // 收入分类
                    if !incomeCategoryData.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundColor(.green)
                                Text("收入分类")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            
                            ForEach(incomeCategoryData, id: \.category) { data in
                                categoryRow(data: data, total: totalIncome, isIncome: true)
                            }
                        }
                    }
                    
                    // 支出分类
                    if !expenseCategoryData.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "arrow.up.circle.fill")
                                    .foregroundColor(.red)
                                Text("支出分类")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            
                            ForEach(expenseCategoryData, id: \.category) { data in
                                categoryRow(data: data, total: totalExpense, isIncome: false)
                            }
                        }
                    }
                }
                .padding(16)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            }
        }
    }
    
    private func categoryRow(data: CategoryData, total: Double, isIncome: Bool) -> some View {
        // 从 SwiftData 中查找对应的分类
        let category = allCategories.first { $0.name == data.category }
        let iconName = category?.symbolName ?? "tag.fill"
        let categoryColor = category?.color ?? Color.gray
        let percentage = total > 0 ? (data.amount / total) * 100 : 0
        
        return VStack(spacing: 8) {
            HStack {
                // 分类图标
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(categoryColor)
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: iconName)
                        .foregroundColor(.white)
                        .font(.system(size: 16))
                }
                
                Text(data.category)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("¥\(data.amount, specifier: "%.2f")")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("\(percentage, specifier: "%.1f")%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(categoryColor)
                        .frame(width: geometry.size.width * CGFloat(percentage / 100), height: 8)
                }
            }
            .frame(height: 8)
        }
    }
    
    // MARK: - 趋势图表
    private var trendChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("收支趋势")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            let incomeChartData = getChartData(for: .income)
            let expenseChartData = getChartData(for: .expense)
            
            if incomeChartData.isEmpty && expenseChartData.isEmpty {
                Text("暂无数据")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                VStack(spacing: 16) {
                    Chart {
                        // 收入曲线
                        if !incomeChartData.isEmpty {
                            ForEach(incomeChartData, id: \.date) { item in
                                LineMark(
                                    x: .value("日期", item.date, unit: .day),
                                    y: .value("金额", item.amount)
                                )
                                .foregroundStyle(Color.green)
                                .interpolationMethod(.catmullRom)
                                .symbol(Circle().strokeBorder(lineWidth: 2))
                            }
                            
                            ForEach(incomeChartData, id: \.date) { item in
                                AreaMark(
                                    x: .value("日期", item.date, unit: .day),
                                    y: .value("金额", item.amount)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.green.opacity(0.2), Color.green.opacity(0.0)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .interpolationMethod(.catmullRom)
                            }
                        }
                        
                        // 支出曲线
                        if !expenseChartData.isEmpty {
                            ForEach(expenseChartData, id: \.date) { item in
                                LineMark(
                                    x: .value("日期", item.date, unit: .day),
                                    y: .value("金额", item.amount)
                                )
                                .foregroundStyle(Color.red)
                                .interpolationMethod(.catmullRom)
                                .symbol(Circle().strokeBorder(lineWidth: 2))
                            }
                            
                            ForEach(expenseChartData, id: \.date) { item in
                                AreaMark(
                                    x: .value("日期", item.date, unit: .day),
                                    y: .value("金额", item.amount)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.red.opacity(0.2), Color.red.opacity(0.0)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .interpolationMethod(.catmullRom)
                            }
                        }
                    }
                    .frame(height: 200)
                    .chartXAxis {
                        // 使用 stride 自动计算间隔，或者根据 selectedPeriod 手动指定
                        // 注意：年度视图只有12个点，月视图30个点，周视图7个点
                        let strideCount: Int = selectedPeriod == .week ? 1 : (selectedPeriod == .month ? 5 : 1)
                        let strideUnit: Calendar.Component = selectedPeriod == .year ? .month : .day
                        
                        AxisMarks(values: .stride(by: strideUnit, count: strideCount)) { value in
                            AxisGridLine()
                            if let date = value.as(Date.self) {
                                AxisValueLabel {
                                    // ❌ 删除原来的 DateFormatter 代码
                                    // ✅ 使用 Text 的 format 参数 (iOS 15+) 或者上面的 helper
                                    if selectedPeriod == .year {
                                        Text(date, format: .dateTime.month(.defaultDigits)) // 显示 "1月", "2月"
                                    } else {
                                        Text(date, format: .dateTime.month(.defaultDigits).day()) // 显示 "1/15"
                                    }
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let doubleValue = value.as(Double.self) {
                                    Text("¥\(Int(doubleValue))")
                                }
                            }
                        }
                    }
                    
                    // 图例
                    HStack(spacing: 24) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 12, height: 12)
                            Text("收入")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 12, height: 12)
                            Text("支出")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(16)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            }
        }
    }
    
    // MARK: - 计算属性
    private var filteredItems: [ExpenseItem] {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedPeriod {
        case .week:
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return items.filter { $0.date >= weekAgo }
        case .month:
            return items.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
        case .year:
            return items.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .year) }
        }
    }
    
    // 收入项目
    private var incomeItems: [ExpenseItem] {
        filteredItems.filter { item in
            if let category = allCategories.first(where: { $0.name == item.category }) {
                return category.categoryType == .income
            }
            return false
        }
    }
    
    // 支出项目
    private var expenseItems: [ExpenseItem] {
        filteredItems.filter { item in
            if let category = allCategories.first(where: { $0.name == item.category }) {
                return category.categoryType == .expense
            }
            return true // 默认当作支出
        }
    }
    
    // 总收入
    private var totalIncome: Double {
        incomeItems.reduce(0) { $0 + $1.amount }
    }
    
    // 总支出
    private var totalExpense: Double {
        expenseItems.reduce(0) { $0 + $1.amount }
    }
    
    // 净收入（收入 - 支出）
    private var netIncome: Double {
        totalIncome - totalExpense
    }
    
    // 平均收入
    private var averageIncome: Double {
        let count = incomeItems.count
        return count > 0 ? totalIncome / Double(count) : 0
    }
    
    // 平均支出
    private var averageExpense: Double {
        let count = expenseItems.count
        return count > 0 ? totalExpense / Double(count) : 0
    }
    
    private var maxExpense: Double {
        expenseItems.map { $0.amount }.max() ?? 0
    }
    
    // MARK: - 数据结构
    struct CategoryData {
        let category: String
        let amount: Double
    }
    
    struct ChartDataPoint {
        let date: Date
        let amount: Double
    }
    
    // MARK: - 辅助方法
    private func getCategoryStatistics(for type: CategoryType) -> [CategoryData] {
        let items = type == .income ? incomeItems : expenseItems
        let grouped = Dictionary(grouping: items) { $0.category }
        return grouped.map { category, items in
            CategoryData(
                category: category,
                amount: items.reduce(0) { $0 + $1.amount }
            )
        }
        .sorted { $0.amount > $1.amount }
    }
    
    private func getChartData(for type: CategoryType) -> [ChartDataPoint] {
        let calendar = Calendar.current
        let now = Date()
        var startDate: Date
        
        // 1. 确定图表的开始时间和结束时间
        // 建议统一逻辑：本周(自然周)，本月(自然月)，本年(自然年)
        switch selectedPeriod {
        case .week:
            // 获取本周一
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            startDate = calendar.date(from: components) ?? now
        case .month:
            // 获取本月1号
            let components = calendar.dateComponents([.year, .month], from: now)
            startDate = calendar.date(from: components) ?? now
        case .year:
            // 获取本年1月1号
            let components = calendar.dateComponents([.year], from: now)
            startDate = calendar.date(from: components) ?? now
        }
        
        let items = type == .income ? incomeItems : expenseItems
        var data: [ChartDataPoint] = []
        var currentDate = startDate
        
        // 结束时间设为今天，或者该周期的最后一天
        let endBound = now 
        
        while currentDate <= endBound {
            let periodTotal: Double
            
            // 2. 根据粒度过滤数据
            if selectedPeriod == .year {
                // 年度视图：按"月"统计
                // 修复点：这里使用 granularity: .month，而不是 inSameDayAs
                let monthItems = items.filter { 
                    calendar.isDate($0.date, equalTo: currentDate, toGranularity: .month) 
                }
                periodTotal = monthItems.reduce(0) { $0 + $1.amount }
            } else {
                // 周/月视图：按"天"统计
                let dayItems = items.filter { 
                    calendar.isDate($0.date, inSameDayAs: currentDate) 
                }
                periodTotal = dayItems.reduce(0) { $0 + $1.amount }
            }
            
            // 只有当金额大于0，或者你想显示0值的点时添加
            // 建议：图表如果是连续线条，最好保留0值的点，否则线条会断开或直接连线跨越
            data.append(ChartDataPoint(date: currentDate, amount: periodTotal))
            
            // 3. 步进时间
            let component: Calendar.Component = (selectedPeriod == .year) ? .month : .day
            if let nextDate = calendar.date(byAdding: component, value: 1, to: currentDate) {
                currentDate = nextDate
            } else {
                break
            }
        }
        
        return data
    }
}

#Preview {
    StatisticsView()
        .modelContainer(for: [ExpenseItem.self], inMemory: true)
}
