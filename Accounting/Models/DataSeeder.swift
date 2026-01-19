import Foundation
import SwiftData
import SwiftUI

struct DataSeeder {
    /// 增加分类的使用次数
    /// - Parameters:
    ///   - categoryName: 分类名称
    ///   - context: SwiftData 模型上下文
    static func incrementCategoryUsage(categoryName: String, context: ModelContext) {
        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate<Category> { $0.name == categoryName }
        )
        
        if let category = try? context.fetch(descriptor).first {
            // 确保 usageCount 已初始化
            if category.usageCount == nil {
                category.usageCount = 0
            }
            category.usageCount = (category.usageCount ?? 0) + 1
            try? context.save()
            print("📊 [DataSeeder] 增加分类使用次数: \(categoryName) -> \(category.usageCount ?? 0)")
        }
    }
    
    static func ensureDefaults(context: ModelContext) {
        // Check if categories already exist
        let categoryDescriptor = FetchDescriptor<Category>()
        let existingCategories = try? context.fetch(categoryDescriptor)
        
        if existingCategories?.isEmpty ?? true {
            // Insert default categories
            let defaultCategories = createDefaultCategories()
            for category in defaultCategories {
                context.insert(category)
            }
        } else {
            // 迁移现有分类：为缺少 sortOrder 或 usageCount 的分类设置默认值
            migrateExistingCategories(context: context, existingCategories: existingCategories ?? [])
        }
        
        // Check if accounts already exist
        let accountDescriptor = FetchDescriptor<Account>()
        let existingAccounts = try? context.fetch(accountDescriptor)
        
        if existingAccounts?.isEmpty ?? true {
            // Insert default accounts
            let defaultAccounts = createDefaultAccounts()
            for account in defaultAccounts {
                context.insert(account)
            }
        } else {
            // Update existing accounts with correct icons
            updateAccountIcons(context: context, existingAccounts: existingAccounts ?? [])
        }
        
        // Save context
        try? context.save()
    }
    
    private static func createDefaultCategories() -> [Category] {
        var categories: [Category] = []
        
        // MARK: - Expense Categories
        // Sort order based on typical usage frequency (0 = highest priority)
        
        // Food Group (Orange #FF9500) - High frequency
        categories.append(Category(name: "餐饮", symbolName: "fork.knife", hexColor: "#FF9500", type: .expense, sortOrder: 0)) // Dining
        categories.append(Category(name: "零食", symbolName: "cup.and.saucer.fill", hexColor: "#FF9500", type: .expense, sortOrder: 1)) // Snacks
        categories.append(Category(name: "杂货", symbolName: "basket.fill", hexColor: "#FF9500", type: .expense, sortOrder: 2)) // Groceries
        categories.append(Category(name: "酒精", symbolName: "wineglass.fill", hexColor: "#FF9500", type: .expense, sortOrder: 15))
        
        // Transport Group (Blue #007AFF) - Medium-high frequency
        categories.append(Category(name: "公共交通", symbolName: "tram.fill", hexColor: "#007AFF", type: .expense, sortOrder: 3)) // Transport
        categories.append(Category(name: "出租车", symbolName: "car.fill", hexColor: "#007AFF", type: .expense, sortOrder: 8))
        categories.append(Category(name: "旅行", symbolName: "airplane", hexColor: "#007AFF", type: .expense, sortOrder: 18))
        
        // Shopping Group (Red #FF2D55) - Medium frequency
        categories.append(Category(name: "日常需求", symbolName: "cart.fill", hexColor: "#FF2D55", type: .expense, sortOrder: 4)) // Daily Needs
        categories.append(Category(name: "衣服", symbolName: "tshirt.fill", hexColor: "#FF2D55", type: .expense, sortOrder: 6)) // Clothes
        categories.append(Category(name: "电子产品", symbolName: "desktopcomputer", hexColor: "#FF2D55", type: .expense, sortOrder: 16))
        categories.append(Category(name: "家具", symbolName: "chair.lounge.fill", hexColor: "#FF2D55", type: .expense, sortOrder: 19))

        // Social Group - Medium frequency
        categories.append(Category(name: "社交", symbolName: "envelope.fill", hexColor: "#8E8E93", type: .expense, sortOrder: 5)) // Social
        
        // Entertainment Group (Purple #AF52DE) - Medium frequency
        categories.append(Category(name: "电影", symbolName: "movieclapper.fill", hexColor: "#AF52DE", type: .expense, sortOrder: 7)) // Entertainment
        categories.append(Category(name: "游戏", symbolName: "gamecontroller.fill", hexColor: "#AF52DE", type: .expense, sortOrder: 12))
        categories.append(Category(name: "运动", symbolName: "figure.run", hexColor: "#AF52DE", type: .expense, sortOrder: 13))
        categories.append(Category(name: "宠物", symbolName: "pawprint.fill", hexColor: "#AF52DE", type: .expense, sortOrder: 17))
        
        // Housing Group (Green #34C759) - Low frequency (monthly)
        categories.append(Category(name: "房租/房贷", symbolName: "house.fill", hexColor: "#34C759", type: .expense, sortOrder: 9)) // Rent
        categories.append(Category(name: "水电费", symbolName: "bolt.fill", hexColor: "#34C759", type: .expense, sortOrder: 10))
        categories.append(Category(name: "网络", symbolName: "wifi", hexColor: "#34C759", type: .expense, sortOrder: 11))
        
        // Medical & Others Group (Gray #8E8E93) - Low frequency
        categories.append(Category(name: "医疗", symbolName: "cross.case.fill", hexColor: "#8E8E93", type: .expense, sortOrder: 14)) // Medical
        categories.append(Category(name: "教育", symbolName: "book.closed.fill", hexColor: "#8E8E93", type: .expense, sortOrder: 20))
        categories.append(Category(name: "其他", symbolName: "ellipsis.circle.fill", hexColor: "#8E8E93", type: .expense, sortOrder: 21))
        
        // MARK: - Income Categories (Gold #FFCC00)
        // Income categories typically have lower frequency than expenses
        categories.append(Category(name: "工资", symbolName: "banknote.fill", hexColor: "#FFCC00", type: .income, sortOrder: 0)) // Salary (most common income)
        categories.append(Category(name: "奖金", symbolName: "dollarsign.circle.fill", hexColor: "#FFCC00", type: .income, sortOrder: 1))
        categories.append(Category(name: "投资", symbolName: "chart.line.uptrend.xyaxis", hexColor: "#FFCC00", type: .income, sortOrder: 2))
        categories.append(Category(name: "兼职", symbolName: "briefcase.fill", hexColor: "#FFCC00", type: .income, sortOrder: 3))
        categories.append(Category(name: "其他收入", symbolName: "tray.and.arrow.down.fill", hexColor: "#FFCC00", type: .income, sortOrder: 4))
        
        return categories
    }
    
    private static func createDefaultAccounts() -> [Account] {
        return [
            Account(name: "微信支付", balance: 0.0, type: .ewallet, hexColor: "#07C160", iconName: "message.fill"),
            Account(name: "支付宝", balance: 0.0, type: .ewallet, hexColor: "#1677FF", iconName: "qrcode.viewfinder"),
            Account(name: "银行卡", balance: 0.0, type: .debitCard, hexColor: "#FF3B30", iconName: "creditcard.fill"),
            Account(name: "现金", balance: 0.0, type: .cash, hexColor: "#FF9500", iconName: "banknote.fill"),
            Account(name: "信用卡/花呗", balance: 0.0, type: .creditCard, hexColor: "#5856D6", iconName: "creditcard.fill")
        ]
    }
    
    // MARK: - Migrate Existing Categories
    /// 迁移现有分类：为缺少 sortOrder 或 usageCount 的分类设置默认值
    private static func migrateExistingCategories(context: ModelContext, existingCategories: [Category]) {
        // 定义分类名称到 sortOrder 的映射（与 createDefaultCategories 中的顺序一致）
        let categorySortOrderMap: [String: Int] = [
            // 支出分类
            "餐饮": 0,
            "零食": 1,
            "杂货": 2,
            "公共交通": 3,
            "日常需求": 4,
            "社交": 5,
            "衣服": 6,
            "电影": 7,
            "出租车": 8,
            "房租/房贷": 9,
            "水电费": 10,
            "网络": 11,
            "游戏": 12,
            "运动": 13,
            "医疗": 14,
            "酒精": 15,
            "电子产品": 16,
            "宠物": 17,
            "旅行": 18,
            "家具": 19,
            "教育": 20,
            "其他": 21,
            // 收入分类
            "工资": 0,
            "奖金": 1,
            "投资": 2,
            "兼职": 3,
            "其他收入": 4
        ]
        
        var needsSave = false
        
        for category in existingCategories {
            var updated = false
            
            // 迁移 sortOrder：如果为 nil 或需要更新
            if let mappedSortOrder = categorySortOrderMap[category.name] {
                if category.sortOrder != mappedSortOrder {
                    category.sortOrder = mappedSortOrder
                    updated = true
                    print("🔄 [DataSeeder] 迁移分类 sortOrder: \(category.name) -> \(mappedSortOrder)")
                }
            } else {
                // 如果不在映射中，设置为默认值 999（最低优先级）
                if category.sortOrder == nil {
                    category.sortOrder = 999
                    updated = true
                    print("🔄 [DataSeeder] 迁移分类 sortOrder: \(category.name) -> 999 (默认)")
                }
            }
            
            // 确保 usageCount 已初始化
            if category.usageCount == nil {
                category.usageCount = 0
                updated = true
                print("🔄 [DataSeeder] 迁移分类 usageCount: \(category.name) -> 0")
            }
            
            if updated {
                needsSave = true
            }
        }
        
        if needsSave {
            do {
                try context.save()
                print("✅ [DataSeeder] 分类迁移完成")
            } catch {
                print("❌ [DataSeeder] 分类迁移保存失败: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Update Account Icons
    private static func updateAccountIcons(context: ModelContext, existingAccounts: [Account]) {
        // 定义账户名称到图标名称的映射
        let accountIconMap: [String: String] = [
            "微信支付": "message.fill",
            "支付宝": "qrcode.viewfinder",
            "银行卡": "creditcard.fill",
            "现金": "banknote.fill",
            "信用卡/花呗": "creditcard.fill"
        ]
        
        // 更新现有账户的图标
        for account in existingAccounts {
            if let correctIconName = accountIconMap[account.name] {
                // 如果图标名称不匹配，则更新
                if account.iconName != correctIconName {
                    account.iconName = correctIconName
                    print("✅ [DataSeeder] 更新账户图标: \(account.name) -> \(correctIconName)")
                }
            }
        }
    }
}

// MARK: - Quick Access Icons
struct QuickAccessIcons {
    // Most commonly used icons for quick selection
    static let commonIcons: [String] = [
        // 购物相关
        "cart.fill",           // Shopping
        "bag.fill",            // Shopping Bag
        "gift.fill",           // Gift
        "tag.fill",            // Tag/Price
        
        // 餐饮相关
        "fork.knife",          // Dining
        "cup.and.saucer.fill", // Snacks/Drinks
        "wineglass.fill",      // Alcohol
        "birthday.cake.fill",  // Birthday/Celebration
        "takeoutbag.and.cup.and.straw.fill", // Takeout
        
        // 交通相关
        "car.fill",            // Car
        "tram.fill",           // Public Transit
        "bicycle",             // Bicycle
        "fuelpump.fill",       // Gas/Fuel
        "airplane",            // Travel
        "sailboat.fill",       // Travel/Leisure
        
        // 住房相关
        "house.fill",          // Housing
        "building.2.fill",      // Building
        "key.fill",            // Key/Rent
        
        // 生活用品
        "bolt.fill",           // Utilities/Electricity
        "drop.fill",           // Water
        "flame.fill",          // Gas/Heating
        "wifi",                // Internet
        "phone.fill",          // Phone/Mobile
        "tv.fill",             // TV/Entertainment
        
        // 服装美容
        "tshirt.fill",         // Clothes
        "scissors",            // Haircut/Beauty
        "sparkles",            // Beauty/Cosmetics
        
        // 电子产品
        "desktopcomputer",     // Computer
        "laptopcomputer",      // Laptop
        "iphone",              // Phone
        "ipad",                // Tablet
        "headphones",          // Audio
        
        // 家具家居
        "chair.lounge.fill",   // Furniture
        "bed.double.fill",     // Bed
        "sofa.fill",           // Sofa
        
        // 娱乐休闲
        "gamecontroller.fill", // Games
        "movieclapper.fill",   // Movies
        "music.note",          // Music
        "figure.run",          // Sports
        "figure.walk",         // Walking/Exercise
        "dumbbell.fill",       // Gym/Fitness
        "ticket.fill",         // Tickets/Events
        
        // 健康医疗
        "heart.fill",          // Health
        "cross.case.fill",     // Medical
        "pills.fill",          // Medicine
        "bandage.fill",        // First Aid
        
        // 教育学习
        "book.closed.fill",    // Education
        "graduationcap.fill",  // Graduation
        "pencil.and.outline",  // Writing/Study
        
        // 宠物
        "pawprint.fill",       // Pets
        "cat.fill",            // Cat
        "dog.fill",            // Dog
        
        // 社交
        "envelope.fill",       // Mail/Social
        "message.fill",        // Message
        "person.2.fill",       // Friends/Social
        
        // 收入相关
        "banknote.fill",       // Money/Cash
        "dollarsign.circle.fill", // Money
        "creditcard.fill",     // Credit Card
        "chart.line.uptrend.xyaxis", // Investment
        "briefcase.fill",      // Work/Salary
        "tray.and.arrow.down.fill", // Income
        
        // 其他常用
        "basket.fill",         // Groceries
        "cart.badge.plus",     // Shopping Add
        "star.fill",           // Favorite/Important
        "bell.fill",           // Reminder/Notification
        "calendar",            // Calendar/Events
        "map.fill",            // Location/Travel
        "camera.fill",         // Photo
        "paintbrush.fill",     // Art/Creative
        "wrench.and.screwdriver.fill", // Repair/Maintenance
        "hammer.fill",         // Tools/DIY
        "leaf.fill",           // Nature/Environment
        "sun.max.fill",        // Weather/Outdoor
        "cloud.fill",          // Cloud/Storage
        "lock.fill",           // Security
        "shield.fill",         // Protection/Insurance
        "questionmark.circle.fill", // Other/Unknown
        "ellipsis.circle.fill" // More/Other
    ]
    
    // Grouped by category for better organization
    static let iconGroups: [String: [String]] = [
        "Food": ["fork.knife", "cup.and.saucer.fill", "basket.fill", "wineglass.fill"],
        "Transport": ["car.fill", "tram.fill", "airplane"],
        "Shopping": ["cart.fill", "tshirt.fill", "desktopcomputer", "chair.lounge.fill"],
        "Housing": ["house.fill", "bolt.fill", "wifi"],
        "Entertainment": ["movieclapper.fill", "gamecontroller.fill", "figure.run", "pawprint.fill"],
        "Income": ["banknote.fill", "dollarsign.circle.fill", "chart.line.uptrend.xyaxis", "briefcase.fill", "tray.and.arrow.down.fill"],
        "Other": ["heart.fill", "book.closed.fill", "cross.case.fill", "envelope.fill", "ellipsis.circle.fill"]
    ]
    
    // Get icons by group name
    static func icons(for group: String) -> [String] {
        iconGroups[group] ?? []
    }
    
    // Search icons by keyword
    static func searchIcons(keyword: String) -> [String] {
        commonIcons.filter { icon in
            icon.localizedCaseInsensitiveContains(keyword)
        }
    }
}
