import Foundation

/// AI 查询意图模型（用于本地 RAG AI 代理）
struct AIQueryIntent: Codable {
    /// 操作类型
    enum Operation: String, Codable {
        case sum // 计算总和（如"总共花了多少钱"）
        case list // 获取记录列表（如"显示我的交易"）
        case count // 计算记录数量（如"多少次"）
        case chat // 普通聊天（需要返回 chatResponse）
    }
    
    /// 操作类型
    let operation: Operation
    
    /// 查询开始日期（可选）
    let startDate: Date?
    
    /// 查询结束日期（可选）
    let endDate: Date?
    
    /// 分类名称筛选（可选，需要匹配 Category.name）
    let categoryName: String?
    
    /// 账户名称筛选（可选，需要匹配 Account.name）
    let accountName: String?
    
    /// 聊天回复（仅当 operation 为 .chat 时使用）
    let chatResponse: String?
    
    // MARK: - Custom Coding Keys
    
    enum CodingKeys: String, CodingKey {
        case operation
        case startDate
        case endDate
        case categoryName = "category"
        case accountName = "account"
        case chatResponse
    }
    
    // MARK: - Custom Decoding
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        operation = try container.decode(Operation.self, forKey: .operation)
        
        // 解析日期（支持 ISO8601 格式字符串）
        if let startDateString = try? container.decodeIfPresent(String.self, forKey: .startDate) {
            startDate = AIQueryIntent.parseDate(from: startDateString)
        } else {
            startDate = nil
        }
        
        if let endDateString = try? container.decodeIfPresent(String.self, forKey: .endDate) {
            endDate = AIQueryIntent.parseDate(from: endDateString)
        } else {
            endDate = nil
        }
        
        categoryName = try container.decodeIfPresent(String.self, forKey: .categoryName)
        accountName = try container.decodeIfPresent(String.self, forKey: .accountName)
        chatResponse = try container.decodeIfPresent(String.self, forKey: .chatResponse)
    }
    
    // MARK: - Custom Encoding
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(operation, forKey: .operation)
        
        // 将日期编码为 ISO8601 格式字符串
        if let startDate = startDate {
            try container.encode(AIQueryIntent.formatDate(startDate), forKey: .startDate)
        } else {
            try container.encodeNil(forKey: .startDate)
        }
        
        if let endDate = endDate {
            try container.encode(AIQueryIntent.formatDate(endDate), forKey: .endDate)
        } else {
            try container.encodeNil(forKey: .endDate)
        }
        
        try container.encodeIfPresent(categoryName, forKey: .categoryName)
        try container.encodeIfPresent(accountName, forKey: .accountName)
        try container.encodeIfPresent(chatResponse, forKey: .chatResponse)
    }
    
    // MARK: - Date Parsing Helper
    
    /// 解析日期字符串（支持 ISO8601 格式：YYYY-MM-DDTHH:mm:ss）
    private static func parseDate(from dateString: String) -> Date? {
        // 尝试 ISO8601 格式（带时间）
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso8601Formatter.date(from: dateString) {
            return date
        }
        
        // 尝试不带秒的格式
        iso8601Formatter.formatOptions = [.withInternetDateTime]
        if let date = iso8601Formatter.date(from: dateString) {
            return date
        }
        
        // 尝试简单日期格式（YYYY-MM-DD）
        let simpleFormatter = DateFormatter()
        simpleFormatter.dateFormat = "yyyy-MM-dd"
        simpleFormatter.locale = Locale(identifier: "en_US_POSIX")
        if let date = simpleFormatter.date(from: dateString) {
            return date
        }
        
        return nil
    }
    
    /// 格式化日期为 ISO8601 字符串（YYYY-MM-DDTHH:mm:ss）
    private static func formatDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}
