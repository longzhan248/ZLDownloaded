//
//  ZYGDLTask.swift
//  ZygoteNetwork
//
//  Created by zhanlong on 2025/2/20.
//

import Foundation

extension ZYGDLTask {
    
    // 用于表示任务的验证状态。
    public enum Validation: Int {
        // 未知状态。
        case unkown
        // 验证正确。
        case correct
        // 验证错误。
        case incorrect
    }
    
}

// 定义一个公开的泛型类 Task，继承自 NSObject，并遵循 Codable 协议。
public class ZYGDLTask<TaskType>: NSObject, Codable {
    
    // 用于编码和解码任务的属性。
    private enum CodingKeys: CodingKey {
        case url
        case currentURL
        case fileName
        case headers
        case startDate
        case endDate
        case totalBytes
        case completedBytes
        case verificationCode
        case status
        case verificationType
        case validation
        case error
    }
    
    // 用于表示任务完成的类型。
    enum CompletionType {
        // 本地完成。
        case local
        // 网络完成，包含 URLSessionTask 和错误信息。
        case network(task: URLSessionTask, error: Error?)
    }
    
    // 用于表示任务中断的类型。
    enum InterruptType {
        // 手动中断。
        case manual
        // 错误中断，包含错误信息。
        case error(_ error: Error)
        // 状态码中断，包含状态码。
        case statusCode(_ statusCode: Int)
    }
    
    // 用于引用会话管理器。
    public internal(set) weak var manager: ZYGDLSessionManager?
    
    // 用于缓存任务数据。
    internal var cache: ZYGDLCache
    
    // 用于执行任务的操作队列。
    internal var operationQueue: DispatchQueue
    
    // 用于存储任务的 URL。
    public let url: URL
    
    // 用于存储任务的进度
    public let progress: Progress = Progress()
    
    // 用于存储任务的状态。
    internal struct State {
        var session: URLSession?
        var headers: [String: String]?
        var verificationCode: String?
        var verificationType: ZYGDLFileChecksumHelper.VerificationType = .md5
        var isRemoveCompletely: Bool = false
        var status: ZYGDLStatus = .waiting
        var validation: Validation = .unkown
        var currentURL: URL
        var startDate: Double = 0
        var endDate: Double = 0
        var speed: Int64 = 0
        var fileName: String
        var timeRemaining: Int64 = 0
        var error: Error?
        
        var progressExecuter: ZYGDLExecuter<TaskType>?
        var successExecuter: ZYGDLExecuter<TaskType>?
        var failureExecuter: ZYGDLExecuter<TaskType>?
        var controlExecuter: ZYGDLExecuter<TaskType>?
        var completionExecuter: ZYGDLExecuter<TaskType>?
        var validateExecuter: ZYGDLExecuter<TaskType>?
    }
    
    // 用于保护任务的状态。
    internal let protectedState: ZYGDLProtector<State>
    
    internal var session: URLSession? {
        get {
            protectedState.directValue.session
        }
        set {
            protectedState.write {
                $0.session = newValue
            }
        }
    }
    
    internal var headers: [String: String]? {
        get {
            protectedState.directValue.headers
        }
        set {
            protectedState.write {
                $0.headers = newValue
            }
        }
    }
    
    internal var verificationCode: String? {
        get {
            protectedState.directValue.verificationCode
        }
        set {
            protectedState.write {
                $0.verificationCode = newValue
            }
        }
    }
    
    internal var verificationType: ZYGDLFileChecksumHelper.VerificationType {
        get {
            protectedState.directValue.verificationType
        }
        set {
            protectedState.write {
                $0.verificationType = newValue
            }
        }
    }
    
    internal var isRemoveCompletely: Bool {
        get {
            protectedState.directValue.isRemoveCompletely
        }
        set {
            protectedState.write {
                $0.isRemoveCompletely = newValue
            }
        }
    }
    
    public internal(set) var status: ZYGDLStatus {
        get {
            protectedState.directValue.status
        }
        set {
            protectedState.write {
                $0.status = newValue
            }
            if newValue == .willSuspend ||
                newValue == .willCancel ||
                newValue == .willRemove {
                return
            }
            if self is ZYGDLDownloadTask {
                manager?.log(.downloadTask(newValue.rawValue, task: self as! ZYGDLDownloadTask))
            }
        }
    }
    
