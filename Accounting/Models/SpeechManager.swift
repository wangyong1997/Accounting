import Foundation
import Speech
import AVFoundation
import SwiftUI
import Observation

/// 语音识别管理器
@MainActor
@Observable
final class SpeechManager: NSObject {
    // MARK: - Published Properties
    
    /// 实时转录文本
    var transcript: String = ""
    
    /// 是否正在录音
    var isRecording: Bool = false
    
    /// 音频级别（0.0 - 1.0，用于波形显示）
    var audioLevel: Float = 0.0
    
    /// 错误信息
    var errorMessage: String?
    
    /// 权限状态
    var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    var microphonePermissionStatus: AVAudioSession.RecordPermission = .undetermined
    
    // MARK: - Private Properties
    
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    // audioEngine 是线程安全的，标记为 nonisolated(unsafe) 以在 deinit 中使用
    nonisolated(unsafe) private let audioEngine = AVAudioEngine()
    private let audioSession = AVAudioSession.sharedInstance()
    
    // 用于 deinit 清理的标记（非隔离，用于安全访问）
    private nonisolated(unsafe) var needsCleanup: Bool = false
    
    // MARK: - Initialization
    
    override init() {
        // 初始化语音识别器，优先使用中文（必须在 super.init() 之前）
        let recognizer: SFSpeechRecognizer?
        if let cnRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN")) {
            recognizer = cnRecognizer
        } else {
            // 如果中文不可用，使用当前语言环境
            recognizer = SFSpeechRecognizer()
        }
        
        // 初始化所有存储属性
        self.speechRecognizer = recognizer
        
        // 调用父类初始化
        super.init()
        
        // 检查权限状态
        authorizationStatus = SFSpeechRecognizer.authorizationStatus()
        microphonePermissionStatus = audioSession.recordPermission
        
