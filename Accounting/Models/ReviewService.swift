import Foundation
import StoreKit
import SwiftUI

/// 应用内评价服务：智能管理评价请求
@MainActor
class ReviewService {
    // MARK: - User Defaults Keys
    private enum Keys {
        static let appLaunchCount = "review_appLaunchCount"
        static let transactionCount = "review_transactionCount"
        static let lastReviewRequestDate = "review_lastReviewRequestDate"
        static let reviewRequestCount = "review_reviewRequestCount"
    }
    
    // MARK: - Configuration
    private let minAppLaunches = 3
    private let minTransactions = 10
    private let minDaysBetweenRequests = 120 // 4个月 = 约120天
    private let maxRequestsPerYear = 3 // Apple限制每年最多3次
    
    // MARK: - Singleton
    static let shared = ReviewService()
    
    private init() {}
    
    // MARK: - Track Actions
    
    /// 记录应用启动
    func logAppLaunch() {
        let currentCount = UserDefaults.standard.integer(forKey: Keys.appLaunchCount)
        UserDefaults.standard.set(currentCount + 1, forKey: Keys.appLaunchCount)
        print("📱 [ReviewService] 应用启动次数: \(currentCount + 1)")
    }
    
    /// 记录关键操作（如添加交易）
    func logKeyAction() {
        let currentCount = UserDefaults.standard.integer(forKey: Keys.transactionCount)
        UserDefaults.standard.set(currentCount + 1, forKey: Keys.transactionCount)
        print("✅ [ReviewService] 交易记录次数: \(currentCount + 1)")
    }
    
    // MARK: - Check Eligibility
    
    /// 检查是否符合评价请求条件
    /// - Returns: 是否符合条件
    func shouldRequestReview() -> Bool {
        // 1. 检查应用启动次数
        let launchCount = UserDefaults.standard.integer(forKey: Keys.appLaunchCount)
        guard launchCount >= minAppLaunches else {
            print("ℹ️ [ReviewService] 应用启动次数不足: \(launchCount)/\(minAppLaunches)")
            return false
        }
        
        // 2. 检查交易记录次数
        let transactionCount = UserDefaults.standard.integer(forKey: Keys.transactionCount)
        guard transactionCount >= minTransactions else {
            print("ℹ️ [ReviewService] 交易记录次数不足: \(transactionCount)/\(minTransactions)")
            return false
        }
        
        // 3. 检查距离上次请求的时间
        if let lastRequestDate = UserDefaults.standard.object(forKey: Keys.lastReviewRequestDate) as? Date {
            let daysSinceLastRequest = Calendar.current.dateComponents([.day], from: lastRequestDate, to: Date()).day ?? 0
            guard daysSinceLastRequest >= minDaysBetweenRequests else {
                print("ℹ️ [ReviewService] 距离上次请求时间不足: \(daysSinceLastRequest)天/\(minDaysBetweenRequests)天")
                return false
            }
        }
        
        // 4. 检查年度请求次数（可选，Apple会自动限制，但我们可以额外检查）
        let requestCount = UserDefaults.standard.integer(forKey: Keys.reviewRequestCount)
        if let lastRequestDate = UserDefaults.standard.object(forKey: Keys.lastReviewRequestDate) as? Date {
            let daysSinceLastRequest = Calendar.current.dateComponents([.day], from: lastRequestDate, to: Date()).day ?? 0
            // 如果距离上次请求超过365天，重置计数
            if daysSinceLastRequest > 365 {
                UserDefaults.standard.set(0, forKey: Keys.reviewRequestCount)
                print("🔄 [ReviewService] 重置年度请求计数")
            }
        }
        
        let currentYearRequestCount = UserDefaults.standard.integer(forKey: Keys.reviewRequestCount)
        guard currentYearRequestCount < maxRequestsPerYear else {
            print("ℹ️ [ReviewService] 年度请求次数已达上限: \(currentYearRequestCount)/\(maxRequestsPerYear)")
            return false
        }
        
        print("✅ [ReviewService] 符合评价请求条件")
        return true
    }
    
    // MARK: - Request Review
    
    /// 请求评价（如果符合条件）
    /// - Parameter requestReview: SwiftUI 的 requestReview 环境值
    func requestReviewIfEligible(requestReview: RequestReviewAction) {
        guard shouldRequestReview() else {
            return
        }
        
        // 记录请求时间和次数
        UserDefaults.standard.set(Date(), forKey: Keys.lastReviewRequestDate)
        let currentCount = UserDefaults.standard.integer(forKey: Keys.reviewRequestCount)
        UserDefaults.standard.set(currentCount + 1, forKey: Keys.reviewRequestCount)
        
        print("⭐ [ReviewService] 请求应用评价")
        
        // 延迟一点显示，确保用户体验流畅
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            requestReview()
        }
    }
    
    // MARK: - Debug & Reset (Development Only)
    
    #if DEBUG
    /// 重置所有评价相关数据（仅用于开发测试）
    func resetReviewData() {
        UserDefaults.standard.removeObject(forKey: Keys.appLaunchCount)
        UserDefaults.standard.removeObject(forKey: Keys.transactionCount)
        UserDefaults.standard.removeObject(forKey: Keys.lastReviewRequestDate)
        UserDefaults.standard.removeObject(forKey: Keys.reviewRequestCount)
        print("🔄 [ReviewService] 已重置所有评价数据")
    }
    
    /// 获取当前状态（用于调试）
    func getCurrentStatus() -> (launches: Int, transactions: Int, lastRequest: Date?, requestCount: Int) {
        let launches = UserDefaults.standard.integer(forKey: Keys.appLaunchCount)
        let transactions = UserDefaults.standard.integer(forKey: Keys.transactionCount)
        let lastRequest = UserDefaults.standard.object(forKey: Keys.lastReviewRequestDate) as? Date
        let requestCount = UserDefaults.standard.integer(forKey: Keys.reviewRequestCount)
        return (launches, transactions, lastRequest, requestCount)
    }
    #endif
}
