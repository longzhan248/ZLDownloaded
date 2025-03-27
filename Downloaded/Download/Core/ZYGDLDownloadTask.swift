//
//  ZYGDLDownloadTask.swift
//  ZygoteNetwork
//
//  Created by zhanlong on 2025/2/20.
//

import UIKit
import ZIPFoundation

public class ZYGDLDownloadTask: ZYGDLTask<ZYGDLDownloadTask> {
    
    // 用于编码和解码任务的属性。
    private enum CodingKeys: CodingKey {
        case resumeData
        case response
    }
    
    // 表示可接受的状态码范围。
    private var acceptableStatusCodes: Range<Int> {
        return 200..<300
    }
    
    // 用于存储 URLSessionDownloadTask。
    private var _sessionTask: URLSessionDownloadTask? {
        willSet {
            _sessionTask?.removeObserver(self, forKeyPath: "currentRequest")
        }
        didSet {
            _sessionTask?.addObserver(self, forKeyPath: "currentRequest", options: [.new], context: nil)
        }
    }
    
    // 用于获取和设置 _sessionTask。
    internal var sessionTask: URLSessionDownloadTask? {
        get {
            protectedDownloadState.read { _ in _sessionTask }
        }
        set {
            protectedDownloadState.read { _ in _sessionTask = newValue }
        }
    }
    
    // 用于存储 HTTP 响应。
    public internal(set) var response: HTTPURLResponse? {
        get {
            protectedDownloadState.directValue.response
        }
        set {
            protectedDownloadState.write { $0.response = newValue }
        }
    }
    
    // 用于获取 HTTP 响应的状态码。
    public var statusCode: Int? {
        response?.statusCode
    }
    
    // 用于获取文件路径。
    public var filePath: String {
        return cache.filePath(fileName: fileName)!
    }
    
    // 用于获取文件扩展名。
    public var pathExtension: String? {
        let pathExtension = (filePath as NSString).pathExtension
        return pathExtension.isEmpty ? nil : pathExtension
    }
    
    // 用于存储下载状态。
    private struct DownloadState {
        var resumeData: Data? {
            didSet {
                guard let resumeData = resumeData else { return }
                tmpFileName = ZYGDLResumeDataHelper.getTmpFileName(resumeData)
            }
        }
        var response: HTTPURLResponse?
        var tmpFileName: String?
        var shouldValidateFile: Bool = false
    }
    
    // 用于保护下载状态。
    private let protectedDownloadState: ZYGDLProtector<DownloadState> = ZYGDLProtector(DownloadState())
    
    // 用于获取和设置下载恢复数据。
    private var resumeData: Data? {
        get {
            protectedDownloadState.directValue.resumeData
        }
        set {
            protectedDownloadState.write { $0.resumeData = newValue }
        }
    }
    
    // 用于获取临时文件名。
    internal var tmpFileName: String? {
        protectedDownloadState.directValue.tmpFileName
    }
    
    // 用于获取和设置是否需要验证文件。
    private var shouldValidateFile: Bool {
        get {
            protectedDownloadState.directValue.shouldValidateFile
        }
        set {
            protectedDownloadState.write { $0.shouldValidateFile = newValue }
        }
    }
    
