import SwiftUI
import SwiftData
import Charts

struct AnalysisView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExpenseItem.date, order: .reverse) private var items: [ExpenseItem]
    @Query(sort: \Category.name) private var allCategories: [Category]
    
    @State private var viewModel = AnalysisViewModel()
    @State private var selectedPeriod: PeriodType = .month
    @State private var selectedDate: Date = Date()

    enum PeriodType: String, CaseIterable {
        case month = "月"
        case year = "年"
    }

    var body: some View {
        ZStack {
            // 背景色
            Color(red: 0.98, green: 0.98, blue: 0.98)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Header: 时间段选择和日期选择
                    headerSection
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    
                    // 汇总卡片
                    summaryCard
                        .padding(.horizontal, 16)
                    
                    // 每日趋势柱状图
                    dailyTrendChart
                        .padding(.horizontal, 16)
                    
                    // 分类占比环形图
                    categoryDonutChart
                        .padding(.horizontal, 16)
                    
                    // 排名列表
                    rankingList
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100)
                }
            }
        }
        .onAppear {
            updateData()
        }
        .onChange(of: selectedPeriod) {
            updateData()
        }
        .onChange(of: selectedDate) {
            updateData()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // 时间段选择器
            Picker("时间段", selection: $selectedPeriod) {
                ForEach(PeriodType.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
            
            // 日期选择器
            if selectedPeriod == .month {
                monthPicker
            } else {
                yearPicker
            }
        }
    }
    
    private var monthPicker: some View {
        HStack {
            Button(action: {
                changeMonth(-1)
            }) {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            Text(monthYearString)
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button(action: {
                changeMonth(1)
            }) {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .foregroundColor(canGoToNextMonth ? .blue : .gray)
            }
            .disabled(!canGoToNextMonth)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var yearPicker: some View {
        HStack {
            Button(action: {
                changeYear(-1)
            }) {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            Text(yearString)
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button(action: {
                changeYear(1)
            }) {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .foregroundColor(canGoToNextYear ? .blue : .gray)
            }
            .disabled(!canGoToNextYear)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: selectedDate)
    }
    
    private var yearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: selectedDate)
    }
    
    // MARK: - 判断是否可以翻页
    private var canGoToNextMonth: Bool {
        let calendar = Calendar.current
        let today = Date()
        let currentMonth = calendar.component(.month, from: today)
        let currentYear = calendar.component(.year, from: today)
        
        let selectedMonth = calendar.component(.month, from: selectedDate)
        let selectedYear = calendar.component(.year, from: selectedDate)
        
        // 如果选择的月份是当前月份或之前的月份，可以前进
        if selectedYear < currentYear {
            return true
        } else if selectedYear == currentYear {
            return selectedMonth < currentMonth
        } else {
            return false
        }
    }
    
    private var canGoToNextYear: Bool {
        let calendar = Calendar.current
        let today = Date()
        let currentYear = calendar.component(.year, from: today)
        let selectedYear = calendar.component(.year, from: selectedDate)
        
        // 如果选择的年份是当前年份或之前的年份，可以前进
        return selectedYear < currentYear
    }
    
    private func changeMonth(_ delta: Int) {
        let calendar = Calendar.current
        guard let newDate = calendar.date(byAdding: .month, value: delta, to: selectedDate) else {
            return
        }
        
        // 检查新日期是否是未来月份
        let today = Date()
        if calendar.compare(newDate, to: today, toGranularity: .month) == .orderedDescending {
            // 如果是未来月份，不允许切换
            return
        }
        
        selectedDate = newDate
    }
    
    private func changeYear(_ delta: Int) {
        let calendar = Calendar.current
        guard let newDate = calendar.date(byAdding: .year, value: delta, to: selectedDate) else {
            return
        }
        
        // 检查新日期是否是未来年份
        let today = Date()
        if calendar.compare(newDate, to: today, toGranularity: .year) == .orderedDescending {
            // 如果是未来年份，不允许切换
            return
        }
        
        selectedDate = newDate
    }
    
    // MARK: - Summary Card
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 总支出（大号显示）
            VStack(alignment: .leading, spacing: 4) {
                Text("总支出")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("¥\(viewModel.totalExpense, specifier: "%.2f")")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            Divider()
            
            // 总收入和日均支出
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("总收入")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("¥\(viewModel.totalIncome, specifier: "%.2f")")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
            }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("日均支出")
                .font(.caption)
                .foregroundColor(.secondary)
            
                    Text("¥\(viewModel.averageDailySpend, specifier: "%.2f")")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 4)
    }
    
    // MARK: - Daily Trend Chart
    private var dailyTrendChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("每日趋势")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            if viewModel.dailyData.isEmpty {
                emptyStateView(message: "暂无数据")
            } else {
                Chart {
                    // 柱状图
                    ForEach(viewModel.dailyData, id: \.day) { data in
                        BarMark(
                            x: .value("日期", data.day),
                            y: .value("金额", data.amount)
                        )
                        .foregroundStyle(data.amount >= viewModel.averageDailySpend ? Color.red : Color.blue)
                        .cornerRadius(4)
                    }
                    
                    // 平均线
                    RuleMark(y: .value("平均值", viewModel.averageDailySpend))
                        .foregroundStyle(Color.gray)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("平均: ¥\(viewModel.averageDailySpend, specifier: "%.2f")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(4)
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: selectedPeriod == .month ? 5 : 1)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let intValue = value.as(Int.self) {
                                Text(selectedPeriod == .month ? "\(intValue)日" : "\(intValue)月")
                                    .font(.caption)
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
                                    .font(.caption)
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
    
    // MARK: - Category Donut Chart
    private var categoryDonutChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("分类占比")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            if viewModel.categoryData.isEmpty {
                emptyStateView(message: "暂无数据")
            } else {
                HStack(spacing: 24) {
                    // 环形图
                    Chart {
                        ForEach(viewModel.categoryData, id: \.category.id) { data in
                            SectorMark(
                                angle: .value("金额", data.amount),
                                innerRadius: .ratio(0.6),
                                angularInset: 2
                        )
                            .foregroundStyle(data.category.color)
                            .annotation(position: .overlay) {
                                if data.percentage > 5 {
                                    Text("\(Int(data.percentage))%")
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                        .fontWeight(.bold)
                                }
                            }
                        }
                    }
                    .frame(width: 200, height: 200)
                    
                    // 图例
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.categoryData.prefix(5), id: \.category.id) { data in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(data.category.color)
                                    .frame(width: 12, height: 12)
                                
                                Text(data.category.name)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text("\(Int(data.percentage))%")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
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
    
    // MARK: - Ranking List
    private var rankingList: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("分类排名")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            if viewModel.categoryData.isEmpty {
                emptyStateView(message: "暂无数据")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.categoryData.enumerated()), id: \.element.category.id) { index, data in
                        rankingRow(data: data, rank: index + 1, total: viewModel.totalExpense)
                        
                        if index < viewModel.categoryData.count - 1 {
                            Divider()
                                .padding(.leading, 60)
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
    
    private func rankingRow(data: AnalysisViewModel.CategoryData, rank: Int, total: Double) -> some View {
        Button(action: {
            // TODO: 导航到该分类的交易列表
            print("点击分类: \(data.category.name)")
        }) {
            HStack(spacing: 12) {
                // 排名
                Text("\(rank)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .frame(width: 24)
                
                // 分类图标
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(data.category.color)
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: data.category.symbolName)
                        .foregroundColor(.white)
                        .font(.system(size: 18))
                }
                
                // 分类名称和进度条
                VStack(alignment: .leading, spacing: 6) {
                    Text(data.category.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 6)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(data.category.color)
                                .frame(width: geometry.size.width * CGFloat(data.percentage / 100), height: 6)
                        }
                    }
                    .frame(height: 6)
                }
                
                Spacer()
                
                // 金额
                Text("¥\(data.amount, specifier: "%.2f")")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Empty State
    private func emptyStateView(message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 40)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Update Data
    private func updateData() {
        viewModel.updateData(for: selectedDate, periodType: selectedPeriod, context: modelContext, allCategories: allCategories)
    }
}

#Preview {
    AnalysisView()
        .modelContainer(for: [ExpenseItem.self, Category.self], inMemory: true)
}
