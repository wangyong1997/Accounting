import SwiftUI
import SwiftData
import CloudKit

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
        
        // Configure for CloudKit sync
        // The container identifier is specified in the entitlements file
        // Set cloudKitDatabase to .automatic to enable iCloud sync
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        
        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            
            // Seed default categories and migrate existing data
            // Note: This will only run once per device, not per iCloud account
            // CloudKit will sync the seeded data to other devices
            let context = ModelContext(container)
            DataSeeder.ensureDefaults(context: context)
            
            return container
        } catch {
            // 提供更详细的错误信息
            let errorMessage = """
            Could not create ModelContainer: \(error)
            
            This error usually occurs when the database schema has changed.
            Possible solutions:
            1. Delete the app and reinstall (this will lose all data)
            2. Check if CloudKit is properly configured
            3. Verify the model schema matches the database
            
            Error details: \(error.localizedDescription)
            """
            print("❌ [AccountingApp] \(errorMessage)")
            fatalError(errorMessage)
        }
    }
}