    public internal(set) var validation: Validation {
        get {
            protectedState.directValue.validation
        }
        set {
            protectedState.write {
                $0.validation = newValue
            }
        }
    }
    
    internal var currentURL: URL {
        get {
            protectedState.directValue.currentURL
        }
        set {
            protectedState.write {
                $0.currentURL = newValue
            }
        }
    }
    
    public internal(set) var startDate: Double {
        get {
            protectedState.directValue.startDate
        }
        set {
            protectedState.write {
                $0.startDate = newValue
            }
        }
    }
    
    public var startDateString: String {
        startDate.tr.convertTimeToDateString()
    }
    
    public internal(set) var endDate: Double {
        get {
            protectedState.directValue.endDate
        }
        set {
            protectedState.write {
                $0.endDate = newValue
            }
        }
    }
    
    public var endDateString: String {
        endDate.tr.convertTimeToDateString()
    }
    
    public internal(set) var speed: Int64 {
        get {
            protectedState.directValue.speed
        }
        set {
            protectedState.write {
                $0.speed = newValue
            }
        }
    }
    
    public var speedString: String {
        speed.tr.convertSpeedToString()
    }
    
    public internal(set) var fileName: String {
        get {
            protectedState.directValue.fileName
        }
        set {
            protectedState.write {
                $0.fileName = newValue
            }
        }
    }

    public internal(set) var timeRemaining: Int64 {
        get {
            protectedState.directValue.timeRemaining
        }
        set {
            protectedState.write {
                $0.timeRemaining = newValue
            }
        }
    }

    public var timeRemainingString: String {
        timeRemaining.tr.convertTimeToString()
    }

    public internal(set) var error: Error? {
        get {
            protectedState.directValue.error
        }
        set {
            protectedState.write {
                $0.error = newValue
            }
        }
    }

    internal var progressExecuter: ZYGDLExecuter<TaskType>? {
        get {
            protectedState.directValue.progressExecuter
        }
        set {
            protectedState.write {
                $0.progressExecuter = newValue
            }
        }
    }

    internal var successExecuter: ZYGDLExecuter<TaskType>? {
        get {
            protectedState.directValue.successExecuter
        }
        set {
            protectedState.write {
                $0.successExecuter = newValue
            }
        }
    }

    internal var failureExecuter: ZYGDLExecuter<TaskType>? {
        get {
            protectedState.directValue.failureExecuter
        }
        set {
            protectedState.write {
                $0.failureExecuter = newValue
            }
        }
    }

    internal var completionExecuter: ZYGDLExecuter<TaskType>? {
        get {
            protectedState.directValue.completionExecuter
        }
        set {
            protectedState.write {
                $0.completionExecuter = newValue
            }
        }
    }

    internal var controlExecuter: ZYGDLExecuter<TaskType>? {
        get {
            protectedState.directValue.controlExecuter
        }
        set {
            protectedState.write {
                $0.controlExecuter = newValue
            }
        }
    }

    internal var validateExecuter: ZYGDLExecuter<TaskType>? {
        get {
            protectedState.directValue.validateExecuter
        }
        set {
            protectedState.write {
                $0.validateExecuter = newValue
            }
        }
    }
    
