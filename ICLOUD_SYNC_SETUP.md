# iCloud Sync (CloudKit) 配置指南

本文档详细说明如何为 PixelLedger 应用启用 iCloud 同步功能。

## ✅ 代码更改已完成

`AccountingApp.swift` 已更新为支持 CloudKit 同步。主要更改：
- 添加了 `cloudKitDatabase: .automatic` 配置
- 导入了 `CloudKit` 框架

## 📋 Xcode 配置检查清单

### 步骤 1: 配置 App ID 和 Capabilities

1. **打开 Xcode 项目**
   - 在 Xcode 中打开 `Accounting.xcodeproj`

2. **选择项目 Target**
   - 在左侧导航栏选择项目根节点
   - 选择 "Accounting" target

3. **配置 Signing & Capabilities**
   - 点击顶部的 "Signing & Capabilities" 标签
   - 确保 "Automatically manage signing" 已勾选（或手动配置证书）

### 步骤 2: 添加 iCloud Capability

1. **添加 iCloud Capability**
   - 点击 "+ Capability" 按钮
   - 搜索并添加 "iCloud"
   - 在 iCloud 设置中：
     - ✅ 勾选 "CloudKit"
     - ❌ 不要勾选 "Key-value storage"（除非你需要）

2. **配置 CloudKit Container**
   - 在 iCloud 设置中，你会看到 "CloudKit Containers" 部分
   - 点击 "+" 添加容器
   - 输入容器标识符，格式：`iCloud.com.yourname.Accounting`
     - 替换 `yourname` 为你的开发者名称或公司名称
     - 例如：`iCloud.com.johnsmith.Accounting`
   - **重要**: 容器标识符必须与 entitlements 文件中的配置一致

### 步骤 3: 更新 Entitlements 文件

1. **打开 Entitlements 文件**
   - 在项目导航器中找到 `Accounting.entitlements`

2. **更新容器标识符**
   - 找到 `com.apple.developer.icloud-container-identifiers` 键
   - 将空数组 `[]` 替换为你的容器标识符：
   ```xml
   <key>com.apple.developer.icloud-container-identifiers</key>
   <array>
       <string>iCloud.com.yourname.Accounting</string>
   </array>
   ```
   - 确保标识符与步骤 2 中创建的容器标识符完全一致

### 步骤 4: 配置 Background Modes（可选但推荐）

1. **添加 Background Modes Capability**
   - 点击 "+ Capability" 按钮
   - 搜索并添加 "Background Modes"

2. **启用 Remote Notifications**
   - 在 Background Modes 设置中：
     - ✅ 勾选 "Remote notifications"
   - 这允许 CloudKit 在后台同步数据

### 步骤 5: 在 CloudKit Console 中创建容器

1. **访问 CloudKit Console**
   - 打开浏览器，访问：https://icloud.developer.apple.com/dashboard
   - 使用你的 Apple Developer 账号登录

2. **创建容器**
   - 点击 "Containers" 或 "+" 按钮
   - 输入容器标识符（与步骤 2 中的一致）
   - 选择环境：
     - **Development**: 用于开发和测试
     - **Production**: 用于 App Store 发布
   - 点击 "Create"

3. **配置 Schema（自动）**
   - SwiftData 会自动在 CloudKit 中创建对应的 Record Types
   - 首次运行应用后，在 CloudKit Console 中检查：
     - `CD_ExpenseItem`
     - `CD_Category`
     - `CD_Account`
   - 这些是 SwiftData 自动生成的 CloudKit 记录类型

### 步骤 6: 测试 iCloud 同步

1. **在同一 Apple ID 的两台设备上测试**
   - 设备 1: 创建一些数据（账单、分类、账户）
   - 等待几秒钟（CloudKit 同步可能需要几秒到几分钟）
   - 设备 2: 打开应用，数据应该自动出现

2. **检查同步状态**
   - 在 Xcode Console 中查看是否有 CloudKit 相关日志
   - 如果遇到问题，检查：
     - 两台设备是否使用相同的 Apple ID
     - 是否已登录 iCloud
     - 网络连接是否正常

## ⚠️ 模型兼容性检查

你的 SwiftData 模型已经兼容 CloudKit，但请注意以下事项：

### ✅ 兼容的属性类型
- `UUID` - ✅ 支持（用于唯一标识）
- `String` - ✅ 支持
- `Double` - ✅ 支持
- `Date` - ✅ 支持
- `String?` (可选) - ✅ 支持

### 📝 注意事项

1. **默认值处理**
   - 你的模型在 `init` 方法中使用默认值（如 `UUID()`, `Date()`）
   - 这是可以的，CloudKit 会正确同步这些值

2. **唯一标识符**
   - `Category` 和 `Account` 使用 `UUID` 作为唯一标识符 ✅
   - `ExpenseItem` 没有显式的 `id`，SwiftData 会自动生成 ✅

3. **可选属性**
   - `ExpenseItem.accountName` 是可选类型 ✅
   - CloudKit 完全支持可选属性

4. **计算属性**
   - `Category.categoryType` 和 `Account.accountType` 是计算属性
   - 这些不会被同步到 CloudKit（只同步存储的属性）
   - 这是正确的行为 ✅

## 🔧 故障排除

### 问题 1: 数据不同步
- **检查**: 确保两台设备使用相同的 Apple ID
- **检查**: 在设备设置中确认 iCloud 已启用
- **检查**: 网络连接是否正常
- **检查**: CloudKit Console 中容器是否已创建

### 问题 2: 编译错误
- **检查**: `Accounting.entitlements` 文件中的容器标识符是否正确
- **检查**: Xcode 中 Signing & Capabilities 是否已正确配置

### 问题 3: 首次同步慢
- **正常现象**: CloudKit 首次同步可能需要几分钟
- **建议**: 在开发环境中使用 Development 容器，同步更快

## 📚 参考资源

- [Apple 官方文档: Using CloudKit with SwiftData](https://developer.apple.com/documentation/cloudkit/using_cloudkit_with_swiftdata)
- [CloudKit Console](https://icloud.developer.apple.com/dashboard)

## ✅ 完成检查清单

完成以下所有步骤后，iCloud 同步应该可以正常工作：

- [ ] 在 Xcode 中添加了 iCloud Capability
- [ ] 勾选了 CloudKit
- [ ] 创建了 CloudKit Container（在 Xcode 中）
- [ ] 更新了 `Accounting.entitlements` 文件
- [ ] 在 CloudKit Console 中创建了容器
- [ ] 添加了 Background Modes（可选）
- [ ] 在两台设备上测试了同步功能

---

**重要提示**: 容器标识符一旦创建就不能更改。确保使用正确的格式和命名约定。
