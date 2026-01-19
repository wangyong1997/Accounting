import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct AssetsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    
    @State private var showEditAccount: Account?
    @State private var showAdjustBalance: Account?
    @State private var showTransfer: Account?
    @State private var showAddAccount = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色
                Color(red: 0.98, green: 0.98, blue: 0.98)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 头部统计卡片
                        headerCard
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                        
                        // 操作提示
                        operationHint
                            .padding(.horizontal, 16)
                        
                        // 账户列表
                        accountCards
                            .padding(.horizontal, 16)
                            .padding(.bottom, 100)
                    }
                }
            }
            .navigationTitle("资产")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showAddAccount = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
            }
        }
        .onAppear {
            // 确保默认账户已加载
            DataSeeder.ensureDefaults(context: modelContext)
            
            // 调试：打印账户数量
            print("📊 [AssetsView] 账户数量: \(accounts.count)")
            for account in accounts {
                print("   - \(account.name): ¥\(account.balance)")
            }
        }
        .onChange(of: accounts.count) { oldValue, newValue in
            // 当账户数量变化时，打印调试信息
            print("📊 [AssetsView] 账户数量变化: \(oldValue) -> \(newValue)")
        }
        .sheet(item: $showEditAccount) { account in
            EditAccountSheet(account: account)
        }
        .sheet(item: $showAdjustBalance) { account in
            AdjustBalanceSheet(account: account)
        }
        .sheet(item: $showTransfer) { account in
            TransferSheet(fromAccount: account, allAccounts: accounts)
        }
        .sheet(isPresented: $showAddAccount) {
            AddAccountSheet()
        }
    }
    
    // MARK: - 删除账户
    private func deleteAccount(_ account: Account) {
        modelContext.delete(account)
        try? modelContext.save()
    }
    
    // MARK: - 头部统计卡片
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("总净资产")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.9))
            
            Text("¥\(totalNetWorth, specifier: "%.2f")")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .fixedSize(horizontal: false, vertical: true)
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("总资产")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    Text("¥\(totalAssets, specifier: "%.2f")")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("总负债")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    Text("¥\(abs(totalLiabilities), specifier: "%.2f")")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(
            LinearGradient(
                colors: [Color.indigo, Color.purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 4)
    }
    
    // MARK: - 操作提示
    private var operationHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .font(.caption)
                .foregroundColor(.blue)
            
            Text("长按账户卡片可编辑、调整余额或转账")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - 账户卡片列表
    private var accountCards: some View {
        Group {
            if accounts.isEmpty {
                // 空状态
                VStack(spacing: 16) {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("暂无账户")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("账户数据正在加载中...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                VStack(spacing: 16) {
                    ForEach(accounts) { account in
                        accountCard(account: account)
                            .contextMenu {
                                Button {
                                    showEditAccount = account
                                } label: {
                                    Label("编辑", systemImage: "pencil")
                                }
                                
                                Button {
                                    showAdjustBalance = account
                                } label: {
                                    Label("调整余额", systemImage: "equal.circle")
                                }
                                
                                Button {
                                    showTransfer = account
                                } label: {
                                    Label("转账", systemImage: "arrow.left.arrow.right")
                                }
                                
                                Divider()
                                
                                Button(role: .destructive) {
                                    deleteAccount(account)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
    }
    
    // MARK: - 账户卡片
    private func accountCard(account: Account) -> some View {
        HStack(spacing: 16) {
            // 图标
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 56, height: 56)
                
                Image(systemName: account.iconName)
                    .foregroundColor(.white)
                    .font(.system(size: 28))
                    .imageScale(.large)
            }
            
            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text(account.name)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(accountTypeName(account.accountType))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
                    // 余额
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("¥\(account.balance, specifier: "%.2f")")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .fixedSize(horizontal: false, vertical: true)
                    }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [account.color, account.color.opacity(0.7)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: account.color.opacity(0.3), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - 计算属性
    private var totalAssets: Double {
        let assets = accounts.filter { $0.balance >= 0 }.reduce(0) { $0 + $1.balance }
        return assets
    }
    
    private var totalLiabilities: Double {
        let liabilities = accounts.filter { $0.balance < 0 }.reduce(0) { $0 + $1.balance }
        return liabilities
    }
    
    private var totalNetWorth: Double {
        let netWorth = accounts.reduce(0) { $0 + $1.balance }
        return netWorth
    }
    
    // MARK: - 辅助方法
    private func accountTypeName(_ type: AccountType) -> String {
        switch type {
        case .cash: return "现金"
        case .debitCard: return "借记卡"
        case .creditCard: return "信用卡"
        case .ewallet: return "电子钱包"
        case .investment: return "投资"
        case .renovation: return "装修"
        case .other: return "其他"
        }
    }
}

// MARK: - 添加账户 Sheet
struct AddAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var name: String = ""
    @State private var selectedColor: Color = .blue
    @State private var selectedIconName: String = "creditcard.fill"
    @State private var selectedAccountType: AccountType = .cash
    @State private var initialBalance: String = "0.00"
    
    var body: some View {
        NavigationView {
            Form {
                Section("账户信息") {
                    TextField("账户名称", text: $name)
                    
                    Picker("账户类型", selection: $selectedAccountType) {
                        ForEach(AccountType.allCases, id: \.self) { type in
                            Text(accountTypeName(type)).tag(type)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("初始余额")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextField("0.00", text: $initialBalance)
                            .keyboardType(.decimalPad)
                            .onChange(of: initialBalance) { oldValue, newValue in
                                let formatted = formatBalanceInput(newValue)
                                if formatted != newValue {
                                    initialBalance = formatted
                                }
                            }
                    }
                    .padding(.top, 8)
                }
                
                Section("外观设置") {
                    // 颜色选择器
                    HStack {
                        Text("颜色")
                        Spacer()
                        ColorPicker("", selection: $selectedColor)
                            .labelsHidden()
                    }
                    
                    // 图标预览和选择
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
                    
                    // 常用图标快捷选择
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(commonAccountIcons, id: \.self) { iconName in
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
                        .padding(.horizontal, 4)
                    }
                }
                
                Section {
                    // 预览卡片
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.3))
                                .frame(width: 56, height: 56)
                            
                            Image(systemName: selectedIconName)
                                .foregroundColor(.white)
                                .font(.system(size: 28))
                                .imageScale(.large)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(name.isEmpty ? "账户名称" : name)
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            Text(accountTypeName(selectedAccountType))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Spacer()
                    }
                    .padding(20)
                    .background(
                        LinearGradient(
                            colors: [selectedColor, selectedColor.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                } header: {
                    Text("预览")
                }
            }
            .navigationTitle("添加账户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveAccount()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func saveAccount() {
        let balance = Double(initialBalance) ?? 0.0
        let roundedBalance = (balance * 100).rounded() / 100
        
        let newAccount = Account(
            name: name,
            balance: roundedBalance,
            type: selectedAccountType,
            hexColor: selectedColor.toHex(),
            iconName: selectedIconName
        )
        
        modelContext.insert(newAccount)
        try? modelContext.save()
        dismiss()
    }
    
    private func accountTypeName(_ type: AccountType) -> String {
        switch type {
        case .cash: return "现金"
        case .debitCard: return "借记卡"
        case .creditCard: return "信用卡"
        case .ewallet: return "电子钱包"
        case .investment: return "投资"
        case .renovation: return "装修"
        case .other: return "其他"
        }
    }
    
    // 格式化余额输入，限制为两位小数
    private func formatBalanceInput(_ input: String) -> String {
        let filtered = input.filter { $0.isNumber || $0 == "." }
        let components = filtered.components(separatedBy: ".")
        if components.count > 2 {
            return components[0] + "." + components.dropFirst().joined()
        }
        if components.count == 2 {
            let integerPart = components[0]
            var decimalPart = components[1]
            if decimalPart.count > 2 {
                decimalPart = String(decimalPart.prefix(2))
            }
            return integerPart + "." + decimalPart
        } else {
            return filtered
        }
    }
    
    // 常用账户图标
    private let commonAccountIcons = [
        "creditcard.fill",
        "banknote.fill",
        "message.fill",
        "qrcode.viewfinder",
        "wallet.pass.fill",
        "creditcard.and.123",
        "building.columns.fill",
        "chart.line.uptrend.xyaxis",
        "dollarsign.circle.fill",
        "bag.fill"
    ]
}

// MARK: - 编辑账户 Sheet
struct EditAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var account: Account
    @State private var name: String
    @State private var selectedColor: Color
    @State private var selectedIconName: String
    @State private var selectedAccountType: AccountType
    
    init(account: Account) {
        self.account = account
        _name = State(initialValue: account.name)
        _selectedColor = State(initialValue: Color(hex: account.hexColor))
        _selectedIconName = State(initialValue: account.iconName)
        _selectedAccountType = State(initialValue: account.accountType)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("账户信息") {
                    TextField("账户名称", text: $name)
                    
                    Picker("账户类型", selection: $selectedAccountType) {
                        ForEach(AccountType.allCases, id: \.self) { type in
                            Text(accountTypeName(type)).tag(type)
                        }
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
                    
                    // 图标预览和选择
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
                    
                    // 常用图标快捷选择
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(commonAccountIcons, id: \.self) { iconName in
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
                        .padding(.horizontal, 4)
                    }
                }
                
                Section {
                    // 预览卡片
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.3))
                                .frame(width: 56, height: 56)
                            
                            Image(systemName: selectedIconName)
                                .foregroundColor(.white)
                                .font(.system(size: 28))
                                .imageScale(.large)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(name.isEmpty ? "账户名称" : name)
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            Text(accountTypeName(selectedAccountType))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Spacer()
                    }
                    .padding(20)
                    .background(
                        LinearGradient(
                            colors: [selectedColor, selectedColor.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                } header: {
                    Text("预览")
                }
            }
            .navigationTitle("编辑账户")
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
        account.name = name
        account.hexColor = selectedColor.toHex()
        account.iconName = selectedIconName
        account.accountType = selectedAccountType
        try? modelContext.save()
        dismiss()
    }
    
    private func accountTypeName(_ type: AccountType) -> String {
        switch type {
        case .cash: return "现金"
        case .debitCard: return "借记卡"
        case .creditCard: return "信用卡"
        case .ewallet: return "电子钱包"
        case .investment: return "投资"
        case .renovation: return "装修"
        case .other: return "其他"
        }
    }
    
    // 常用账户图标
    private let commonAccountIcons = [
        "creditcard.fill",
        "banknote.fill",
        "message.fill",
        "qrcode.viewfinder",
        "wallet.pass.fill",
        "creditcard.and.123",
        "building.columns.fill",
        "chart.line.uptrend.xyaxis",
        "dollarsign.circle.fill",
        "bag.fill"
    ]
}

// MARK: - 调整余额 Sheet
struct AdjustBalanceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var account: Account
    @State private var newBalance: String = ""
    
    init(account: Account) {
        self.account = account
        _newBalance = State(initialValue: String(format: "%.2f", account.balance))
    }
    
    // 计算实时差异
    private var difference: Double? {
        guard let newBalanceValue = Double(newBalance) else { return nil }
        return newBalanceValue - account.balance
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Form {
                    Section {
                        // 当前余额显示
                        HStack {
                            Text("当前余额")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("¥\(account.balance, specifier: "%.2f")")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        
                        // 新余额输入
                        VStack(alignment: .leading, spacing: 8) {
                            Text("新余额")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            TextField("输入新余额", text: $newBalance)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 24, weight: .semibold))
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .onChange(of: newBalance) { oldValue, newValue in
                                    // 限制输入为两位小数
                                    let formatted = formatBalanceInput(newValue)
                                    if formatted != newValue {
                                        newBalance = formatted
                                    }
                                }
                        }
                        .padding(.top, 8)
                        
                        // 实时差异显示
                        if let diff = difference, abs(diff) > 0.001 {
                            HStack {
                                Text("差异")
                                    .foregroundColor(.secondary)
                                Spacer()
                                HStack(spacing: 4) {
                                    Image(systemName: diff > 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                        .font(.caption)
                                    Text("\(diff > 0 ? "+" : "")¥\(abs(diff), specifier: "%.2f")")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                }
                                .foregroundColor(diff > 0 ? .green : .red)
                            }
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                        }
                    } header: {
                        Text("调整 \(account.name) 的余额")
                    } footer: {
                        if let diff = difference, abs(diff) > 0.001 {
                            Text(diff > 0 
                                 ? "系统将自动创建一笔收入记录来保持账本一致性" 
                                 : "系统将自动创建一笔支出记录来保持账本一致性")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("输入新的余额值来更新账户余额。系统会自动创建交易记录以保持账本一致性。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("调整余额")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveBalance()
                    }
                    .disabled(newBalance.isEmpty || Double(newBalance) == nil || abs(difference ?? 0) < 0.001)
                }
            }
        }
    }
    
    private func saveBalance() {
        guard let balance = Double(newBalance) else { return }
        
        // 四舍五入到两位小数
        let roundedBalance = (balance * 100).rounded() / 100
        
        // 使用 AccountService 来调整余额（会自动创建交易记录）
        AccountService.adjustBalance(account: account, newBalance: roundedBalance, context: modelContext)
        
        dismiss()
    }
    
    // 格式化余额输入，限制为两位小数
    private func formatBalanceInput(_ input: String) -> String {
        // 移除所有非数字和小数点的字符
        let filtered = input.filter { $0.isNumber || $0 == "." }
        
        // 检查是否有多个小数点
        let components = filtered.components(separatedBy: ".")
        if components.count > 2 {
            // 如果有多个小数点，只保留第一个
            return components[0] + "." + components.dropFirst().joined()
        }
        
        // 如果只有一个小数点，检查小数位数
        if components.count == 2 {
            let integerPart = components[0]
            var decimalPart = components[1]
            
            // 限制小数部分最多两位
            if decimalPart.count > 2 {
                decimalPart = String(decimalPart.prefix(2))
            }
            
            return integerPart + "." + decimalPart
        } else {
            return filtered
        }
    }
}

// MARK: - 转账 Sheet
struct TransferSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let fromAccount: Account
    let allAccounts: [Account]
    
    @State private var selectedToAccount: Account?
    @State private var amount: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("从账户") {
                    HStack {
                        Image(systemName: fromAccount.iconName)
                            .foregroundColor(fromAccount.color)
                        Text(fromAccount.name)
                        Spacer()
                               Text("¥\(fromAccount.balance, specifier: "%.2f")")
                                   .lineLimit(1)
                                   .minimumScaleFactor(0.7)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("到账户") {
                    Picker("选择账户", selection: $selectedToAccount) {
                        Text("请选择").tag(nil as Account?)
                        ForEach(allAccounts.filter { $0.id != fromAccount.id }) { account in
                            HStack {
                                Image(systemName: account.iconName)
                                    .foregroundColor(account.color)
                                Text(account.name)
                            }
                            .tag(account as Account?)
                        }
                    }
                }
                
                Section("转账金额") {
                    TextField("金额", text: $amount)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("转账")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确认") {
                        if let toAccount = selectedToAccount,
                           let transferAmount = Double(amount),
                           transferAmount > 0,
                           fromAccount.balance >= transferAmount {
                            fromAccount.balance -= transferAmount
                            toAccount.balance += transferAmount
                            try? modelContext.save()
                            dismiss()
                        }
                    }
                    .disabled(selectedToAccount == nil || amount.isEmpty || Double(amount) == nil || (Double(amount) ?? 0) <= 0)
                }
            }
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Account.self, Category.self, ExpenseItem.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = ModelContext(container)
    DataSeeder.ensureDefaults(context: context)
    
    return AssetsView()
        .modelContainer(container)
}
