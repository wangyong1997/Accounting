# PixelLedger 数据模型使用说明

## 概述

本项目包含两个主要的数据模型：
- `Category`: 分类模型，用于管理支出和收入的分类
- `ExpenseItem`: 支出项目模型（已存在）

## 数据模型

### Category 模型

`Category` 是一个 SwiftData `@Model`，包含以下属性：

- `id`: UUID - 唯一标识符
- `name`: String - 分类名称（如 "Dining", "Salary"）
- `symbolName`: String - SF Symbol 图标名称
- `hexColor`: String - 十六进制颜色代码（如 "#FF9500"）
- `type`: String - 分类类型（"Expense" 或 "Income"）
- `createdAt`: Date - 创建时间

### CategoryType 枚举

```swift
enum CategoryType: String, Codable {
    case expense = "Expense"
    case income = "Income"
}
```

## 数据种子机制

### 自动初始化

`DataSeeder.ensureDefaults(context:)` 函数会在应用首次启动时自动检查并创建默认分类。

**调用位置**: `AccountingApp.swift` 中的 `createModelContainer()` 方法

**工作原理**:
1. 检查 `Category` 表是否为空
2. 如果为空，批量插入所有默认分类
3. 如果已有数据，跳过初始化

### 默认分类列表

#### 支出分类 (Expense)

**Food 组** (橙色 #FF9500)
- Dining (fork.knife)
- Snacks (cup.and.saucer.fill)
- Groceries (basket.fill)
- Alcohol (wineglass.fill)

**Transport 组** (蓝色 #007AFF)
- Public Transit (tram.fill)
- Car/Taxi (car.fill)
- Travel (airplane)

**Shopping 组** (红色 #FF2D55)
- Daily Needs (cart.fill)
- Clothes (tshirt.fill)
- Electronics (desktopcomputer)
- Furniture (chair.lounge.fill)

**Housing 组** (绿色 #34C759)
- Rent/Mortgage (house.fill)
- Utilities (bolt.fill)
- Internet (wifi)

**Entertainment 组** (紫色 #AF52DE)
- Movies (movieclapper.fill)
- Games (gamecontroller.fill)
- Sports (figure.run)
- Pets (pawprint.fill)

**Medical & Others 组** (灰色 #8E8E93)
- Medical (cross.case.fill)
- Education (book.closed.fill)
- Social (envelope.fill)
- Other (ellipsis.circle.fill)

#### 收入分类 (Income) - 金色 #FFCC00

- Salary (banknote.fill)
- Bonus (dollarsign.circle.fill)
- Investment (chart.line.uptrend.xyaxis)
- Side Job (briefcase.fill)
- Other Income (tray.and.arrow.down.fill)

## 常用图标快捷键

### QuickAccessIcons

提供了常用图标的快速访问功能：

```swift
// 获取所有常用图标
QuickAccessIcons.commonIcons

// 按组获取图标
QuickAccessIcons.icons(for: "Food")

// 搜索图标
QuickAccessIcons.searchIcons(keyword: "car")
```

### QuickIconSelector 组件

一个 SwiftUI 视图组件，提供：
- 搜索功能：按分类名称或图标名称搜索
- 常用图标快捷栏：显示最常用的 12 个图标
- 完整分类列表：显示所有可用分类

**使用方法**:
```swift
QuickIconSelector(selectedCategory: $selectedCategory)
```

## 使用示例

### 在视图中查询分类

```swift
@Query(sort: \Category.name) private var categories: [Category]

// 只获取支出分类
let expenseCategories = categories.filter { $0.categoryType == .expense }

// 只获取收入分类
let incomeCategories = categories.filter { $0.categoryType == .income }
```

### 获取分类颜色

```swift
let category = categories.first!
let color = category.color // 自动转换为 SwiftUI Color
```

### 手动触发数据种子（如果需要）

```swift
@Environment(\.modelContext) private var modelContext

// 在需要的地方调用
DataSeeder.ensureDefaults(context: modelContext)
```

## 注意事项

1. **首次启动**: 数据种子会在应用首次启动时自动执行，无需手动调用
2. **数据持久化**: 所有分类数据会保存在 SwiftData 中，应用重启后仍然存在
3. **颜色格式**: 颜色使用十六进制格式存储（如 "#FF9500"），可通过 `category.color` 转换为 SwiftUI Color
4. **类型安全**: 使用 `categoryType` 计算属性来访问类型，而不是直接使用 `type` 字符串