    internal init(_ url: URL,
                  headers: [String: String]? = nil,
                  fileName: String? = nil,
                  cache: ZYGDLCache,
                  operationQueue: DispatchQueue) {
        super.init(url,
                   headers: headers,
                   cache: cache,
                   operationQueue: operationQueue)
        if let fileName = fileName, !fileName.isEmpty {
            self.fileName = fileName
        }
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(fixDelegateMethodError),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)
    }
    
    // 实现编码方法。
    public override func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let superEncoder = container.superEncoder()
        try super.encode(to: superEncoder)
        try container.encodeIfPresent(resumeData, forKey: .resumeData)
        if let response = response {
            let responseData: Data
            if #available(iOS 11.0, *) {
                responseData = try NSKeyedArchiver.archivedData(withRootObject: (response as HTTPURLResponse), requiringSecureCoding: true)
            } else {
                responseData = NSKeyedArchiver.archivedData(withRootObject: (response as HTTPURLResponse))
            }
            try container.encode(responseData, forKey: .response)
        }
    }
    
    // 实现解码方法。
    internal required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
        resumeData = try container.decodeIfPresent(Data.self, forKey: .resumeData)
        if let responseData = try container.decodeIfPresent(Data.self, forKey: .response) {
            if #available(iOS 11.0, *) {
                response = try? NSKeyedUnarchiver.unarchivedObject(ofClass: HTTPURLResponse.self, from: responseData)
            } else {
                response = NSKeyedUnarchiver.unarchiveObject(with: responseData) as? HTTPURLResponse
            }
        }
    }
    
    // 析构方法。
    deinit {
        sessionTask?.removeObserver(self, forKeyPath: "currentRequest")
        NotificationCenter.default.removeObserver(self)
    }
    
    // 用于修复委托方法错误。
    @objc private func fixDelegateMethodError() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.sessionTask?.suspend()
            self.sessionTask?.resume()
        }
    }
    
    internal override func execute(_ executer: ZYGDLExecuter<ZYGDLDownloadTask>?) {
        executer?.execute(self)
    }
}

// MARK: - control
extension ZYGDLDownloadTask {
    
    // 用于开始下载任务。
    internal func download() {
        cache.createDirectory()
        guard let manager = manager else { return }
        switch status {
        case .waiting, .suspended, .failed:
            if cache.fileExists(fileName: fileName) {
                prepareForDownload(fileExists: true)
            } else {
                if manager.shouldRun {
                    prepareForDownload(fileExists: false)
                } else {
                    status = .waiting
                    progressExecuter?.execute(self)
                    executeControl()
                }
            }
        case .succeeded:
            executeControl()
            succeeded(fromRunning: false, immediately: false)
        case .running:
            status = .running
            executeControl()
        default: break
        }
    }
    
    // 用于准备下载任务。
    private func prepareForDownload(fileExists: Bool) {
        status = .running
        protectedState.write {
            $0.speed = 0
            if $0.startDate == 0 {
                 $0.startDate = Date().timeIntervalSince1970
            }
        }
        error = nil
        start(fileExists: fileExists)
    }
    
