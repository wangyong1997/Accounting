import Foundation
import SwiftData

/// 本地数据查询服务（执行查询意图）
struct LocalDataService {
    
    /// 执行查询意图
    /// - Parameters:
    ///   - intent: 查询意图
    ///   - context: SwiftData 模型上下文
    /// - Returns: 格式化的查询结果字符串
    static func executeIntent(_ intent: QueryIntent, context: ModelContext) -> String {
        // 处理 unknown 操作
        guard intent.operation != .unknown else {
            return "" // 返回空字符串，让 AI 处理为普通聊天
        }
        
        // 解析日期范围
        let startDate = parseDate(intent.startDate)
        let endDate = parseDate(intent.endDate)
        
        // 构建查询描述符
        let descriptor = buildFetchDescriptor(
            startDate: startDate,
            endDate: endDate,
            categoryName: intent.categoryName,
            accountName: intent.accountName
        )
        
        // 执行查询
        guard let expenses = try? context.fetch(descriptor) else {
            return "❌ 查询数据时出现错误"
        }
        
        // 根据操作类型格式化结果
        switch intent.operation {
        case .sum:
            return formatSumResult(expenses: expenses, intent: intent)
        case .list:
            return formatListResult(expenses: expenses, intent: intent)
        case .count:
            return formatCountResult(expenses: expenses)
        case .chat:
            // chat 操作应该返回 chatResponse，但这里不应该执行查询
            return intent.chatResponse ?? ""
        case .unknown:
            return ""
        }
    }
    
    // MARK: - 日期解析
    
    /// 解析日期字符串（支持 ISO8601 和相对偏移）
    /// - Parameter dateString: 日期字符串（如 "2024-01-15", "-7d", "today"）
    /// - Returns: Date 对象，如果解析失败返回 nil
    private static func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        
        // 处理 "today" 或 "今天"
        if dateString.lowercased() == "today" || dateString.lowercased() == "今天" {
            return Calendar.current.startOfDay(for: Date())
        }
        
        // 处理相对偏移（如 "-7d" 表示 7 天前）
        if dateString.hasPrefix("-") || dateString.hasPrefix("+") {
            let isNegative = dateString.hasPrefix("-")
            let numberString = String(dateString.dropFirst())
            
            if numberString.hasSuffix("d") {
                let daysString = String(numberString.dropLast())
                if let days = Int(daysString) {
                    let calendar = Calendar.current
                    let offset = isNegative ? -days : days
                    let date = calendar.date(byAdding: .day, value: offset, to: Date()) ?? Date()
                    return calendar.startOfDay(for: date)
                }
            }
        }
        
