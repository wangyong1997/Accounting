import SwiftUI
import SwiftData

@main
struct AccountingApp: App {
    var body: some Scene {
        let container = createModelContainer()
        
        WindowGroup {
            ContentView()
                .onAppear {
                    // 记录应用启动
                    ReviewService.shared.logAppLaunch()
                }
        }
        .modelContainer(container)
    }
    
           private func createModelContainer() -> ModelContainer {
               let schema = Schema([ExpenseItem.self, Category.self, Account.self])
        
        // 本地存储（已关闭 iCloud/CloudKit，同步）
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        
        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            
            // Seed default categories and migrate existing data（仅本机）
            let context = ModelContext(container)
            DataSeeder.ensureDefaults(context: context)
            
            return container
        } catch {
            // 提供更详细的错误信息
            let errorMessage = """
            Could not create ModelContainer: \(error)
            
            This error usually occurs when the local database schema has changed.
            Possible solutions:
            1. Delete the app and reinstall (这会清空本地数据)
            2. 确认 SwiftData 模型与本地存储 schema 一致
            
            Error details: \(error.localizedDescription)
            """
            print("❌ [AccountingApp] \(errorMessage)")
            fatalError(errorMessage)
        }
    }
}
