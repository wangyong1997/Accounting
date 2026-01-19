import Foundation
import SwiftData

/// 账户服务：处理余额调整和相关业务逻辑
struct AccountService {
    /// 调整账户余额，并自动创建交易记录以保持账本一致性
    /// - Parameters:
    ///   - account: 要调整的账户
    ///   - newBalance: 新的余额值
    ///   - context: SwiftData 模型上下文
    static func adjustBalance(account: Account, newBalance: Double, context: ModelContext) {
        // 1. 计算差异
        let difference = newBalance - account.balance
        
        // 2. 如果差异为 0，无需更改
        guard abs(difference) > 0.001 else {
            print("ℹ️ [AccountService] 余额无变化，跳过调整")
            return
        }
        
        // 3. 更新账户余额
        let oldBalance = account.balance
        account.balance = newBalance
        print("✅ [AccountService] 更新账户余额: \(account.name) - \(oldBalance) -> \(newBalance)")
        
        // 4. 创建交易记录
        if difference < 0 {
            // 负差异：资金减少，创建支出记录
            let adjustmentCategory = findOrCreateAdjustmentCategory(context: context, isIncome: false)
            let expense = ExpenseItem(
                amount: abs(difference),
                title: "余额调整（资产页面手动修正）",
                date: Date(),
                category: adjustmentCategory.name,
                accountName: account.name
            )
            context.insert(expense)
            
            // 增加分类的使用次数
            DataSeeder.incrementCategoryUsage(categoryName: adjustmentCategory.name, context: context)
            
            print("📝 [AccountService] 创建支出记录: -¥\(String(format: "%.2f", abs(difference)))")
        } else {
            // 正差异：资金增加，创建收入记录
            let adjustmentCategory = findOrCreateAdjustmentCategory(context: context, isIncome: true)
            let expense = ExpenseItem(
                amount: difference,
                title: "余额调整（资产页面手动修正）",
                date: Date(),
                category: adjustmentCategory.name,
                accountName: account.name
            )
            context.insert(expense)
            
            // 增加分类的使用次数
            DataSeeder.incrementCategoryUsage(categoryName: adjustmentCategory.name, context: context)
            
            print("📝 [AccountService] 创建收入记录: +¥\(String(format: "%.2f", difference))")
        }
        
        // 6. 保存上下文
        do {
            try context.save()
            print("✅ [AccountService] 余额调整完成并已保存")
        } catch {
            print("❌ [AccountService] 保存失败: \(error.localizedDescription)")
        }
    }
    
    /// 查找或创建余额调整分类
    /// - Parameter isIncome: 是否为收入类型
    private static func findOrCreateAdjustmentCategory(context: ModelContext, isIncome: Bool) -> Category {
        let categoryName = "余额调整"
        let categoryType: CategoryType = isIncome ? .income : .expense
        
        // 查找现有分类（按名称和类型）
        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate<Category> { category in
                category.name == categoryName && category.type == categoryType.rawValue
            }
        )
        
        if let existingCategory = try? context.fetch(descriptor).first {
            print("✅ [AccountService] 找到现有调整分类: \(existingCategory.name) (类型: \(categoryType.rawValue))")
            return existingCategory
        }
        
        // 创建新分类
        let newCategory = Category(
            name: categoryName,
            symbolName: "slider.horizontal.3",
            hexColor: "#8E8E93",
            type: categoryType
        )
        context.insert(newCategory)
        print("✅ [AccountService] 创建新的调整分类: \(newCategory.name) (类型: \(categoryType.rawValue))")
        
        return newCategory
    }
}
