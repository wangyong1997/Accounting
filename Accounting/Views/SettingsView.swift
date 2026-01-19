import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query(sort: \ExpenseItem.date, order: .reverse) private var expenses: [ExpenseItem]
    
    // Settings
    @AppStorage("useCloud") private var useCloud = false
    @AppStorage("useFaceID") private var useFaceID = false
    @AppStorage("userNickname") private var userNickname = ""
    @AppStorage("hasCleanedMockData") private var hasCleanedMockData = false
    
    // Streak tracking
    @AppStorage("lastAppOpenDate") private var lastAppOpenDateTimestamp: TimeInterval = 0
    @AppStorage("currentStreak") private var currentStreak = 0
    
    // UI State
    @State private var showCategoryManagement = false
    @State private var showResetConfirmation = false
    @State private var showImportView = false
    @State private var showAppIconView = false
    @State private var showFileImporter = false
    @State private var importResult: CSVImporter.ImportResult?
    @State private var showImportResultAlert = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Section 1: Header (Gamification)
                Section {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                                .font(.title2)
                            Text("连续使用: \(currentStreak) 天")
                                .font(.headline)
                        }
                        Text("数据存储在本地设备")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                
                // Section 2: Data Management
                Section {
                    Toggle(isOn: $useCloud) {
                        Label("iCloud 同步", systemImage: "cloud.fill")
                    }
                    
                    ShareLink(item: exportFile, preview: SharePreview("PixelLedger 数据备份", icon: "doc.text.fill")) {
                        Label("导出到 CSV", systemImage: "square.and.arrow.up")
                    }
                    .disabled(expenses.isEmpty)
                    
                    Button(action: {
                        showFileImporter = true
                    }) {
                        Label("导入 CSV", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("数据管理")
                }
                
                // Section 3: Privacy & Security
                Section {
                    Toggle(isOn: $useFaceID) {
                        Label("使用 Face ID 解锁", systemImage: "faceid")
                    }
                } header: {
                    Text("隐私与安全")
                }
                
                // Section 4: Personalization
                Section {
                    NavigationLink(destination: AppIconView()) {
                        Label("应用图标", systemImage: "app.fill")
                    }
                    
                    HStack {
                        Label("称呼我", systemImage: "person.circle.fill")
                        Spacer()
                        TextField("输入昵称", text: $userNickname)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 150)
                    }
                } header: {
                    Text("个性化")
                }
                
                // Section 5: App Settings
                Section {
                    Button(action: {
                        showCategoryManagement = true
                    }) {
                        Label("分类管理", systemImage: "tag.fill")
                    }
                } header: {
                    Text("应用设置")
                }
                
                // Section 6: Data Management (Danger Zone)
                Section {
                    Button(role: .destructive, action: {
                        showResetConfirmation = true
                    }) {
                        Label("重置所有数据", systemImage: "trash.fill")
                    }
                } header: {
                    Text("数据管理")
                } footer: {
                    Text("此操作将删除所有账单、分类和账户数据，且无法恢复。")
                }
                
                // Section 7: About
                Section {
                    HStack {
                        Label("版本", systemImage: "info.circle.fill")
                    Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: {
                        rateApp()
                    }) {
                        Label("评价应用", systemImage: "star.fill")
                    }
                } header: {
                    Text("关于")
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)
            .listStyle(.insetGrouped)
        }
        .sheet(isPresented: $showCategoryManagement) {
            CategoryManagementView()
        }
        .alert("重置所有数据", isPresented: $showResetConfirmation) {
            Button("取消", role: .cancel) { }
            Button("确认重置", role: .destructive) {
                resetAllData()
            }
        } message: {
            Text("此操作将删除所有账单、分类和账户数据，且无法恢复。确定要继续吗？")
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result: result)
        }
        .alert("导入完成", isPresented: $showImportResultAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            if let result = importResult {
                Text("导入完成。\n成功: \(result.success) 条\n失败: \(result.failed) 条")
                } else {
                Text("导入失败")
            }
        }
        .onAppear {
            updateStreak()
            // 只在首次启动时清理一次模拟数据
            if !hasCleanedMockData {
                hasCleanedMockData = true
            }
        }
    }
    
    // MARK: - App Version
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version) (\(build))"
    }
    
    // MARK: - Streak Management
    private func updateStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if lastAppOpenDateTimestamp > 0 {
            let lastDate = calendar.startOfDay(for: Date(timeIntervalSince1970: lastAppOpenDateTimestamp))
            let daysDifference = calendar.dateComponents([.day], from: lastDate, to: today).day ?? 0
            
            if daysDifference == 0 {
                // Same day, no update needed
                return
            } else if daysDifference == 1 {
                // Consecutive day
                currentStreak += 1
            } else {
                // Streak broken
                currentStreak = 1
            }
        } else {
            // First time opening
            currentStreak = 1
        }
        
        // Update last open date
        lastAppOpenDateTimestamp = Date().timeIntervalSince1970
    }
    
    // MARK: - Export Data
    /// 生成导出文件
    private var exportFile: ExpenseExportFile {
        ExpenseExportFile.create(expenses: expenses, categories: categories)
    }
    
    // MARK: - Rate App
    private func rateApp() {
        // TODO: Open App Store rating page
        print("⭐ [SettingsView] Rate App")
    }
    
    // MARK: - Import CSV
    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                print("❌ [SettingsView] 未选择文件")
                return
            }
            
            // 在后台线程执行导入（避免阻塞 UI）
            Task {
                do {
                    // 在主线程的 ModelContext 上执行（SwiftData 要求）
                    await MainActor.run {
                        do {
                            let result = try CSVImporter.importCSV(url: url, context: modelContext)
                            importResult = result
                            showImportResultAlert = true
                            print("✅ [SettingsView] 导入成功: \(result.success) 条，失败: \(result.failed) 条")
                        } catch {
                            print("❌ [SettingsView] 导入失败: \(error.localizedDescription)")
                            importResult = CSVImporter.ImportResult(success: 0, failed: 0)
                            showImportResultAlert = true
                        }
                    }
                }
            }
            
        case .failure(let error):
            print("❌ [SettingsView] 文件选择失败: \(error.localizedDescription)")
            importResult = CSVImporter.ImportResult(success: 0, failed: 0)
            showImportResultAlert = true
        }
    }
    
    // MARK: - Reset All Data
    private func resetAllData() {
        // 删除所有账单
        for expense in expenses {
            modelContext.delete(expense)
        }
        
        // 删除所有自定义分类（保留默认分类会在下次启动时自动创建）
        for category in categories {
            modelContext.delete(category)
        }
        
        // 删除所有账户（保留默认账户会在下次启动时自动创建）
        for account in accounts {
            modelContext.delete(account)
        }
        
        // 保存更改
        try? modelContext.save()
        
        // 重新初始化默认数据
        DataSeeder.ensureDefaults(context: modelContext)
        
        print("🔄 [SettingsView] 已重置所有数据")
    }
}

// MARK: - Placeholder Views
struct ImportDataView: View {
    var body: some View {
        Form {
            Section {
                Text("导入数据功能")
                    .foregroundColor(.secondary)
            } header: {
                Text("导入数据")
            } footer: {
                Text("此功能正在开发中")
            }
        }
        .navigationTitle("导入数据")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AppIconView: View {
    var body: some View {
            Form {
                Section {
                Text("应用图标设置")
                    .foregroundColor(.secondary)
                } header: {
                Text("应用图标")
                } footer: {
                Text("此功能正在开发中")
            }
        }
        .navigationTitle("应用图标")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [ExpenseItem.self, Category.self, Account.self], inMemory: true)
}
