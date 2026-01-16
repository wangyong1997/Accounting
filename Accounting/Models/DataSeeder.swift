import Foundation
import SwiftData
import SwiftUI

struct DataSeeder {
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
        
        // Food Group (Orange #FF9500)
        categories.append(Category(name: "餐饮", symbolName: "fork.knife", hexColor: "#FF9500", type: .expense))
        categories.append(Category(name: "零食", symbolName: "cup.and.saucer.fill", hexColor: "#FF9500", type: .expense))
        categories.append(Category(name: "杂货", symbolName: "basket.fill", hexColor: "#FF9500", type: .expense))
        categories.append(Category(name: "酒精", symbolName: "wineglass.fill", hexColor: "#FF9500", type: .expense))
        
        // Transport Group (Blue #007AFF)
        categories.append(Category(name: "公共交通", symbolName: "tram.fill", hexColor: "#007AFF", type: .expense))
        categories.append(Category(name: "出租车", symbolName: "car.fill", hexColor: "#007AFF", type: .expense))
        categories.append(Category(name: "旅行", symbolName: "airplane", hexColor: "#007AFF", type: .expense))
        
        // Shopping Group (Red #FF2D55)
        categories.append(Category(name: "日常需求", symbolName: "cart.fill", hexColor: "#FF2D55", type: .expense))
        categories.append(Category(name: "衣服", symbolName: "tshirt.fill", hexColor: "#FF2D55", type: .expense))
        categories.append(Category(name: "电子产品", symbolName: "desktopcomputer", hexColor: "#FF2D55", type: .expense))
        categories.append(Category(name: "家具", symbolName: "chair.lounge.fill", hexColor: "#FF2D55", type: .expense))

        // Housing Group (Green #34C759)
        categories.append(Category(name: "房租/房贷", symbolName: "house.fill", hexColor: "#34C759", type: .expense))
        categories.append(Category(name: "水电费", symbolName: "bolt.fill", hexColor: "#34C759", type: .expense))
        categories.append(Category(name: "网络", symbolName: "wifi", hexColor: "#34C759", type: .expense))
        
        // Entertainment Group (Purple #AF52DE)
        categories.append(Category(name: "电影", symbolName: "movieclapper.fill", hexColor: "#AF52DE", type: .expense))
        categories.append(Category(name: "游戏", symbolName: "gamecontroller.fill", hexColor: "#AF52DE", type: .expense))
        categories.append(Category(name: "运动", symbolName: "figure.run", hexColor: "#AF52DE", type: .expense))
        categories.append(Category(name: "宠物", symbolName: "pawprint.fill", hexColor: "#AF52DE", type: .expense))
        
        // Medical & Others Group (Gray #8E8E93)
        categories.append(Category(name: "医疗", symbolName: "cross.case.fill", hexColor: "#8E8E93", type: .expense))
        categories.append(Category(name: "教育", symbolName: "book.closed.fill", hexColor: "#8E8E93", type: .expense))
        categories.append(Category(name: "社交", symbolName: "envelope.fill", hexColor: "#8E8E93", type: .expense))
        categories.append(Category(name: "其他", symbolName: "ellipsis.circle.fill", hexColor: "#8E8E93", type: .expense))
        
        // MARK: - Income Categories (Gold #FFCC00)
        categories.append(Category(name: "工资", symbolName: "banknote.fill", hexColor: "#FFCC00", type: .income))
        categories.append(Category(name: "奖金", symbolName: "dollarsign.circle.fill", hexColor: "#FFCC00", type: .income))
        categories.append(Category(name: "投资", symbolName: "chart.line.uptrend.xyaxis", hexColor: "#FFCC00", type: .income))
        categories.append(Category(name: "兼职", symbolName: "briefcase.fill", hexColor: "#FFCC00", type: .income))
        categories.append(Category(name: "其他收入", symbolName: "tray.and.arrow.down.fill", hexColor: "#FFCC00", type: .income))
        
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
        "cart.fill",           // Shopping
        "fork.knife",          // Dining
        "car.fill",            // Transport
        "house.fill",          // Housing
        "bolt.fill",           // Utilities
        "wifi",                // Internet
        "gamecontroller.fill", // Entertainment
        "heart.fill",          // Health
        "book.closed.fill",    // Education
        "banknote.fill",       // Income
        "dollarsign.circle.fill", // Money
        "chart.line.uptrend.xyaxis", // Investment
        "briefcase.fill",      // Work
        "airplane",            // Travel
        "pawprint.fill",       // Pets
        "movieclapper.fill",   // Movies
        "basket.fill",         // Groceries
        "cup.and.saucer.fill", // Snacks
        "wineglass.fill",      // Alcohol
        "tshirt.fill",         // Clothes
        "desktopcomputer",     // Electronics
        "chair.lounge.fill",   // Furniture
        "tram.fill",           // Public Transit
        "cross.case.fill",     // Medical
        "envelope.fill",       // Social
        "ellipsis.circle.fill" // Other
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