    // 用于开始下载任务。
    private func start(fileExists: Bool) {
        if fileExists {
            manager?.log(.downloadTask("file already exists", task: self))
            if let fileInfo = try? FileManager.default.attributesOfItem(atPath: cache.filePath(fileName: fileName)!),
                let length = fileInfo[.size] as? Int64 {
                progress.totalUnitCount = length
            }
            executeControl()
            operationQueue.async {
                self.didComplete(.local)
            }
        } else {
            if let resumeData = resumeData,
                cache.retrieveTmpFile(tmpFileName) {
                if #available(iOS 10.2, *) {
                    sessionTask = session?.downloadTask(withResumeData: resumeData)
                } else if #available(iOS 10.0, *) {
                    sessionTask = session?.correctedDownloadTask(withResumeData: resumeData)
                } else {
                    sessionTask = session?.downloadTask(withResumeData: resumeData)
                }
            } else {
                var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 0)
                if let headers = headers {
                    request.allHTTPHeaderFields = headers
                }
                sessionTask = session?.downloadTask(with: request)
                progress.completedUnitCount = 0
                progress.totalUnitCount = 0
            }
            progress.setUserInfoObject(progress.completedUnitCount, forKey: .fileCompletedCountKey)
            executeControl()
            sessionTask?.resume()
        }
    }
    
    // 用于暂停下载任务。
    internal func suspend(onMainQueue: Bool = true, handler: Handler<ZYGDLDownloadTask>? = nil) {
        guard status == .running || status == .waiting else { return }
        controlExecuter = ZYGDLExecuter(onMainQueue: onMainQueue, handler: handler)
        if status == .running {
            status = .willSuspend
            sessionTask?.cancel(byProducingResumeData: { _ in })
        } else {
            status = .willSuspend
            operationQueue.async {
                self.didComplete(.local)
            }
        }
    }
    
    // 用于取消下载任务。
    internal func cancel(onMainQueue: Bool = true, handler: Handler<ZYGDLDownloadTask>? = nil) {
        guard status != .succeeded else { return }
        controlExecuter = ZYGDLExecuter(onMainQueue: onMainQueue, handler: handler)
        if status == .running {
            status = .willCancel
            sessionTask?.cancel()
        } else {
            status = .willCancel
            operationQueue.async {
                self.didComplete(.local)
            }
        }
    }
    
    // 用于移除下载任务。
    internal func remove(completely: Bool = false, onMainQueue: Bool = true, handler: Handler<ZYGDLDownloadTask>? = nil) {
        isRemoveCompletely = completely
        controlExecuter = ZYGDLExecuter(onMainQueue: onMainQueue, handler: handler)
        if status == .running {
            status = .willRemove
            sessionTask?.cancel()
        } else {
            status = .willRemove
            operationQueue.async {
                self.didComplete(.local)
            }
        }
    }
    
    // 用于更新下载任务的请求头和文件名。
    internal func update(_ newHeaders: [String: String]? = nil, newFileName: String? = nil) {
        headers = newHeaders
        if let newFileName = newFileName, !newFileName.isEmpty {
            cache.updateFileName(filePath, newFileName)
            fileName = newFileName
        }
    }
    
    
    private func validateFile() {
        guard let validateHandler = self.validateExecuter else { return }

        if !shouldValidateFile {
            validateHandler.execute(self)
            return
        }

        guard let verificationCode = verificationCode else { return }

        ZYGDLFileChecksumHelper.validateFile(filePath, code: verificationCode, type: verificationType) { [weak self] (result) in
            guard let self = self else { return }
            self.shouldValidateFile = false
            if case let .failure(error) = result {
                self.validation = .incorrect
                self.manager?.log(.error("file validation failed, url: \(self.url)", error: error))
            } else {
                self.validation = .correct
                self.manager?.log(.downloadTask("file validation successful", task: self))
            }
            self.manager?.storeTasks()
            validateHandler.execute(self)
        }
    }
}

// MARK: - status handle
extension ZYGDLDownloadTask {
    
    // 用于处理任务取消或移除后的操作。
    private func didCancelOrRemove() {
        // 把预操作的状态改成完成操作的状态
        if status == .willCancel {
            status = .canceled
        }
        if status == .willRemove {
            status = .removed
        }
        cache.remove(self, completely: isRemoveCompletely)
        
        manager?.didCancelOrRemove(self)
    }
    
    // 用于处理任务成功后的操作。
    internal func succeeded(fromRunning: Bool, immediately: Bool) {
        if endDate == 0 {
            protectedState.write {
                $0.endDate = Date().timeIntervalSince1970
                $0.timeRemaining = 0
            }
        }
        status = .succeeded
        progress.completedUnitCount = progress.totalUnitCount
        progressExecuter?.execute(self)
        if immediately {
            executeCompletion(true)
        }
        validateFile()
        manager?.maintainTasks(with: .succeeded(self))
        manager?.determineStatus(fromRunningTask: fromRunning)
    }
    
    // 用于根据中断类型确定任务状态。
    private func determineStatus(with interruptType: InterruptType) {
        var fromRunning = true
        switch interruptType {
        case let .error(error):
            self.error = error
            var tempStatus = status
            if let resumeData = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
                self.resumeData = ZYGDLResumeDataHelper.handleResumeData(resumeData)
                cache.storeTmpFile(tmpFileName)
            }
            if let _ = (error as NSError).userInfo[NSURLErrorBackgroundTaskCancelledReasonKey] as? Int {
                tempStatus = .suspended
            }
            if let urlError = error as? URLError, urlError.code != URLError.cancelled {
                tempStatus = .failed
            }
            status = tempStatus
        case let .statusCode(statusCode):
            self.error = ZYGDLError.unacceptableStatusCode(code: statusCode)
            status = .failed
        case .manual:
            fromRunning = false
        }
        
