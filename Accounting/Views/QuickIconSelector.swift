import SwiftUI
import SwiftData

struct QuickIconSelector: View {
    @Query(sort: \Category.name) private var allCategories: [Category]
    @Binding var selectedCategory: Category?
    @State private var searchText: String = ""
    @State private var selectedGroup: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 搜索栏
            searchBar
            
            // 常用图标快捷组
            quickAccessSection
            
            // 所有分类列表
            allCategoriesSection
        }
    }
    
    // MARK: - 搜索栏
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("搜索分类或图标", text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - 常用图标快捷组
    private var quickAccessSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("常用图标")
                .font(.headline)
                .foregroundColor(.primary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(QuickAccessIcons.commonIcons.prefix(12), id: \.self) { iconName in
                        quickIconButton(iconName: iconName)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    private func quickIconButton(iconName: String) -> some View {
        Button(action: {
            // Find category with this icon or create a temporary selection
            if let category = allCategories.first(where: { $0.symbolName == iconName }) {
                selectedCategory = category
            }
        }) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(selectedCategory?.symbolName == iconName ? .white : .primary)
                .frame(width: 50, height: 50)
                .background(
                    selectedCategory?.symbolName == iconName
                        ? selectedCategory?.color ?? Color.blue
                        : Color.gray.opacity(0.1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - 所有分类列表
    private var allCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("所有分类")
                .font(.headline)
                .foregroundColor(.primary)
            
            let filteredCategories = filteredCategoriesList
            
            if filteredCategories.isEmpty {
                Text("未找到匹配的分类")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(filteredCategories) { category in
                        categoryButton(category: category)
                    }
                }
            }
        }
    }
    
    private func categoryButton(category: Category) -> some View {
        Button(action: {
            selectedCategory = category
        }) {
            VStack(spacing: 8) {
                Image(systemName: category.symbolName)
                    .font(.title2)
                    .foregroundColor(selectedCategory?.id == category.id ? .white : category.color)
                
                Text(category.name)
                    .font(.caption)
                    .foregroundColor(selectedCategory?.id == category.id ? .white : .primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                selectedCategory?.id == category.id
                    ? category.color
                    : Color.white
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedCategory?.id == category.id ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    // MARK: - 计算属性
    private var filteredCategoriesList: [Category] {
        var categories = allCategories
        
        // Filter by search text
        if !searchText.isEmpty {
            categories = categories.filter { category in
                category.name.localizedCaseInsensitiveContains(searchText) ||
                category.symbolName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Filter by group if selected
        if let group = selectedGroup {
            let groupIcons = QuickAccessIcons.icons(for: group)
            categories = categories.filter { groupIcons.contains($0.symbolName) }
        }
        
        return categories
    }
}

#Preview {
    QuickIconSelector(selectedCategory: .constant(nil))
        .modelContainer(for: [Category.self], inMemory: true)
}
