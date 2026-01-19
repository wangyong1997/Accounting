import Foundation
import SwiftData

/// CSV 导入器：从 CSV 文件导入账单数据
struct CSVImporter {
    /// 导入结果
    struct ImportResult {
        let success: Int
        let failed: Int
        
        var total: Int {
            success + failed
        }
    }
    
    /// 导入 CSV 文件
    /// - Parameters:
    ///   - url: CSV 文件 URL
    ///   - context: SwiftData 模型上下文
    /// - Returns: 导入结果（成功和失败的数量）
    /// - Throws: 导入过程中的错误
    static func importCSV(url: URL, context: ModelContext) throws -> ImportResult {
        // 开始访问安全作用域资源
        guard url.startAccessingSecurityScopedResource() else {
            throw ImportError.cannotAccessFile
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        // 读取文件内容
        let csvString: String
        do {
            // 尝试使用 UTF-8 编码读取（处理 BOM）
            var data = try Data(contentsOf: url)
            // 移除 BOM（如果存在）
            // UTF-8 BOM 是 0xEF 0xBB 0xBF
            if data.count >= 3 && data[0] == 0xEF && data[1] == 0xBB && data[2] == 0xBF {
                data = data.dropFirst(3)
            }
            csvString = String(data: data, encoding: .utf8) ?? ""
        } catch {
            throw ImportError.cannotReadFile(error)
        }
        
        // 解析 CSV
        let lines = csvString.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        guard lines.count > 1 else {
            throw ImportError.invalidFileFormat("文件为空或格式不正确")
        }
        
        // 跳过表头（第一行）
        let dataLines = Array(lines.dropFirst())
        
        // 创建日期格式化器
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        dateFormatter.locale = Locale(identifier: "zh_CN")
        
        var successCount = 0
        var failedCount = 0
        
        // 获取所有现有分类和账户（用于查找或创建）
        let existingCategories = try? context.fetch(FetchDescriptor<Category>())
        let existingAccounts = try? context.fetch(FetchDescriptor<Account>())
        let existingExpenses = try? context.fetch(FetchDescriptor<ExpenseItem>())
        
        // 创建查找映射
        var categoryMap: [String: Category] = [:]
        if let categories = existingCategories {
            categoryMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.name, $0) })
        }
        
        var accountMap: [String: Account] = [:]
        if let accounts = existingAccounts {
            accountMap = Dictionary(uniqueKeysWithValues: accounts.map { ($0.name, $0) })
        }
        
        // 创建重复检查集合（使用 Set 提高查找效率）
        let existingExpenseSet = Set(existingExpenses?.map { "\($0.amount)|\($0.date.timeIntervalSince1970)|\($0.title)" } ?? [])
        
        // 解析每一行
        for (index, line) in dataLines.enumerated() {
            do {
                // 解析 CSV 行（处理引号包裹的字段）
                let fields = parseCSVLine(line)
                
                guard fields.count >= 7 else {
                    print("⚠️ [CSVImporter] 第 \(index + 2) 行字段数量不足，跳过")
                    failedCount += 1
                    continue
                }
                
                // 解析字段
                let dateStr = fields[0].trimmingCharacters(in: .whitespaces)
                let timeStr = fields[1].trimmingCharacters(in: .whitespaces)
                let typeStr = fields[2].trimmingCharacters(in: .whitespaces)
                let amountStr = fields[3].trimmingCharacters(in: .whitespaces)
                let categoryStr = fields[4].trimmingCharacters(in: .whitespaces)
                let accountStr = fields[5].trimmingCharacters(in: .whitespaces)
                let noteStr = fields[6].trimmingCharacters(in: .whitespaces)
                
                // 解析日期和时间
                let dateTimeStr = "\(dateStr) \(timeStr)"
                guard let date = dateFormatter.date(from: dateTimeStr) else {
                    print("⚠️ [CSVImporter] 第 \(index + 2) 行日期解析失败: \(dateTimeStr)")
                    failedCount += 1
                    continue
                }
                
                // 解析金额
                guard let amount = Double(amountStr) else {
                    print("⚠️ [CSVImporter] 第 \(index + 2) 行金额解析失败: \(amountStr)")
                    failedCount += 1
                    continue
                }
                
                // 检查重复
                let expenseKey = "\(amount)|\(date.timeIntervalSince1970)|\(noteStr)"
                if existingExpenseSet.contains(expenseKey) {
                    print("ℹ️ [CSVImporter] 第 \(index + 2) 行已存在，跳过重复")
                    continue
                }
                
                // 查找或创建分类
                let category: Category
                if let existingCategory = categoryMap[categoryStr] {
                    category = existingCategory
                } else {
                    // 根据 Type 字段判断分类类型
                    let categoryType: CategoryType = (typeStr.lowercased() == "income") ? .income : .expense
                    category = Category(
                        name: categoryStr.isEmpty ? "未分类" : categoryStr,
                        symbolName: "questionmark.circle",
                        hexColor: "#8E8E93",
                        type: categoryType
                    )
                    context.insert(category)
                    categoryMap[categoryStr] = category
                    print("✅ [CSVImporter] 创建新分类: \(category.name)")
                }
                
                // 查找或创建账户
                let account: Account?
                if accountStr.isEmpty {
                    account = nil
                } else if let existingAccount = accountMap[accountStr] {
                    account = existingAccount
                } else {
                    // 创建新账户
                    account = Account(
                        name: accountStr,
                        balance: 0.0,
                        type: .cash,
                        hexColor: "#8E8E93",
                        iconName: "creditcard.fill"
                    )
                    context.insert(account!)
                    accountMap[accountStr] = account
                    print("✅ [CSVImporter] 创建新账户: \(account!.name)")
                }
                
                // 创建账单
                let expense = ExpenseItem(
                    amount: amount,
                    title: noteStr.isEmpty ? category.name : noteStr,
                    date: date,
                    category: category.name,
                    accountName: account?.name
                )
                
                // 更新账户余额（如果有关联账户）
                if let account = account {
                    let isIncome = category.categoryType == .income
                    if isIncome {
                        account.balance += amount
                    } else {
                        account.balance -= amount
                    }
                }
                
                context.insert(expense)
                
                // 增加分类的使用次数
                DataSeeder.incrementCategoryUsage(categoryName: category.name, context: context)
                
                successCount += 1
                
            } catch {
                print("❌ [CSVImporter] 第 \(index + 2) 行处理失败: \(error.localizedDescription)")
                failedCount += 1
            }
        }
        
        // 保存上下文
        do {
            try context.save()
            print("✅ [CSVImporter] 导入完成，保存成功")
        } catch {
            print("❌ [CSVImporter] 保存失败: \(error.localizedDescription)")
            throw ImportError.saveFailed(error)
        }
        
        return ImportResult(success: successCount, failed: failedCount)
    }
    
    /// 解析 CSV 行（处理引号包裹的字段）
    /// - Parameter line: CSV 行字符串
    /// - Returns: 字段数组
    private static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var insideQuotes = false
        var characters = Array(line)
        var index = 0
        
        while index < characters.count {
            let char = characters[index]
            
            if char == "\"" {
                if insideQuotes {
                    // 检查是否是转义的引号（两个连续引号）
                    if index + 1 < characters.count && characters[index + 1] == "\"" {
                        // 转义的引号，添加一个引号
                        currentField += "\""
                        index += 2
                        continue
                    } else {
                        // 结束引号字段
                        insideQuotes = false
                    }
                } else {
                    // 开始引号字段
                    insideQuotes = true
                }
            } else if char == "," && !insideQuotes {
                // 字段分隔符（不在引号内）
                fields.append(currentField)
                currentField = ""
            } else {
                // 普通字符
                currentField.append(char)
            }
            
            index += 1
        }
        
        // 添加最后一个字段
        fields.append(currentField)
        
        return fields
    }
    
    /// 导入错误类型
    enum ImportError: LocalizedError {
        case cannotAccessFile
        case cannotReadFile(Error)
        case invalidFileFormat(String)
        case saveFailed(Error)
        
        var errorDescription: String? {
            switch self {
            case .cannotAccessFile:
                return "无法访问文件"
            case .cannotReadFile(let error):
                return "无法读取文件: \(error.localizedDescription)"
            case .invalidFileFormat(let message):
                return "文件格式无效: \(message)"
            case .saveFailed(let error):
                return "保存失败: \(error.localizedDescription)"
            }
        }
    }
}
