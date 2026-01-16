import Foundation
import SwiftData

@Model
final class ExpenseItem {
    var amount: Double
    var title: String
    var date: Date
    var category: String
    var accountName: String? // 支付方式（账户名称），可选

    init(amount: Double, title: String, date: Date = .now, category: String, accountName: String? = nil) {
        self.amount = amount
        self.title = title
        self.date = date
        self.category = category
        self.accountName = accountName
    }
}
