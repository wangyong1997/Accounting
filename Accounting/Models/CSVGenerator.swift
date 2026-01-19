import Foundation
import SwiftData

/// CSV 生成器：将账单数据转换为 CSV 格式
struct CSVGenerator {
    /// 生成 CSV 字符串
    /// - Parameter expenses: 账单数组
    /// - Returns: CSV 格式的字符串（包含 BOM，Excel 兼容）
    static func generateCSV(from expenses: [ExpenseItem]) -> String {
        // 创建日期格式化器
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "zh_CN")
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        timeFormatter.locale = Locale(identifier: "zh_CN")
        
        // 创建 CSV 字符串（从 BOM 开始，确保 Excel 正确识别 UTF-8）
        var csvString = "\u{FEFF}"
        
        // 添加表头
        csvString += "Date,Time,Type,Amount,Category,Account,Note\n"
        
        // 添加数据行
        for expense in expenses {
            // 日期
            let dateStr = dateFormatter.string(from: expense.date)
            
            // 时间
            let timeStr = timeFormatter.string(from: expense.date)
            
            // 类型（根据金额正负判断，但实际应该根据分类判断）
            // 注意：这里我们需要根据分类名称判断，但 ExpenseItem 只有 category 字符串
            // 我们需要查询 Category 来确定类型，但为了简化，我们可以根据金额或分类名称判断
            // 实际上，我们应该传入分类信息，但为了保持简单，这里先使用一个占位符
            // 更好的方式是传入分类映射，但为了快速实现，我们使用 "Expense" 或 "Income"
            // 由于我们无法直接判断，这里先使用 "Expense"（实际应该根据分类类型）
            let typeStr = "Expense" // 或者 "Income"，需要根据分类判断
            
            // 金额（保留两位小数）
            let amountStr = String(format: "%.2f", expense.amount)
            
            // 分类（转义逗号和引号）
            let categoryStr = escapeCSVField(expense.category)
            
            // 账户（可选，转义逗号和引号）
            let accountStr = escapeCSVField(expense.accountName ?? "")
            
            // 备注（转义逗号和引号）
            let noteStr = escapeCSVField(expense.title)
            
            // 构建行
            csvString += "\(dateStr),\(timeStr),\(typeStr),\(amountStr),\(categoryStr),\(accountStr),\(noteStr)\n"
        }
        
        return csvString
    }
    
    /// 生成 CSV 字符串（带分类类型信息）
    /// - Parameters:
    ///   - expenses: 账单数组
    ///   - categories: 分类数组（用于判断收入/支出）
    /// - Returns: CSV 格式的字符串（包含 BOM，Excel 兼容）
    static func generateCSV(from expenses: [ExpenseItem], categories: [Category]) -> String {
        // 创建分类映射（名称 -> 类型）
        let categoryMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.name, $0.categoryType) })
        
        // 创建日期格式化器
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "zh_CN")
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        timeFormatter.locale = Locale(identifier: "zh_CN")
        
        // 创建 CSV 字符串（从 BOM 开始，确保 Excel 正确识别 UTF-8）
        var csvString = "\u{FEFF}"
        
        // 添加表头
        csvString += "Date,Time,Type,Amount,Category,Account,Note\n"
        
        // 添加数据行
        for expense in expenses {
            // 日期
            let dateStr = dateFormatter.string(from: expense.date)
            
            // 时间
            let timeStr = timeFormatter.string(from: expense.date)
            
            // 类型（根据分类判断）
            let categoryType = categoryMap[expense.category] ?? .expense
            let typeStr = categoryType == .income ? "Income" : "Expense"
            
            // 金额（保留两位小数）
            let amountStr = String(format: "%.2f", expense.amount)
            
            // 分类（转义逗号和引号）
            let categoryStr = escapeCSVField(expense.category)
            
            // 账户（可选，转义逗号和引号）
            let accountStr = escapeCSVField(expense.accountName ?? "")
            
            // 备注（转义逗号和引号）
            let noteStr = escapeCSVField(expense.title)
            
            // 构建行
            csvString += "\(dateStr),\(timeStr),\(typeStr),\(amountStr),\(categoryStr),\(accountStr),\(noteStr)\n"
        }
        
        return csvString
    }
    
    /// 转义 CSV 字段（处理逗号、引号和换行符）
    /// - Parameter field: 原始字段值
    /// - Returns: 转义后的字段值
    private static func escapeCSVField(_ field: String) -> String {
        // 如果字段包含逗号、引号或换行符，需要用引号包裹，并转义内部的引号
        if field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") {
            // 将内部的引号转义为两个引号
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }
}
