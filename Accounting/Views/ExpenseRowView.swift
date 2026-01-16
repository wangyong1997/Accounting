import SwiftUI
import SwiftData

struct ExpenseRowView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allCategories: [Category]
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    
    let expense: ExpenseItem
    let isLast: Bool
    let onDelete: () -> Void
    
    // 根据分类名称查找对应的 Category 对象
    private var category: Category? {
        allCategories.first { $0.name == expense.category }
    }
    
    // 根据账户名称查找对应的 Account 对象
    private var account: Account? {
        guard let accountName = expense.accountName else { return nil }
        return accounts.first { $0.name == accountName }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // 分类图标
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(category?.color ?? Color.gray)
                    .frame(width: 48, height: 48)
                
                Image(systemName: category?.symbolName ?? "questionmark.circle.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 24))
            }
            
            // 费用信息
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(expense.category)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let account = account {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 4) {
                            Image(systemName: account.iconName)
                                .font(.system(size: 10))
                                .foregroundColor(account.color)
                            
                            Text(account.name)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // 金额和删除按钮
            HStack(spacing: 8) {
                // 根据分类类型显示 "+" 或 "-"
                let isIncome = category?.categoryType == .income
                let prefix = isIncome ? "+" : "-"
                let amountColor: Color = isIncome ? .green : .primary
                
                Text("\(prefix)\(expense.amount, format: .currency(code: "CNY"))")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(amountColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.system(size: 16))
                        .frame(width: 32, height: 32)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color.white)
        .overlay(
            Group {
                if !isLast {
                    Divider()
                        .padding(.leading, 80)
                }
            },
            alignment: .bottom
        )
    }
}
