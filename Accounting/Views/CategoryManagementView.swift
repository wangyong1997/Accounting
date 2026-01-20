import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct CategoryManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Category.name) private var allCategories: [Category]
    
    @State private var showAddCategory = false
    @State private var categoryToEdit: Category?
    
    var expenseCategories: [Category] {
        allCategories.filter { $0.categoryType == .expense }
    }
    
    var incomeCategories: [Category] {
        allCategories.filter { $0.categoryType == .income }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.98, green: 0.98, blue: 0.98)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 支出分类
                        if !expenseCategories.isEmpty {
                            categorySection(title: "支出分类", categories: expenseCategories)
                        }
                        
                        // 收入分类
                        if !incomeCategories.isEmpty {
                            categorySection(title: "收入分类", categories: incomeCategories)
                        }
                        
                        // 空状态
                        if allCategories.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "tag.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.gray.opacity(0.5))
                                
                                Text("暂无分类")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Text("点击右上角添加按钮创建分类")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("分类管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("完成") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showAddCategory = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
            }
            .sheet(isPresented: $showAddCategory) {
                AddCategorySheet()
            }
            .sheet(item: $categoryToEdit) { category in
                EditCategorySheet(category: category)
            }
            .onAppear {
                DataSeeder.ensureDefaults(context: modelContext)
            }
        }
    }
    
    // MARK: - 分类分组
    private func categorySection(title: String, categories: [Category]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                    categoryRow(category: category)
                        .overlay(
                            Group {
                                if index < categories.count - 1 {
                                    Divider()
                                        .padding(.leading, 68)
                                }
                            },
                            alignment: .bottom
                        )
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
    }
    
    // MARK: - 分类行
    private func categoryRow(category: Category) -> some View {
        HStack(spacing: 16) {
            // 图标
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(category.color)
                    .frame(width: 40, height: 40)
                
                Image(systemName: category.symbolName)
                    .foregroundColor(.white)
                    .font(.system(size: 18))
            }
            
            // 名称
            Text(category.name)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
            
            // 编辑按钮
            Button(action: {
                categoryToEdit = category
            }) {
                Image(systemName: "pencil")
                    .foregroundColor(.blue)
                    .font(.system(size: 16))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.white)
        .contextMenu {
            Button {
                categoryToEdit = category
            } label: {
                Label("编辑", systemImage: "pencil")
            }
            
            Divider()
            
            Button(role: .destructive) {
                deleteCategory(category)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }
    
    // MARK: - 删除分类
    private func deleteCategory(_ category: Category) {
        modelContext.delete(category)
        try? modelContext.save()
    }
}

// MARK: - 添加分类 Sheet
struct AddCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var name: String = ""
    @State private var selectedColor: Color = .blue
    @State private var selectedIconName: String = "tag.fill"
    @State private var selectedType: CategoryType = .expense
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // 预览（放在最上面）
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedColor)
                                .frame(width: 48, height: 48)
                            
                            Image(systemName: selectedIconName)
                                .foregroundColor(.white)
                                .font(.system(size: 24))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(name.isEmpty ? "分类名称" : name)
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text(selectedType == .expense ? "支出" : "收入")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(16)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } header: {
                    Text("预览")
                }
                
                Section("分类信息") {
                    TextField("分类名称", text: $name)
                    
                    Picker("类型", selection: $selectedType) {
                        Text("支出").tag(CategoryType.expense)
                        Text("收入").tag(CategoryType.income)
                    }
                }
                
                Section("外观设置") {
                    // 颜色选择器
                    HStack {
                        Text("颜色")
                        Spacer()
                        ColorPicker("", selection: $selectedColor)
                            .labelsHidden()
                    }
                    
                    // 图标预览
                    HStack {
                        Text("图标")
                        Spacer()
                        Image(systemName: selectedIconName)
                            .font(.title2)
                            .foregroundColor(selectedColor)
                            .frame(width: 40, height: 40)
                            .background(selectedColor.opacity(0.2))
                            .clipShape(Circle())
                    }
                    
                    // 常用图标快捷选择（换行显示）
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        ForEach(QuickAccessIcons.commonIcons, id: \.self) { iconName in
                                Button(action: {
                                    selectedIconName = iconName
                                }) {
                                    Image(systemName: iconName)
                                        .font(.title3)
                                        .foregroundColor(selectedIconName == iconName ? .white : selectedColor)
                                        .frame(width: 44, height: 44)
                                        .background(selectedIconName == iconName ? selectedColor : selectedColor.opacity(0.2))
                                        .clipShape(Circle())
                                }
                            }
                        }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("添加分类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveCategory()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func saveCategory() {
        let newCategory = Category(
            name: name,
            symbolName: selectedIconName,
            hexColor: selectedColor.toHex(),
            type: selectedType
        )
        
        modelContext.insert(newCategory)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - 编辑分类 Sheet
struct EditCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var category: Category
    @State private var name: String
    @State private var selectedColor: Color
    @State private var selectedIconName: String
    @State private var selectedType: CategoryType
    
    init(category: Category) {
        self.category = category
        _name = State(initialValue: category.name)
        _selectedColor = State(initialValue: category.color)
        _selectedIconName = State(initialValue: category.symbolName)
        _selectedType = State(initialValue: category.categoryType)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // 预览（放在最上面）
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedColor)
                                .frame(width: 48, height: 48)
                            
                            Image(systemName: selectedIconName)
                                .foregroundColor(.white)
                                .font(.system(size: 24))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(name.isEmpty ? "分类名称" : name)
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text(selectedType == .expense ? "支出" : "收入")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(16)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } header: {
                    Text("预览")
                }
                
                Section("分类信息") {
                    TextField("分类名称", text: $name)
                    
                    Picker("类型", selection: $selectedType) {
                        Text("支出").tag(CategoryType.expense)
                        Text("收入").tag(CategoryType.income)
                    }
                }
                
                Section("外观设置") {
                    // 颜色选择器
                    HStack {
                        Text("颜色")
                        Spacer()
                        ColorPicker("", selection: $selectedColor)
                            .labelsHidden()
                    }
                    
                    // 图标预览
                    HStack {
                        Text("图标")
                        Spacer()
                        Image(systemName: selectedIconName)
                            .font(.title2)
                            .foregroundColor(selectedColor)
                            .frame(width: 40, height: 40)
                            .background(selectedColor.opacity(0.2))
                            .clipShape(Circle())
                    }
                    
                    // 常用图标快捷选择（换行显示）
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        ForEach(QuickAccessIcons.commonIcons, id: \.self) { iconName in
                                Button(action: {
                                    selectedIconName = iconName
                                }) {
                                    Image(systemName: iconName)
                                        .font(.title3)
                                        .foregroundColor(selectedIconName == iconName ? .white : selectedColor)
                                        .frame(width: 44, height: 44)
                                        .background(selectedIconName == iconName ? selectedColor : selectedColor.opacity(0.2))
                                        .clipShape(Circle())
                                }
                            }
                        }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("编辑分类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveChanges()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func saveChanges() {
        category.name = name
        category.hexColor = selectedColor.toHex()
        category.symbolName = selectedIconName
        category.categoryType = selectedType
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Category.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = ModelContext(container)
    DataSeeder.ensureDefaults(context: context)
    
    return CategoryManagementView()
        .modelContainer(container)
}
