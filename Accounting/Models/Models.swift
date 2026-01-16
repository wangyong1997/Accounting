import Foundation
import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Category Type Enum
enum CategoryType: String, Codable {
    case expense = "Expense"
    case income = "Income"
}

// MARK: - Account Type Enum
enum AccountType: String, Codable, CaseIterable {
    case cash = "cash"
    case debitCard = "debitCard"
    case creditCard = "creditCard"
    case ewallet = "ewallet"
    case investment = "investment"
    case renovation = "renovation"
    case other = "other"
}

// MARK: - Category Model
@Model
final class Category: Identifiable {
    var id: UUID
    var name: String
    var symbolName: String
    var hexColor: String
    var type: String // Store as String for SwiftData compatibility
    var createdAt: Date
    
    init(id: UUID = UUID(), name: String, symbolName: String, hexColor: String, type: CategoryType, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.hexColor = hexColor
        self.type = type.rawValue
        self.createdAt = createdAt
    }
    
    // Computed property for type
    var categoryType: CategoryType {
        get {
            CategoryType(rawValue: type) ?? .expense
        }
        set {
            type = newValue.rawValue
        }
    }
    
    // Helper to convert hex color to SwiftUI Color
    var color: Color {
        Color(hex: hexColor)
    }
}

// MARK: - Account Model
@Model
final class Account: Identifiable {
    var id: UUID
    var name: String
    var balance: Double
    var type: String // Store as String for SwiftData compatibility
    var hexColor: String
    var iconName: String
    var createdAt: Date
    
    init(id: UUID = UUID(), name: String, balance: Double = 0.0, type: AccountType, hexColor: String, iconName: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.balance = balance
        self.type = type.rawValue
        self.hexColor = hexColor
        self.iconName = iconName
        self.createdAt = createdAt
    }
    
    // Computed property for type
    var accountType: AccountType {
        get {
            AccountType(rawValue: type) ?? .cash
        }
        set {
            type = newValue.rawValue
        }
    }
    
    // Helper to convert hex color to SwiftUI Color
    var color: Color {
        Color(hex: hexColor)
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    func toHex() -> String {
        #if canImport(UIKit)
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return "#000000"
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
        #else
        return "#000000"
        #endif
    }
}
