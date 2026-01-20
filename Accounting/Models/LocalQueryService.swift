import Foundation
import SwiftData

/// 本地查询服务（执行 AIQueryIntent）
struct LocalQueryService {
    
    /// 执行查询意图
    /// - Parameters:
    ///   - intent: AI 查询意图
    ///   - context: SwiftData 模型上下文
    /// - Returns: 格式化的查询结果字符串
    /// - Throws: 如果查询执行失败
    static func executeQuery(intent: AIQueryIntent, context: ModelContext) throws -> String {
        // 处理聊天操作
        if intent.operation == .chat {
            return intent.chatResponse ?? "你好！我是你的记账助手，可以帮你查询和分析财务数据。"
        }
        
        // 构建查询描述符
        let descriptor = buildFetchDescriptor(
            startDate: intent.startDate,
            endDate: intent.endDate,
            categoryName: intent.categoryName,
            accountName: intent.accountName
        )
        
        // 执行查询
        let expenses = try context.fetch(descriptor)
        
        // 根据操作类型格式化结果
        switch intent.operation {
        case .sum:
            return formatSumResult(expenses: expenses)
        case .list:
            return formatListResult(expenses: expenses)
        case .count:
            return formatCountResult(expenses: expenses)
        case .chat:
            return intent.chatResponse ?? ""
        }
    }
    
    // MARK: - 构建查询描述符
    
    /// 构建 SwiftData 查询描述符
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
    private static func formatSumResult(expenses: [ExpenseItem]) -> String {
        let total = expenses.reduce(0.0) { $0 + $1.amount }
        let count = expenses.count
        
        if count == 0 {
            return "Total: ¥0.00\nFound 0 records."
        }
        
        return "Total: ¥\(String(format: "%.2f", total))\nFound \(count) record\(count == 1 ? "" : "s")."
    }
    
    /// 格式化列表结果（限制前 10 条）
    private static func formatListResult(expenses: [ExpenseItem]) -> String {
        let limitedExpenses = Array(expenses.prefix(10))
        
        if limitedExpenses.isEmpty {
            return "Found 0 records."
        }
        
        var result = ""
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM-dd"
        
        for (index, expense) in limitedExpenses.enumerated() {
            let dateStr = dateFormatter.string(from: expense.date)
            let amountStr = String(format: "%.2f", expense.amount)
            let categoryStr = expense.category
            let titleStr = expense.title.isEmpty ? "无标题" : expense.title
            
            result += "\(index + 1). [\(categoryStr)] -¥\(amountStr) (\(titleStr)) - \(dateStr)\n"
        }
        
        if expenses.count > 10 {
            result += "... and \(expenses.count - 10) more record\(expenses.count - 10 == 1 ? "" : "s")."
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// 格式化计数结果
    private static func formatCountResult(expenses: [ExpenseItem]) -> String {
        let count = expenses.count
        return "Found \(count) record\(count == 1 ? "" : "s")."
    }
}