        switch status {
        case .willSuspend:
            status = .suspended
            progressExecuter?.execute(self)
            executeControl()
            executeCompletion(false)
        case .willCancel, .willRemove:
            didCancelOrRemove()
            executeControl()
            executeCompletion(false)
        case .suspended, .failed:
            progressExecuter?.execute(self)
            executeCompletion(false)
        default:
            status = .failed
            progressExecuter?.execute(self)
            executeCompletion(false)
        }
        manager?.determineStatus(fromRunningTask: fromRunning)
    }
}

// MARK: - closure
extension ZYGDLDownloadTask {
    
    // 用于设置文件验证的处理程序。
    @discardableResult
    public func validateFile(code: String,
                             type: ZYGDLFileChecksumHelper.VerificationType,
                             onMainQueue: Bool = true,
                             handler: @escaping Handler<ZYGDLDownloadTask>) -> Self {
        operationQueue.async {
           let (verificationCode, verificationType) = self.protectedState.read {
                                                           ($0.verificationCode, $0.verificationType)
                                                       }
           if verificationCode == code &&
               verificationType == type &&
               self.validation != .unkown {
               self.shouldValidateFile = false
           } else {
               self.shouldValidateFile = true
               self.protectedState.write {
                   $0.verificationCode = code
                   $0.verificationType = type
               }
               self.manager?.storeTasks()
           }
           self.validateExecuter = ZYGDLExecuter(onMainQueue: onMainQueue, handler: handler)
           if self.status == .succeeded {
               self.validateFile()
           }
       }
       return self
    }
    
    // 用于执行任务完成的处理程序。
    private func executeCompletion(_ isSucceeded: Bool) {
        if let completionExecuter = completionExecuter {
            completionExecuter.execute(self)
        } else if isSucceeded {
            successExecuter?.execute(self)
        } else {
            failureExecuter?.execute(self)
        }
        NotificationCenter.default.postNotification(name: ZYGDLDownloadTask.didCompleteNotification, downloadTask: self)
    }
    
    // 用于执行控制处理程序。
    private func executeControl() {
        controlExecuter?.execute(self)
        controlExecuter = nil
    }
}

// MARK: - KVO
extension ZYGDLDownloadTask {
    
    // 用于观察任务的属性变化。
    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if let change = change, let newRequest = change[NSKeyValueChangeKey.newKey] as? URLRequest, let url = newRequest.url {
            currentURL = url
            manager?.updateUrlMapper(with: self)
        }
    }
    
}

// MARK: - info
extension ZYGDLDownloadTask {
    
    internal func updateSpeedAndTimeRemaining() {
        
        let dataCount = progress.completedUnitCount
        let lastData: Int64 = progress.userInfo[.fileCompletedCountKey] as? Int64 ?? 0

        if dataCount > lastData {
            let speed = dataCount - lastData
            updateTimeRemaining(speed)
        }
        progress.setUserInfoObject(dataCount, forKey: .fileCompletedCountKey)
    }
    
    private func updateTimeRemaining(_ speed: Int64) {
        var timeRemaining: Double
        if speed != 0 {
            timeRemaining = (Double(progress.totalUnitCount) - Double(progress.completedUnitCount)) / Double(speed)
            if timeRemaining >= 0.8 && timeRemaining < 1 {
                timeRemaining += 1
            }
        } else {
            timeRemaining = 0
        }
        protectedState.write {
            $0.speed = speed
            $0.timeRemaining = Int64(timeRemaining)
        }
    }
    
}

// MARK: - callback
extension ZYGDLDownloadTask {
    
