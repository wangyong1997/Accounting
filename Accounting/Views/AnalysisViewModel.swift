import Foundation
import SwiftData
import SwiftUI

/// 分析视图的数据模型
@Observable
class AnalysisViewModel {
    // MARK: - 数据模型
    struct DailyData {
        let day: Int
        let date: Date
        let amount: Double
    }
    
    struct CategoryData {
        let category: Category
        let amount: Double
        let percentage: Double
    }
    
    // MARK: - 计算属性
    var totalExpense: Double = 0
    var totalIncome: Double = 0
    var averageDailySpend: Double = 0
    var daysPassed: Int = 0
    
    var dailyData: [DailyData] = []
    var categoryData: [CategoryData] = []
    
    // MARK: - 更新数据
    func updateData(for date: Date, periodType: AnalysisView.PeriodType, context: ModelContext, allCategories: [Category]) {
        let calendar = Calendar.current
        
        let startDate: Date
        let endDate: Date
        
        if periodType == .month {
            // 月份视图
            startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
            endDate = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startDate) ?? date
            
            // 计算已过去的天数
            let today = Date()
            if calendar.isDate(today, equalTo: date, toGranularity: .month) {
                daysPassed = calendar.dateComponents([.day], from: startDate, to: today).day ?? 0
                daysPassed = max(1, daysPassed)
            } else {
                daysPassed = calendar.range(of: .day, in: .month, for: date)?.count ?? 30
            }
        } else {
            // 年份视图
            startDate = calendar.date(from: calendar.dateComponents([.year], from: date)) ?? date
            endDate = calendar.date(byAdding: DateComponents(year: 1, day: -1), to: startDate) ?? date
            
            // 计算已过去的天数
            let today = Date()
            if calendar.isDate(today, equalTo: date, toGranularity: .year) {
                daysPassed = calendar.dateComponents([.day], from: startDate, to: today).day ?? 0
                daysPassed = max(1, daysPassed)
            } else {
                daysPassed = calendar.range(of: .day, in: .year, for: date)?.count ?? 365
            }
        }
        
