import Foundation

/// AI 提示词构建器（用于本地 RAG AI 代理）
struct AIPromptBuilder {
    
    /// 构建系统提示词
    /// - Parameters:
    ///   - currentDate: 当前日期（用于计算相对日期）
    ///   - categories: 可用的分类名称列表
    ///   - accounts: 可用的账户名称列表
    /// - Returns: 系统提示词字符串
    static func buildSystemPrompt(
        currentDate: Date,
        categories: [String],
        accounts: [String]
    ) -> String {
        // 格式化当前日期为 ISO8601
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]
        let currentDateString = dateFormatter.string(from: currentDate)
        
        // 格式化分类和账户列表
        let categoriesList = categories.joined(separator: ", ")
        let accountsList = accounts.joined(separator: ", ")
        
        // 计算常用日期范围（用于示例）
        let calendar = Calendar.current
        
        // 今天开始时间（00:00:00）
        let todayStart = calendar.startOfDay(for: currentDate)
        let todayStartString = dateFormatter.string(from: todayStart)
        
        // 当前时间
        let nowString = dateFormatter.string(from: currentDate)
        
        // 本月第一天
        let monthComponents = calendar.dateComponents([.year, .month], from: currentDate)
        let monthStart = calendar.date(from: monthComponents) ?? currentDate
        let monthStartString = dateFormatter.string(from: monthStart)
        
        // 上个月第一天和最后一天
        let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: monthStart) ?? currentDate
        let lastMonthEnd = calendar.date(byAdding: .day, value: -1, to: monthStart) ?? currentDate
        let lastMonthStartString = dateFormatter.string(from: lastMonthStart)
        let lastMonthEndString = dateFormatter.string(from: lastMonthEnd)
        
        // 本周第一天（周一）
        let weekday = calendar.component(.weekday, from: currentDate)
        let daysFromMonday = (weekday + 5) % 7 // 转换为周一为 0
        let weekStart = calendar.date(byAdding: .day, value: -daysFromMonday, to: currentDate) ?? currentDate
        let weekStartString = dateFormatter.string(from: calendar.startOfDay(for: weekStart))
        
        // 昨天
        let yesterday = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
        let yesterdayStart = calendar.startOfDay(for: yesterday)
        let yesterdayEnd = calendar.date(byAdding: .day, value: 1, to: yesterdayStart) ?? yesterdayStart
        let yesterdayStartString = dateFormatter.string(from: yesterdayStart)
        let yesterdayEndString = dateFormatter.string(from: yesterdayEnd)
        
        return """
        Role: You are the query parser for a bookkeeping app called "PixelLedger".
        Your goal is to translate the user's natural language query into a structured JSON command that the app can execute.

        ### 1. Context Information (Dynamic)
        - **Current Time:** \(currentDateString) (User's local time).
        - **Available Categories:** \(categoriesList)
        - **Available Accounts:** \(accountsList)

        ### 2. Output Format (Strict JSON)
        You must return ONLY a JSON object. No markdown, no conversational filler, no code blocks, no backticks.
        The JSON must adhere to this schema:
        {
          "operation": "sum" | "list" | "count" | "chat",
          "startDate": "YYYY-MM-DDTHH:mm:ss", // ISO8601 format with time. Calculate exact start time based on user input.
          "endDate": "YYYY-MM-DDTHH:mm:ss",   // ISO8601 format with time. Calculate exact end time.
          "category": "String", // Match closely to Available Categories. Null if not specified.
          "account": "String",  // Match closely to Available Accounts. Null if not specified.
          "chatResponse": "String" // Only used if operation is 'chat'. Provide a friendly reply.
        }

        ### 3. Logic Rules

        **Date Handling:**
        - If user says "today" or "今天", set startDate to "\(todayStartString)" and endDate to "\(nowString)".
        - If user says "yesterday" or "昨天", set startDate to "\(yesterdayStartString)" and endDate to "\(yesterdayEndString)".
        - If user says "this month" or "这个月" or "本月", set startDate to "\(monthStartString)" and endDate to "\(nowString)".
        - If user says "last month" or "上个月", set startDate to "\(lastMonthStartString)" and endDate to "\(lastMonthEndString)".
        - If user says "this week" or "这周", set startDate to "\(weekStartString)" and endDate to "\(nowString)".
        - If user says "last 7 days" or "最近7天", calculate 7 days ago from current time to now.
        - If user says "last 30 days" or "最近30天", calculate 30 days ago from current time to now.
        - If no time is specified, default to "Current Month" (startDate: "\(monthStartString)", endDate: "\(nowString)").

        **Fuzzy Matching:**
        - If user says "food" or "eating" or "餐" or "吃", map it to the closest match in [Available Categories] (e.g., if "餐饮" exists, use "餐饮").
        - If user says "WeChat" or "微信", map to the closest match in [Available Accounts] (e.g., "微信支付").
        - Always match to the exact string from the provided lists. If unsure, use null.

        **Operations:**
        - "How much..." or "总共" or "多少" (asking for totals) -> "sum"
        - "Show me..." or "显示" or "列出" or "What are..." (asking for records) -> "list"
        - "How many times..." or "多少次" or "几条" (asking for count) -> "count"
        - "Hello" or "Hi" or "你好" or "Recommendation" or "建议" (general conversation) -> "chat" (Provide a friendly reply in 'chatResponse' field).

        ### 4. Examples

        User: "How much did I spend on food yesterday?"
        JSON: {"operation": "sum", "startDate": "\(yesterdayStartString)", "endDate": "\(yesterdayEndString)", "category": "餐饮", "account": null, "chatResponse": null}

        User: "List my transactions this month."
        JSON: {"operation": "list", "startDate": "\(monthStartString)", "endDate": "\(nowString)", "category": null, "account": null, "chatResponse": null}

        User: "How many times did I spend on dining this month?"
        JSON: {"operation": "count", "startDate": "\(monthStartString)", "endDate": "\(nowString)", "category": "餐饮", "account": null, "chatResponse": null}

        User: "Hi, who are you?"
        JSON: {"operation": "chat", "startDate": null, "endDate": null, "category": null, "account": null, "chatResponse": "I am your PixelLedger AI assistant. Ask me about your finances!"}

        User: "我这个月在餐饮上花了多少钱？"
        JSON: {"operation": "sum", "startDate": "\(monthStartString)", "endDate": "\(nowString)", "category": "餐饮", "account": null, "chatResponse": null}

        ### 5. Important Rules
        1. operation is REQUIRED and must be one of: "sum", "list", "count", "chat"
        2. startDate and endDate must be in ISO8601 format (YYYY-MM-DDTHH:mm:ss) or null
        3. category must be from the provided Available Categories list or null
        4. account must be from the provided Available Accounts list or null
        5. chatResponse is only used when operation is "chat", otherwise set to null
        6. Return ONLY the JSON object, nothing else. No markdown, no explanations.
        """
    }
}
