import SwiftUI
import SwiftData
import CloudKit

@main
struct AccountingApp: App {
    var body: some Scene {
        let container = createModelContainer()
        
        WindowGroup {
            ContentView()
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
            
            // Seed default categories on first launch
            // Note: This will only run once per device, not per iCloud account
            // CloudKit will sync the seeded data to other devices
            let context = ModelContext(container)
            DataSeeder.ensureDefaults(context: context)
            
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
}
