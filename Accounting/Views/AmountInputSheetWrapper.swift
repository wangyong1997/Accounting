import SwiftUI
import SwiftData

struct AmountInputSheetWrapper: View {
    let category: Category?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Group {
            if let category = category {
                QuickAddSheet(selectedCategory: category)
            } else {
                // 如果分类为空，显示错误提示
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    
                    Text("分类加载失败")
                        .font(.headline)
                    
                    Text("请重新选择分类")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button("关闭") {
                        dismiss()
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(red: 0.98, green: 0.98, blue: 0.98))
            }
        }
    }
}
