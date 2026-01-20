# AI服务配置指南

## 概述

`AIService` 支持 OpenAI 兼容的 API 端点，可以与以下服务提供商配合使用：
- OpenAI (https://api.openai.com/v1)
- DeepSeek (https://api.deepseek.com/v1)
- 其他兼容 OpenAI API 格式的服务

## 配置方法

### 方法1：使用 Info.plist（推荐用于开发）

1. 复制 `AIConfig.plist.example` 为 `AIConfig.plist`
2. 将 `AIConfig.plist` 添加到 Xcode 项目中
3. 填写你的 API 密钥和配置：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>APIKey</key>
    <string>YOUR_API_KEY_HERE</string>
    <key>BaseURL</key>
    <string>https://api.openai.com/v1</string>
    <key>Model</key>
    <string>gpt-3.5-turbo</string>
</dict>
</plist>
```

**重要：** 确保 `AIConfig.plist` 已添加到 `.gitignore` 中，不要提交 API 密钥到版本控制！

### 方法2：使用 UserDefaults（推荐用于生产环境）

在应用的设置页面中，允许用户输入 API 密钥：

```swift
AIService.shared.updateConfiguration(
    apiKey: "your-api-key",
    baseURL: "https://api.openai.com/v1",  // 可选
    model: "gpt-3.5-turbo"  // 可选
)
```

配置会自动保存到 UserDefaults，下次启动时会自动加载。

## API 端点配置示例

### OpenAI
```swift
AIService.shared.updateConfiguration(
    apiKey: "sk-...",
    baseURL: "https://api.openai.com/v1",
    model: "gpt-3.5-turbo"
)
```

### DeepSeek
```swift
AIService.shared.updateConfiguration(
    apiKey: "sk-...",
    baseURL: "https://api.deepseek.com/v1",
    model: "deepseek-chat"
)
```

### 自定义端点
```swift
AIService.shared.updateConfiguration(
    apiKey: "your-api-key",
    baseURL: "https://your-custom-endpoint.com/v1",
    model: "your-model-name"
)
```

## 使用示例

### 在代码中调用

```swift
do {
    let result = try await AIService.shared.parseTransaction(
        text: "昨天午餐花了50元",
        currentCategories: ["餐饮", "交通", "购物"],
        currentAccounts: ["微信支付", "支付宝", "银行卡"]
    )
    
    if let amount = result.amount {
        print("金额: \(amount)")
        print("分类: \(result.categoryName ?? "未指定")")
        print("账户: \(result.accountName ?? "未指定")")
        print("备注: \(result.note ?? "无")")
        print("日期: \(result.date ?? "今天")")
    }
} catch {
    print("错误: \(error.localizedDescription)")
}
```

## 响应格式

`AIService` 期望 API 返回以下 JSON 格式：

```json
{
    "amount": 50.0,
    "category_name": "餐饮",
    "account_name": "微信支付",
    "note": "午餐",
    "date": "-1d"
}
```

### 字段说明

- `amount`: 金额（必需，数字类型）
- `category_name`: 分类名称（可选，必须从提供的分类列表中选择）
- `account_name`: 账户名称（可选，必须从提供的账户列表中选择）
- `note`: 交易备注/描述（可选）
- `date`: 日期（可选，ISO8601格式如"2024-01-15"，或相对偏移如"-1d"表示昨天）

## 错误处理

`AIService` 会抛出以下错误类型：

- `AIServiceError.invalidConfiguration`: 配置无效
- `AIServiceError.networkError`: 网络错误
- `AIServiceError.invalidResponse`: 无效的响应
- `AIServiceError.decodingError`: JSON 解析错误
- `AIServiceError.apiError`: API 返回的错误

## 安全检查

1. **不要将 API 密钥提交到版本控制**
   - 将 `AIConfig.plist` 添加到 `.gitignore`
   - 使用环境变量或安全的密钥管理服务

2. **在生产环境中使用 UserDefaults**
   - 允许用户在应用内配置 API 密钥
   - 使用 Keychain 存储敏感信息（可选）

3. **验证配置**
   ```swift
   if AIService.shared.isConfigured {
       // 可以使用 AI 服务
   } else {
       // 使用本地解析作为后备
   }
   ```

## 后备方案

如果 `AIService` 未配置或调用失败，应用会自动使用本地解析逻辑作为后备方案，确保基本功能仍然可用。
