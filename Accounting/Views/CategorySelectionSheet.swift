import SwiftUI
import SwiftData

struct CategorySelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Category.name) private var allCategories: [Category]
    @Binding var selectedCategory: Category?
    var onCategorySelected: (Category) -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.98, green: 0.98, blue: 0.98)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // 标题
                        Text("选择分类")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                        
                        // 只显示支出分类
                        let expenseCategories = allCategories.filter { $0.categoryType == .expense }
                        
                        if expenseCategories.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "tray.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.gray.opacity(0.5))
                                
                                Text("暂无分类")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Text("请先添加分类")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                        } else {
                            // 分类网格
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ], spacing: 16) {
                                ForEach(expenseCategories) { category in
                                    categoryButton(category: category)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            .navigationTitle("选择分类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // 确保默认分类已加载
                DataSeeder.ensureDefaults(context: modelContext)
            }
        }
    }
    
    private func categoryButton(category: Category) -> some View {
        Button(action: {
            // 输出选择的分类
            print("📌 [CategorySelectionSheet] 用户选择了分类: \(category.name) (ID: \(category.id))")
            
            // 先更新选中状态（虽然 binding 是 constant，但保持一致性）
            selectedCategory = category
            // 先执行回调，确保状态更新
            onCategorySelected(category)
            // 然后关闭页面
            dismiss()
        }) {
            VStack(spacing: 12) {
                ZStack {
                    // 选中状态的背景圆圈
                    if selectedCategory?.id == category.id {
                        Circle()
                            .fill(category.color.opacity(0.2))
                            .frame(width: 60, height: 60)
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    // 图标
                    Image(systemName: category.symbolName)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(selectedCategory?.id == category.id ? category.color : category.color.opacity(0.7))
                        .scaleEffect(selectedCategory?.id == category.id ? 1.1 : 1.0)
                }
                .frame(height: 60)
                
                // 分类名称
                Text(category.name)
                    .font(.system(size: 13, weight: selectedCategory?.id == category.id ? .semibold : .regular))
                    .foregroundColor(selectedCategory?.id == category.id ? category.color : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                selectedCategory?.id == category.id
                    ? category.color.opacity(0.1)
                    : Color.white
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        selectedCategory?.id == category.id
                            ? category.color.opacity(0.5)
                            : Color.gray.opacity(0.2),
                        lineWidth: selectedCategory?.id == category.id ? 2 : 1
                    )
            )
            .shadow(
                color: selectedCategory?.id == category.id
                    ? category.color.opacity(0.2)
                    : .black.opacity(0.05),
                radius: selectedCategory?.id == category.id ? 8 : 4,
                x: 0,
                y: 2
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var selectedCategory: Category? = nil
        
        var body: some View {
            CategorySelectionSheet(
                selectedCategory: $selectedCategory,
                onCategorySelected: { _ in }
            )
        }
    }
    
    return PreviewWrapper()
        .modelContainer(for: [Category.self], inMemory: true)
}
