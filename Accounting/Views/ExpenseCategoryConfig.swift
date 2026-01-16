import SwiftUI

struct CategoryConfig {
    let iconName: String
    let color: Color
    
    static let configs: [String: CategoryConfig] = [
        "Food": CategoryConfig(iconName: "cart.fill", color: .orange),
        "Entertainment": CategoryConfig(iconName: "tv.fill", color: .purple),
        "Transport": CategoryConfig(iconName: "car.fill", color: .blue),
        "Health": CategoryConfig(iconName: "heart.fill", color: .red),
        "Bills": CategoryConfig(iconName: "doc.text.fill", color: .green),
        "Shopping": CategoryConfig(iconName: "bag.fill", color: .pink),
        "Other": CategoryConfig(iconName: "pin.fill", color: .gray)
    ]
    
    static func config(for category: String) -> CategoryConfig {
        configs[category] ?? configs["Other"]!
    }
}

let categories = ["Food", "Entertainment", "Transport", "Health", "Bills", "Shopping", "Other"]

func formatDate(_ date: Date) -> String {
    let calendar = Calendar.current
    let today = Date()
    let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
    
    if calendar.isDateInToday(date) {
        return "Today"
    } else if calendar.isDateInYesterday(date) {
        return "Yesterday"
    } else {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
    }
}