        // 获取该时间段的所有交易
        let descriptor = FetchDescriptor<ExpenseItem>(
            predicate: #Predicate<ExpenseItem> { item in
                item.date >= startDate && item.date <= endDate
            },
            sortBy: [SortDescriptor(\.date)]
        )
        
        guard let items = try? context.fetch(descriptor) else {
            resetData()
            return
        }
        
        // 处理数据
        if periodType == .month {
            processItemsForMonth(items, startDate: startDate, endDate: endDate, calendar: calendar, allCategories: allCategories)
        } else {
            processItemsForYear(items, startDate: startDate, endDate: endDate, calendar: calendar, allCategories: allCategories)
        }
    }
    
    // MARK: - 处理交易数据（月份）
    private func processItemsForMonth(_ items: [ExpenseItem], startDate: Date, endDate: Date, calendar: Calendar, allCategories: [Category]) {
        // 1. 计算总收入和总支出
        var expenseTotal: Double = 0
        var incomeTotal: Double = 0
        
        for item in items {
            let category = allCategories.first { $0.name == item.category }
            if category?.categoryType == .income {
                incomeTotal += item.amount
            } else {
                expenseTotal += item.amount
            }
        }
        
        totalExpense = expenseTotal
        totalIncome = incomeTotal
        averageDailySpend = daysPassed > 0 ? expenseTotal / Double(daysPassed) : 0
        
        // 2. 计算每日数据（仅支出）
        var dailyTotals: [Int: Double] = [:]
        for item in items {
            let category = allCategories.first { $0.name == item.category }
            if category?.categoryType == .expense {
                let day = calendar.component(.day, from: item.date)
                dailyTotals[day, default: 0] += item.amount
            }
        }
        
        // 生成每日数据数组
        let monthDays = calendar.range(of: .day, in: .month, for: startDate)?.count ?? 30
        dailyData = (1...monthDays).map { day in
            let date = calendar.date(bySetting: .day, value: day, of: startDate) ?? startDate
            let amount = dailyTotals[day] ?? 0
            return DailyData(day: day, date: date, amount: amount)
        }
        
        processCategoryData(items, expenseTotal: expenseTotal, allCategories: allCategories)
    }
    
    // MARK: - 处理交易数据（年份）
    private func processItemsForYear(_ items: [ExpenseItem], startDate: Date, endDate: Date, calendar: Calendar, allCategories: [Category]) {
        // 1. 计算总收入和总支出
        var expenseTotal: Double = 0
        var incomeTotal: Double = 0
        
        for item in items {
            let category = allCategories.first { $0.name == item.category }
            if category?.categoryType == .income {
                incomeTotal += item.amount
            } else {
                expenseTotal += item.amount
            }
        }
        
        totalExpense = expenseTotal
        totalIncome = incomeTotal
        averageDailySpend = daysPassed > 0 ? expenseTotal / Double(daysPassed) : 0
        
        // 2. 计算每月数据（用于柱状图）
        var monthlyTotals: [Int: Double] = [:]
        for item in items {
            let category = allCategories.first { $0.name == item.category }
            if category?.categoryType == .expense {
                let month = calendar.component(.month, from: item.date)
                monthlyTotals[month, default: 0] += item.amount
            }
        }
        
        // 生成每月数据数组
        dailyData = (1...12).map { month in
            let date = calendar.date(bySetting: .month, value: month, of: startDate) ?? startDate
            let amount = monthlyTotals[month] ?? 0
            return DailyData(day: month, date: date, amount: amount)
        }
        
        processCategoryData(items, expenseTotal: expenseTotal, allCategories: allCategories)
    }
    
    // MARK: - 处理分类数据（共用）
    private func processCategoryData(_ items: [ExpenseItem], expenseTotal: Double, allCategories: [Category]) {
        
        // 计算分类数据（仅支出）
        var categoryTotals: [String: Double] = [:]
        for item in items {
            let category = allCategories.first { $0.name == item.category }
            if category?.categoryType == .expense {
                categoryTotals[item.category, default: 0] += item.amount
            }
        }
        
        // 转换为 CategoryData 数组并排序
        var categoryDataList: [CategoryData] = categoryTotals.compactMap { categoryName, amount in
            guard let category = allCategories.first(where: { $0.name == categoryName }) else {
                return nil
            }
            let percentage = expenseTotal > 0 ? (amount / expenseTotal) * 100 : 0
            return CategoryData(category: category, amount: amount, percentage: percentage)
        }
        
        // 按金额排序
        categoryDataList.sort { $0.amount > $1.amount }
        
        // 取前5个，其余归为"其他"
        if categoryDataList.count > 5 {
            var top5 = Array(categoryDataList.prefix(5))
            let othersAmount = categoryDataList.dropFirst(5).reduce(0) { $0 + $1.amount }
            let othersPercentage = expenseTotal > 0 ? (othersAmount / expenseTotal) * 100 : 0
            
            // 查找或创建"其他"分类（用于显示，不保存到数据库）
            let othersCategory: Category
            if let existingOthers = allCategories.first(where: { $0.name == "其他" && $0.categoryType == .expense }) {
                othersCategory = existingOthers
            } else {
                // 创建临时分类对象（仅用于显示）
                othersCategory = Category(
                    name: "其他",
                    symbolName: "ellipsis.circle.fill",
                    hexColor: "#8E8E93",
                    type: .expense
                )
            }
            
            top5.append(CategoryData(
                category: othersCategory,
                amount: othersAmount,
                percentage: othersPercentage
            ))
            
            categoryData = top5
        } else {
            categoryData = categoryDataList
        }
    }
    
    // MARK: - 重置数据
    private func resetData() {
        totalExpense = 0
        totalIncome = 0
        averageDailySpend = 0
        daysPassed = 0
        dailyData = []
        categoryData = []
    }
}