        // 配置语音识别器
        speechRecognizer?.delegate = self
    }
    
    // MARK: - Permission Management
    
    /// 请求所有必需的权限
    /// - Returns: 是否已授予所有权限
    func requestPermissions() async -> Bool {
        // 请求语音识别权限
        let speechStatus = await requestSpeechAuthorization()
        
        // 请求麦克风权限
        let microphoneStatus = await requestMicrophonePermission()
        
        return speechStatus == .authorized && microphoneStatus == .granted
    }
    
    /// 请求语音识别权限
    @discardableResult
    private func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        let currentStatus = SFSpeechRecognizer.authorizationStatus()
        
        guard currentStatus == .notDetermined else {
            authorizationStatus = currentStatus
            return currentStatus
        }
        
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    self.authorizationStatus = status
                    continuation.resume(returning: status)
                }
            }
        }
    }
    
    /// 请求麦克风权限
    @discardableResult
    private func requestMicrophonePermission() async -> AVAudioSession.RecordPermission {
        let currentStatus = audioSession.recordPermission
        
        guard currentStatus == .undetermined else {
            microphonePermissionStatus = currentStatus
            return currentStatus
        }
        
        return await withCheckedContinuation { continuation in
            audioSession.requestRecordPermission { granted in
                Task { @MainActor in
                    let status: AVAudioSession.RecordPermission = granted ? .granted : .denied
                    self.microphonePermissionStatus = status
                    continuation.resume(returning: status)
                }
            }
        }
    }
    
    /// 检查是否已授予所有权限
    var hasAllPermissions: Bool {
        authorizationStatus == .authorized && microphonePermissionStatus == .granted
    }
    
    // MARK: - Recording Control
    
    /// 开始录音
    func startRecording() throws {
        // 检查权限
        guard hasAllPermissions else {
            throw SpeechError.permissionDenied
        }
        
        // 检查语音识别器是否可用
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw SpeechError.recognizerUnavailable
        }
        
        // 如果正在录音，先停止
        if isRecording {
            stopRecording()
        }
        
        // 重置状态
        transcript = ""
        errorMessage = nil
        
        // 配置音频会话
        try configureAudioSession()
        
        // 创建识别请求
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else {
            throw SpeechError.requestCreationFailed
        }
        
        // 配置识别请求
        request.shouldReportPartialResults = true
        
        // 获取音频输入节点
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // 安装音频引擎的 tap 来监听音频
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            request.append(buffer)
            
            // 更新音频级别（用于波形显示）
            if let channelData = buffer.floatChannelData {
                let channelDataValue = channelData.pointee
                let channelDataValueArray = stride(from: 0, to: Int(buffer.frameLength), by: buffer.stride)
                    .map { channelDataValue[$0] }
                
                let rms = sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
                let avgPower = 20 * log10(rms)
                let normalizedLevel = max(0.0, min(1.0, (avgPower + 60) / 60)) // 归一化到 0-1
                
                Task { @MainActor in
                    self?.audioLevel = normalizedLevel
                }
            }
        }
        
        // 准备并启动音频引擎
        audioEngine.prepare()
        try audioEngine.start()
        
        // 开始识别任务
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self else { return }
                
                if let error = error {
                    self.handleRecognitionError(error)
                    return
                }
                
                if let result = result {
                    // 更新转录文本
                    self.transcript = result.bestTranscription.formattedString
                    
                    // 如果识别完成（最终结果）
                    if result.isFinal {
                        self.stopRecording()
                    }
                }
            }
        }
        
        isRecording = true
        needsCleanup = true
        print("🎤 [SpeechManager] 开始录音")
    }
    
    /// 停止录音
    func stopRecording() {
        guard isRecording else { return }
        
        // 停止音频引擎
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        // 完成识别请求
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        // 取消识别任务
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // 重置音频级别
        audioLevel = 0.0
        
        isRecording = false
        needsCleanup = false
        print("🛑 [SpeechManager] 停止录音")
    }
    
    // MARK: - Audio Session Configuration
    
    /// 配置音频会话
    private func configureAudioSession() throws {
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }
    
    // MARK: - Error Handling
    
    /// 处理识别错误
    private func handleRecognitionError(_ error: Error) {
        if let speechError = error as? SpeechError {
            errorMessage = speechError.localizedDescription
        } else {
            let nsError = error as NSError
            
            switch nsError.code {
            case 216: // SFSpeechRecognizerErrorCode.notAvailable
                errorMessage = "语音识别服务不可用"
            case 201: // SFSpeechRecognizerErrorCode.recognitionTaskUnavailable
                errorMessage = "识别任务不可用"
            case 1700: // SFSpeechRecognizerErrorCode.audioEngineUnavailable
                errorMessage = "音频引擎不可用"
            case 1701: // SFSpeechRecognizerErrorCode.networkUnavailable
                errorMessage = "网络不可用，无法进行语音识别"
            default:
                errorMessage = "语音识别错误: \(error.localizedDescription)"
            }
        }
        
        print("❌ [SpeechManager] 识别错误: \(error.localizedDescription)")
        stopRecording()
    }
    
    // MARK: - Cleanup
    
    /// 非隔离的清理方法，用于 deinit
    nonisolated private func performCleanup() {
        // 只清理音频引擎，这是线程安全的
        if needsCleanup {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
    }
    
    deinit {
        // 在 deinit 中调用非隔离的清理方法
        performCleanup()
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension SpeechManager: SFSpeechRecognizerDelegate {
    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            if !available && self.isRecording {
                self.errorMessage = "语音识别服务已不可用"
                self.stopRecording()
            }
        }
    }
}

// MARK: - SpeechError

enum SpeechError: LocalizedError {
    case permissionDenied
    case recognizerUnavailable
    case requestCreationFailed
    case audioSessionConfigurationFailed
    case audioEngineStartFailed
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "需要授予语音识别和麦克风权限才能使用此功能"
        case .recognizerUnavailable:
            return "语音识别服务当前不可用"
        case .requestCreationFailed:
            return "无法创建识别请求"
        case .audioSessionConfigurationFailed:
            return "音频会话配置失败"
        case .audioEngineStartFailed:
            return "音频引擎启动失败"
        }
    }
}
