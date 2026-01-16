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
            
            // 总支出卡片
            VStack(alignment: .leading, spacing: 8) {
                Text("总支出")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.9))
                
                Text("¥\(totalExpense, specifier: "%.2f")")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                
                Text("共 \(filteredItems.count) 笔")
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
            
            // 平均支出卡片
            HStack(spacing: 16) {
                statCard(
                    title: "平均支出",
                    value: String(format: "¥%.2f", averageExpense),
                    icon: "chart.bar.fill",
                    color: .blue
                )
                
                statCard(
                    title: "最大支出",
                    value: String(format: "¥%.2f", maxExpense),
                    icon: "arrow.up.circle.fill",
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
            
            let categoryData = getCategoryStatistics()
            
            if categoryData.isEmpty {
                Text("暂无数据")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                VStack(spacing: 12) {
                    ForEach(categoryData, id: \.category) { data in
                        categoryRow(data: data, total: totalExpense)
                    }
                }
                .padding(16)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            }
        }
    }
    
    private func categoryRow(data: CategoryData, total: Double) -> some View {
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
            Text("支出趋势")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            let chartData = getChartData()
            
            if chartData.isEmpty {
                Text("暂无数据")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                VStack(spacing: 16) {
                    Chart(chartData, id: \.date) { item in
                        LineMark(
                            x: .value("日期", item.date, unit: .day),
                            y: .value("金额", item.amount)
                        )
                        .foregroundStyle(Color.indigo)
                        .interpolationMethod(.catmullRom)
                        
                        AreaMark(
                            x: .value("日期", item.date, unit: .day),
                            y: .value("金额", item.amount)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.indigo.opacity(0.3), Color.indigo.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                    .frame(height: 200)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: selectedPeriod == .week ? 1 : selectedPeriod == .month ? 5 : 30)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.month().day())
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
    
    private var totalExpense: Double {
        filteredItems.reduce(0) { $0 + $1.amount }
    }
    
    private var averageExpense: Double {
        let count = filteredItems.count
        return count > 0 ? totalExpense / Double(count) : 0
    }
    
    private var maxExpense: Double {
        filteredItems.map { $0.amount }.max() ?? 0
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
    private func getCategoryStatistics() -> [CategoryData] {
        let grouped = Dictionary(grouping: filteredItems) { $0.category }
        return grouped.map { category, items in
            CategoryData(
                category: category,
                amount: items.reduce(0) { $0 + $1.amount }
            )
        }
        .sorted { $0.amount > $1.amount }
    }
    
    private func getChartData() -> [ChartDataPoint] {
        let calendar = Calendar.current
        let now = Date()
        var startDate: Date
        
        switch selectedPeriod {
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
            startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        case .year:
            startDate = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
        }
        
        let dateRange = calendar.dateInterval(of: selectedPeriod == .week ? .day : selectedPeriod == .month ? .day : .month, for: startDate) ?? DateInterval(start: startDate, end: now)
        
        var data: [ChartDataPoint] = []
        var currentDate = dateRange.start
        
        while currentDate <= dateRange.end {
            let dayItems = filteredItems.filter { calendar.isDate($0.date, inSameDayAs: currentDate) }
            let dayTotal = dayItems.reduce(0) { $0 + $1.amount }
            data.append(ChartDataPoint(date: currentDate, amount: dayTotal))
            
            if let nextDate = calendar.date(byAdding: selectedPeriod == .week ? .day : selectedPeriod == .month ? .day : .month, value: 1, to: currentDate) {
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
