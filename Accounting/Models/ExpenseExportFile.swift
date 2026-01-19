import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// 账单导出文件（实现 Transferable 协议，用于分享）
struct ExpenseExportFile: Transferable {
    let csvData: Data
    let filename: String
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .commaSeparatedText) { file in
            // 创建临时文件 URL
            let tempDirectory = FileManager.default.temporaryDirectory
            let tempFileURL = tempDirectory.appendingPathComponent(file.filename)
            
            // 将 CSV 数据写入临时文件
            try file.csvData.write(to: tempFileURL)
            
            // 返回临时文件的 URL
            return SentTransferredFile(
                tempFileURL,
                allowAccessingOriginalFile: false
            )
        } importing: { received in
            // 导入功能（如果需要）
            let data = try Data(contentsOf: received.file)
            let filename = received.file.lastPathComponent
            return ExpenseExportFile(csvData: data, filename: filename)
        }
    }
    
    /// 创建导出文件
    /// - Parameters:
    ///   - expenses: 账单数组
    ///   - categories: 分类数组（用于判断收入/支出类型）
    /// - Returns: ExpenseExportFile 实例
    static func create(expenses: [ExpenseItem], categories: [Category]) -> ExpenseExportFile {
        // 生成 CSV 字符串
        let csvString = CSVGenerator.generateCSV(from: expenses, categories: categories)
        
        // 转换为 Data（使用 UTF-8 编码）
        guard let csvData = csvString.data(using: .utf8) else {
            fatalError("无法将 CSV 字符串转换为 Data")
        }
        
        // 生成文件名（包含当前日期）
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: Date())
        let filename = "PixelLedger_Backup_\(dateStr).csv"
        
        return ExpenseExportFile(csvData: csvData, filename: filename)
    }
}

/// 扩展 UTType 以支持 CSV 文件类型
extension UTType {
    static var commaSeparatedText: UTType {
        UTType(filenameExtension: "csv") ?? .plainText
    }
}
