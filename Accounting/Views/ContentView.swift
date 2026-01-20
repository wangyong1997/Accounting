import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedTab: TabItem = .timeline
    @State private var showCategorySheet = false
    @State private var showAmountSheet = false
    @State private var categoryForAmountInput: Category?
    @State private var scrollToTopTrigger = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // 内容视图
            Group {
                switch selectedTab {
                case .timeline:
                    TimelineView(scrollToTopTrigger: $scrollToTopTrigger)
                case .analysis:
                    AnalysisView()
                case .assets:
                    AssetsView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 80) // 为底部导航栏留出空间
            
            // 自定义 Tab Bar
            CustomTabBar(selectedTab: $selectedTab, onQuickAdd: {
                showCategorySheet = true
            }, onTimelineDoubleTap: {
                if selectedTab == .timeline {
                    scrollToTopTrigger.toggle()
                }
            })
            .ignoresSafeArea(.keyboard, edges: .bottom)
            
            // 全局悬浮语音入口（跨页面可见）
            FloatingVoiceAssistant()
                .zIndex(1000)
        }
        .sheet(isPresented: $showCategorySheet) {
            CategorySelectionSheet(
                selectedCategory: .constant(nil),
                onCategorySelected: { category in
                    // 输出接收到的分类
                    print("✅ [ContentView] 接收到选择的分类: \(category.name) (ID: \(category.id))")
                    print("   - 图标: \(category.symbolName)")
                    print("   - 颜色: \(category.hexColor)")
                    print("   - 类型: \(category.categoryType)")
                    
                    // 先关闭分类选择页面
                    showCategorySheet = false
                    
                    // 延迟一点，确保分类选择页面完全关闭后再设置 category
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        // 设置分类，这会触发 sheet(item:) 显示金额输入页面
                        categoryForAmountInput = category
                        print("   - categoryForAmountInput 已设置为: \(categoryForAmountInput?.name ?? "nil")")
                    }
                }
            )
        }
        .sheet(item: $categoryForAmountInput) { category in
            // 使用 sheet(item:) 确保 category 在显示时一定存在
            QuickAddSheet(selectedCategory: category)
                .onAppear {
                    print("📱 [ContentView] 显示金额输入页面，分类: \(category.name)")
                }
                .onDisappear {
                    print("📱 [ContentView] 金额输入页面已关闭")
                    // 关闭时清空分类，以便下次重新选择
                    // categoryForAmountInput 会在 sheet 关闭时自动设置为 nil
                }
        }
        .onAppear {
            // 确保默认分类已加载
            DataSeeder.ensureDefaults(context: modelContext)
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: ExpenseItem.self, Category.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = ModelContext(container)
    DataSeeder.ensureDefaults(context: context)
    
    return ContentView()
        .modelContainer(container)
}
