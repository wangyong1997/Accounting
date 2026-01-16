import SwiftUI
import SwiftData

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
               let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
            // Seed default categories on first launch
            let context = ModelContext(container)
            DataSeeder.ensureDefaults(context: context)
            
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
}