    internal func didWriteData(bytesWritten: Int64,
                               totalBytesWritten: Int64,
                               totalBytesExpectedToWrite: Int64) {
        progress.completedUnitCount = totalBytesWritten
        progress.totalUnitCount = totalBytesExpectedToWrite
        progressExecuter?.execute(self)
        manager?.updateProgress()
        NotificationCenter.default.postNotification(name: ZYGDLDownloadTask.runningNotification, downloadTask: self)
    }
    
    internal func didFinishDownloading(task: URLSessionDownloadTask,
                                       to location: URL) {
        guard let statusCode = (task.response as? HTTPURLResponse)?.statusCode,
            acceptableStatusCodes.contains(statusCode)
            else { return }
        if let pathExtension = pathExtension {
            let fileType = ZYGDLFileType(fileExtension:pathExtension)
            switch fileType {
            case .zip:
                let fileManager = FileManager()
                let sourceURL = URL(fileURLWithPath: location.path)
                let destinationURL = URL(fileURLWithPath: filePath)
                do {
                    try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
                    try fileManager.unzipItem(at: sourceURL, to: destinationURL)
                    cache.storeFile(at: destinationURL, to: destinationURL)
                    cache.removeTmpFile(tmpFileName)
                } catch {
                    print("Extraction of ZIP archive failed with error:\(error)")
                }
                return
            default:
                break
            }
        }
        cache.storeFile(at: location, to: URL(fileURLWithPath: filePath))
        cache.removeTmpFile(tmpFileName)
    }
    
    internal func didComplete(_ type: CompletionType) {
        switch type {
        case .local:
            
            switch status {
            case .willSuspend,.willCancel, .willRemove:
                determineStatus(with: .manual)
            case .running:
                succeeded(fromRunning: false, immediately: true)
            default:
                return
            }
            
        case let .network(task, error):
            manager?.maintainTasks(with: .removeRunningTasks(self))
            sessionTask = nil

            switch status {
            case .willCancel, .willRemove:
                determineStatus(with: .manual)
                return
            case .willSuspend, .running:
                progress.totalUnitCount = task.countOfBytesExpectedToReceive
                progress.completedUnitCount = task.countOfBytesReceived
                progress.setUserInfoObject(task.countOfBytesReceived, forKey: .fileCompletedCountKey)
                
                let statusCode = (task.response as? HTTPURLResponse)?.statusCode ?? -1
                let isAcceptable = acceptableStatusCodes.contains(statusCode)
                
                if error != nil {
                    response = task.response as? HTTPURLResponse
                    determineStatus(with: .error(error!))
                } else if !isAcceptable {
                    response = task.response as? HTTPURLResponse
                    determineStatus(with: .statusCode(statusCode))
                } else {
                    resumeData = nil
                    succeeded(fromRunning: true, immediately: true)
                }
            default:
                return
            }
        }
    }
    
}

extension Array where Element == ZYGDLDownloadTask {
    
    @discardableResult
    public func progress(onMainQueue: Bool = true, handler: @escaping Handler<ZYGDLDownloadTask>) -> [Element] {
        self.forEach { $0.progress(onMainQueue: onMainQueue, handler: handler) }
        return self
    }
    
    @discardableResult
    public func success(onMainQueue: Bool = true, handler: @escaping Handler<ZYGDLDownloadTask>) -> [Element] {
        self.forEach { $0.success(onMainQueue: onMainQueue, handler: handler) }
        return self
    }
    
    @discardableResult
    public func failure(onMainQueue: Bool = true, handler: @escaping Handler<ZYGDLDownloadTask>) -> [Element] {
        self.forEach { $0.failure(onMainQueue: onMainQueue, handler: handler) }
        return self
    }
    
    public func validateFile(codes: [String],
                             type: ZYGDLFileChecksumHelper.VerificationType,
                             onMainQueue: Bool = true,
                             handler: @escaping Handler<ZYGDLDownloadTask>) -> [Element] {
        for (index, task) in self.enumerated() {
            guard let code = codes.safeObject(at: index) else { continue }
            task.validateFile(code: code, type: type, onMainQueue: onMainQueue, handler: handler)
        }
        return self
    }
    
}