        // 尝试解析 ISO8601 格式
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: dateString) {
            return Calendar.current.startOfDay(for: date)
        }
        
        // 尝试不带秒的格式
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: dateString) {
            return Calendar.current.startOfDay(for: date)
        }
        
        // 尝试简单日期格式 (yyyy-MM-dd)
        let simpleFormatter = DateFormatter()
        simpleFormatter.dateFormat = "yyyy-MM-dd"
        simpleFormatter.locale = Locale(identifier: "en_US_POSIX")
        if let date = simpleFormatter.date(from: dateString) {
            return Calendar.current.startOfDay(for: date)
        }
        
        return nil
    }
    
    // MARK: - 构建查询描述符
    
    /// 构建 SwiftData 查询描述符
    /// - Parameters:
    ///   - startDate: 开始日期
    ///   - endDate: 结束日期
    ///   - categoryName: 分类名称
    ///   - accountName: 账户名称
    /// - Returns: FetchDescriptor<ExpenseItem>
    private static func buildFetchDescriptor(
        startDate: Date?,
        endDate: Date?,
        categoryName: String?,
        accountName: String?
    ) -> FetchDescriptor<ExpenseItem> {
        
        // 根据筛选条件构建谓词
        if let start = startDate, let end = endDate {
            // 日期范围 + 分类 + 账户
            if let category = categoryName, let account = accountName {
                return FetchDescriptor<ExpenseItem>(
                    predicate: #Predicate<ExpenseItem> { item in
                        item.date >= start && item.date <= end &&
                        item.category == category &&
                        item.accountName == account
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            } else if let category = categoryName {
                return FetchDescriptor<ExpenseItem>(
                    predicate: #Predicate<ExpenseItem> { item in
                        item.date >= start && item.date <= end &&
                        item.category == category
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            } else if let account = accountName {
                return FetchDescriptor<ExpenseItem>(
                    predicate: #Predicate<ExpenseItem> { item in
                        item.date >= start && item.date <= end &&
                        item.accountName == account
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            } else {
                return FetchDescriptor<ExpenseItem>(
                    predicate: #Predicate<ExpenseItem> { item in
                        item.date >= start && item.date <= end
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            }
        } else if let start = startDate {
            // 只有开始日期
            if let category = categoryName, let account = accountName {
                return FetchDescriptor<ExpenseItem>(
                    predicate: #Predicate<ExpenseItem> { item in
                        item.date >= start &&
                        item.category == category &&
                        item.accountName == account
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            } else if let category = categoryName {
                return FetchDescriptor<ExpenseItem>(
                    predicate: #Predicate<ExpenseItem> { item in
                        item.date >= start && item.category == category
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            } else if let account = accountName {
                return FetchDescriptor<ExpenseItem>(
                    predicate: #Predicate<ExpenseItem> { item in
                        item.date >= start && item.accountName == account
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            } else {
                return FetchDescriptor<ExpenseItem>(
                    predicate: #Predicate<ExpenseItem> { item in
                        item.date >= start
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            }
        } else if let end = endDate {
            // 只有结束日期
            if let category = categoryName, let account = accountName {
                return FetchDescriptor<ExpenseItem>(
                    predicate: #Predicate<ExpenseItem> { item in
                        item.date <= end &&
                        item.category == category &&
                        item.accountName == account
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            } else if let category = categoryName {
                return FetchDescriptor<ExpenseItem>(
                    predicate: #Predicate<ExpenseItem> { item in
                        item.date <= end && item.category == category
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            } else if let account = accountName {
                return FetchDescriptor<ExpenseItem>(
                    predicate: #Predicate<ExpenseItem> { item in
                        item.date <= end && item.accountName == account
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            } else {
                return FetchDescriptor<ExpenseItem>(
                    predicate: #Predicate<ExpenseItem> { item in
                        item.date <= end
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            }
        } else {
            // 没有日期范围，只有分类或账户筛选
            if let category = categoryName, let account = accountName {
                return FetchDescriptor<ExpenseItem>(
                    predicate: #Predicate<ExpenseItem> { item in
                        item.category == category && item.accountName == account
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            } else if let category = categoryName {
                return FetchDescriptor<ExpenseItem>(
                    predicate: #Predicate<ExpenseItem> { item in
                        item.category == category
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            } else if let account = accountName {
                return FetchDescriptor<ExpenseItem>(
                    predicate: #Predicate<ExpenseItem> { item in
                        item.accountName == account
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            } else {
                // 没有筛选条件，获取所有记录
                return FetchDescriptor<ExpenseItem>(
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            }
        }
    }
    
    // MARK: - 格式化结果
    
    /// 格式化总和结果
    /// - Parameters:
    ///   - expenses: 交易记录数组
    ///   - intent: 查询意图
    /// - Returns: 格式化的字符串
    private static func formatSumResult(expenses: [ExpenseItem], intent: QueryIntent) -> String {
        let total = expenses.reduce(0.0) { $0 + $1.amount }
        let count = expenses.count
        
        var result = "Total: \(String(format: "%.2f", total))\n"
        result += "Records: \(count)"
        
        // 添加筛选条件说明（可选，用于调试）
        var filters: [String] = []
        if intent.startDate != nil || intent.endDate != nil {
            if let start = parseDate(intent.startDate), let end = parseDate(intent.endDate) {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                filters.append("Date: \(dateFormatter.string(from: start)) to \(dateFormatter.string(from: end))")
            } else if let start = parseDate(intent.startDate) {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                filters.append("Date: from \(dateFormatter.string(from: start))")
            } else if let end = parseDate(intent.endDate) {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                filters.append("Date: to \(dateFormatter.string(from: end))")
            }
        }
        if let category = intent.categoryName {
            filters.append("Category: \(category)")
        }
        if let account = intent.accountName {
            filters.append("Account: \(account)")
        }
        
        if !filters.isEmpty {
            result += "\nFilters: " + filters.joined(separator: ", ")
        }
        
        return result
    }
    
    /// 格式化列表结果（CSV 样式）
    /// - Parameters:
    ///   - expenses: 交易记录数组
    ///   - intent: 查询意图
    /// - Returns: CSV 样式的字符串（限制 20 条）
    private static func formatListResult(expenses: [ExpenseItem], intent: QueryIntent) -> String {
        let limitedExpenses = Array(expenses.prefix(20)) // 限制 20 条以节省 token
        let count = expenses.count
        
        if limitedExpenses.isEmpty {
            return "No records found.\nTotal: 0"
        }
        
        // CSV 样式：Date, Name, Amount, Category, Account
        var result = "Date,Name,Amount,Category,Account\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        
        for expense in limitedExpenses {
            let dateStr = dateFormatter.string(from: expense.date)
            let nameStr = expense.title.replacingOccurrences(of: ",", with: ";") // 转义逗号
            let amountStr = String(format: "%.2f", expense.amount)
            let categoryStr = expense.category
            let accountStr = expense.accountName ?? ""
            
            result += "\(dateStr),\(nameStr),\(amountStr),\(categoryStr),\(accountStr)\n"
        }
        
        if count > 20 {
            result += "\n... (showing 20 of \(count) records)"
        }
        
        return result
    }
    
    /// 格式化计数结果
    /// - Parameter expenses: 交易记录数组
    /// - Returns: 格式化的字符串
    private static func formatCountResult(expenses: [ExpenseItem]) -> String {
        let count = expenses.count
        return "Found \(count) record\(count == 1 ? "" : "s")."
    }
}