    internal init(_ url: URL,
                  headers: [String: String]? = nil,
                  cache: ZYGDLCache,
                  operationQueue: DispatchQueue) {
        self.cache = cache
        self.url = url
        self.operationQueue = operationQueue
        protectedState = ZYGDLProtector(State(currentURL: url, fileName: url.tr.fileName))
        super.init()
        self.headers = headers
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(url, forKey: .url)
        try container.encode(currentURL, forKey: .currentURL)
        try container.encode(fileName, forKey: .fileName)
        try container.encodeIfPresent(headers, forKey: .headers)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(endDate, forKey: .endDate)
        try container.encode(progress.totalUnitCount, forKey: .totalBytes)
        try container.encode(progress.completedUnitCount, forKey: .completedBytes)
        try container.encode(status.rawValue, forKey: .status)
        try container.encodeIfPresent(verificationCode, forKey: .verificationCode)
        try container.encode(verificationType.rawValue, forKey: .verificationType)
        try container.encode(validation.rawValue, forKey: .validation)
        if let error = error {
            let errorData: Data
            if #available(iOS 11.0, *) {
                errorData = try NSKeyedArchiver.archivedData(withRootObject: (error as NSError), requiringSecureCoding: true)
            } else {
                errorData = NSKeyedArchiver.archivedData(withRootObject: (error as NSError))
            }
            try container.encode(errorData, forKey: .error)
        }
    }
    
    public required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        url = try container.decode(URL.self, forKey: .url)
        let currentURL = try container.decode(URL.self, forKey: .currentURL)
        let fileName = try container.decode(String.self, forKey: .fileName)
        protectedState = ZYGDLProtector(State(currentURL: currentURL, fileName: fileName))
        cache = decoder.userInfo[.cache] as? ZYGDLCache ?? ZYGDLCache("default")
        operationQueue = decoder.userInfo[.operationQueue] as? DispatchQueue ?? DispatchQueue(label: "com.ZYG.Downloaded.SessionManager.operationQueue")
        super.init()

        progress.totalUnitCount = try container.decode(Int64.self, forKey: .totalBytes)
        progress.completedUnitCount = try container.decode(Int64.self, forKey: .completedBytes)

        let statusString = try container.decode(String.self, forKey: .status)
        let verificationTypeInt = try container.decode(Int.self, forKey: .verificationType)
        let validationType = try container.decode(Int.self, forKey: .validation)

        try protectedState.write {
            $0.headers = try container.decodeIfPresent([String: String].self, forKey: .headers)
            $0.startDate = try container.decode(Double.self, forKey: .startDate)
            $0.endDate = try container.decode(Double.self, forKey: .endDate)
            $0.verificationCode = try container.decodeIfPresent(String.self, forKey: .verificationCode)
            $0.status = ZYGDLStatus(rawValue: statusString)!
            $0.verificationType = ZYGDLFileChecksumHelper.VerificationType(rawValue: verificationTypeInt)!
            $0.validation = Validation(rawValue: validationType)!
            if let errorData = try container.decodeIfPresent(Data.self, forKey: .error) {
                if #available(iOS 11.0, *) {
                    $0.error = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSError.self, from: errorData)
                } else {
                    $0.error = NSKeyedUnarchiver.unarchiveObject(with: errorData) as? NSError
                }
            }
        }
    }
    
    // 用于执行任务的处理程序。
    internal func execute(_ executer: ZYGDLExecuter<TaskType>?) {
        
    }
}

extension ZYGDLTask {
    
    // 用于设置任务进度的处理程序。
    @discardableResult
    public func progress(onMainQueue: Bool = true, handler: @escaping Handler<TaskType>) -> Self {
        // 创建一个 Executer 实例，并将其赋值给 progressExecuter。
        progressExecuter = ZYGDLExecuter(onMainQueue: onMainQueue, handle: handler)
        return self
    }
    
    // 用于设置任务成功的处理程序。
    @discardableResult
    public func success(onMainQueue: Bool = true, handler: @escaping Handler<TaskType>) -> Self {
        // 创建一个 Executer 实例，并将其赋值给 successExecuter。
        successExecuter = ZYGDLExecuter(onMainQueue: onMainQueue, handle: handler)
        
        // 如果任务状态为成功且没有完成的处理程序，则异步执行 successExecuter。
        if status == .succeeded && completionExecuter == nil {
            operationQueue.async {
                self.execute(self.successExecuter)
            }
        }
        return self
    }
    
    // 用于设置任务失败的处理程序。
    @discardableResult
    public func failure(onMainQueue: Bool = true, handler: @escaping Handler<TaskType>) -> Self {
        // 创建一个 Executer 实例，并将其赋值给 failureExecuter。
        failureExecuter = ZYGDLExecuter(onMainQueue: onMainQueue, handle: handler)
        
        if completionExecuter == nil &&
            (status == .suspended ||
             status == .canceled ||
             status == .removed ||
             status == .failed) {
            operationQueue.async {
                self.execute(self.failureExecuter)
            }
        }
        return self
    }
    
    // 用于设置任务完成的处理程序。
    @discardableResult
    public func completion(onMainQueue: Bool = true, handler: @escaping Handler<TaskType>) -> Self {
        // 创建一个 Executer 实例，并将其赋值给 completionExecuter。
        completionExecuter = ZYGDLExecuter(onMainQueue: onMainQueue, handle: handler)
        
        // 如果任务状态为暂停、取消、移除、成功或失败，则异步执行 completionExecuter。
        if status == .suspended ||
            status == .canceled ||
            status == .removed ||
            status == .succeeded ||
            status == .failed {
            operationQueue.async {
                self.execute(self.completionExecuter)
            }
        }
        return self
    }
}
