//
//  ZYGDLSessionManager.swift
//  ZygoteNetwork
//
//  Created by zhanlong on 2025/2/19.
//

import UIKit

public class ZYGDLSessionManager {
    
    enum MaintainTasksAction {
        case append(ZYGDLDownloadTask)
        case remove(ZYGDLDownloadTask)
        case succeeded(ZYGDLDownloadTask)
        case appendRunningTasks(ZYGDLDownloadTask)
        case removeRunningTasks(ZYGDLDownloadTask)
    }
    
    public let operationQueue: DispatchQueue
    
    public let cache: ZYGDLCache
    
    public let identifier: String
    
    public var completionHandler: (() -> Void)?
    
    public var configuration: ZYGDLSessionConfiguration {
        get {
            protectedState.directValue.configuration
        }
        set {
            operationQueue.sync {
                protectedState.write {
                    $0.configuration = newValue
                    if $0.status == .running {
                        totalSuspend()
                    }
                }
            }
        }
    }
    
    private struct State {
        var logger: ZYGDLLogable
        var isControlNetworkActivityIndicator: Bool = true
        var configuration: ZYGDLSessionConfiguration {
            didSet {
                guard !shouldCreatSession else {
                    return
                }
                shouldCreatSession = true
                if status == .running {
                    if configuration.maxConcurrentTasksLimit <= oldValue.maxConcurrentTasksLimit {
                        restartTasks = runningTasks + tasks.filter({ task in
                            task.status == .waiting
                        })
                    } else {
                        restartTasks = tasks.filter({ task in
                            task.status == .waiting || task.status == .running
                        })
                    }
                } else {
                    session?.invalidateAndCancel()
                    session = nil
                }
            }
        }
        var session: URLSession?
        var shouldCreatSession: Bool = false
        var timer: DispatchSourceTimer?
        var status: ZYGDLStatus = .waiting
        var tasks: [ZYGDLDownloadTask] = []
        var taskMapper: [String: ZYGDLDownloadTask] = [String: ZYGDLDownloadTask]()
        var urlMapper: [URL: URL] = [URL: URL]()
        var runningTasks: [ZYGDLDownloadTask] = []
        var restartTasks: [ZYGDLDownloadTask] = []
        var succeededTasks: [ZYGDLDownloadTask] = []
        var speed: Int64 = 0
        var timeRemaining: Int64 = 0
        
        var progressExecuter: ZYGDLExecuter<ZYGDLSessionManager>?
        var successExecuter: ZYGDLExecuter<ZYGDLSessionManager>?
        var failureExecuter: ZYGDLExecuter<ZYGDLSessionManager>?
        var completionExecuter: ZYGDLExecuter<ZYGDLSessionManager>?
        var controlExecuter: ZYGDLExecuter<ZYGDLSessionManager>?
    }
    
    private let protectedState: ZYGDLProtector<State>
    
    public var logger: ZYGDLLogable {
        get {
            protectedState.directValue.logger
        }
        set {
            protectedState.write {
                $0.logger = newValue
            }
        }
    }
    
    public var isControlNetworkActivityIndicator: Bool {
        get {
            protectedState.directValue.isControlNetworkActivityIndicator
        }
        set {
            protectedState.write {
                $0.isControlNetworkActivityIndicator = newValue
            }
        }
    }
    
    internal var shouldRun: Bool {
        return runningTasks.count < configuration.maxConcurrentTasksLimit
    }
    
    private var session: URLSession? {
        get {
            protectedState.directValue.session
        }
        set {
            protectedState.write {
                $0.session = newValue
            }
        }
    }
    
    private var shouldCreatSession: Bool {
        get {
            protectedState.directValue.shouldCreatSession
        }
        set {
            protectedState.write {
                $0.shouldCreatSession = newValue
            }
        }
    }
    
    private var timer: DispatchSourceTimer? {
        get {
            protectedState.directValue.timer
        }
        set {
            protectedState.write {
                $0.timer = newValue
            }
        }
    }
    
    public private(set) var status: ZYGDLStatus {
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
            log(.sessionManager(newValue.rawValue, manager: self))
        }
    }
    
    public private(set) var tasks: [ZYGDLDownloadTask] {
        get {
            protectedState.directValue.tasks
        }
        set {
            protectedState.write {
                $0.tasks = newValue
            }
        }
    }
    
    private var runningTasks: [ZYGDLDownloadTask] {
        get {
            protectedState.directValue.runningTasks
        }
        set {
            protectedState.write {
                $0.runningTasks = newValue
            }
        }
    }
    
    private var restartTasks: [ZYGDLDownloadTask] {
        get {
            protectedState.directValue.restartTasks
        }
        set {
            protectedState.write {
                $0.restartTasks = newValue
            }
        }
    }
    
    public private(set) var succeededTasks: [ZYGDLDownloadTask] {
        get {
            protectedState.directValue.succeededTasks
        }
        set {
            protectedState.write {
                $0.succeededTasks = newValue
            }
        }
    }
    
    private let _progress = Progress()
    public var progress: Progress {
        _progress.completedUnitCount = tasks.reduce(0, { partialResult, task in
            partialResult + task.progress.completedUnitCount
        })
        _progress.totalUnitCount = tasks.reduce(0, { partialResult, task in
            partialResult + task.progress.totalUnitCount
        })
        return _progress
    }
    
    public private(set) var speed: Int64 {
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
    
    public private(set) var timeRemaining: Int64 {
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
    
    private var progressExecuter: ZYGDLExecuter<ZYGDLSessionManager>? {
        get {
            protectedState.directValue.progressExecuter
        }
        set {
            protectedState.write {
                $0.progressExecuter = newValue
            }
        }
    }
    
    private var successExecuter: ZYGDLExecuter<ZYGDLSessionManager>? {
        get {
            protectedState.directValue.successExecuter
        }
        set {
            protectedState.write {
                $0.successExecuter = newValue
            }
        }
    }
    
    private var failureExecuter: ZYGDLExecuter<ZYGDLSessionManager>? {
        get {
            protectedState.directValue.failureExecuter
        }
        set {
            protectedState.write {
                $0.failureExecuter = newValue
            }
        }
    }
    
    private var completionExecuter: ZYGDLExecuter<ZYGDLSessionManager>? {
        get {
            protectedState.directValue.completionExecuter
        }
        set {
            protectedState.write {
                $0.completionExecuter = newValue
            }
        }
    }
    
    private var controlExecuter: ZYGDLExecuter<ZYGDLSessionManager>? {
        get {
            protectedState.directValue.controlExecuter
        }
        set {
            protectedState.write {
                $0.controlExecuter = newValue
            }
        }
    }
    
    public init(_ identifier: String,
                configuration: ZYGDLSessionConfiguration,
                logger: ZYGDLLogable? = nil,
                cache: ZYGDLCache? = nil,
                operationQueue: DispatchQueue = DispatchQueue(label: "com.ZYG.Downloaded.SessionManager.operationQueue",
                                                              autoreleaseFrequency: .workItem)) {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.ZYG.Downloaded"
        self.identifier = "\(bundleIdentifier).\(identifier)"
        protectedState = ZYGDLProtector(
            State(logger: logger ?? ZYGDLLogger(identifier: "\(bundleIdentifier).\(identifier)", option: .default), configuration: configuration)
        )
        self.operationQueue = operationQueue
        self.cache = cache ?? ZYGDLCache(identifier)
        self.cache.manager = self
        self.cache.retrieveAllTask().forEach { task in
            maintainTasks(with: .append(task))
        }
        succeededTasks = tasks.filter({ task in
            task.status == .succeeded
        })
        log(.sessionManager("retrieveTasks", manager: self))
        protectedState.write { state in
            state.tasks.forEach { task in
                task.manager = self
                task.operationQueue = operationQueue
                state.urlMapper[task.currentURL] = task.url
            }
            state.shouldCreatSession = true
        }
        operationQueue.sync {
            createSession()
            restoreStatus()
        }
    }
    
    deinit {
        invalidate()
    }
    
    public func invalidate() {
        session?.invalidateAndCancel()
        session = nil
        cache.invalidata()
        invalidateTimer()
    }
    
    private func createSession(_ completion: (() -> ())? = nil) {
        guard shouldCreatSession else {
            return
        }
        let sessionConfiguration = URLSessionConfiguration.background(withIdentifier: identifier)
        sessionConfiguration.timeoutIntervalForRequest = configuration.timeoutIntervalForRequest
        sessionConfiguration.httpMaximumConnectionsPerHost = 100000
        sessionConfiguration.allowsCellularAccess = configuration.allowsCellularAccess
        if #available(iOS 13, *) {
            sessionConfiguration.allowsConstrainedNetworkAccess = configuration.allowsConstrainedNetworkAccess
            sessionConfiguration.allowsExpensiveNetworkAccess = configuration.allowsExpensiveNetworkAccess
        }
        let sessionDelegate = ZYGDLSessionDelegate()
        sessionDelegate.manager = self
        let delegateQueue = OperationQueue(maxConCurrentOperationCount: 1, underlyingQueue: operationQueue, name: "com.ZYG.Downloaded.SessionManager.delegateQueue")
        protectedState.write {
            let session = URLSession(configuration: sessionConfiguration,
                                     delegate: sessionDelegate,
                                     delegateQueue: delegateQueue)
            $0.session = session
            $0.tasks.forEach { task in
                task.session = session
            }
            $0.shouldCreatSession = false
        }
        completion?()
    }
    
}

// MARK: - download
extension ZYGDLSessionManager {
    
    /// 开启一个下载任务
    ///
    /// - Parameters:
    ///   - url: URLConvertible
    ///   - headers: headers
    ///   - fileName: 下载文件的文件名，如果传nil，则默认为url的md5加上文件扩展名
    /// - Returns: 如果url有效，则返回对应的task；如果url无效，则返回nil
    @discardableResult
    public func download(_ url: ZYGDLURLConvertible,
                         headers: [String: String]? = nil,
                         fileName: String? = nil,
                         onMainQueue: Bool = true,
                         handler: Handler<ZYGDLDownloadTask>? = nil) -> ZYGDLDownloadTask? {
        do {
            let validURL = try url.asURL()
            var task: ZYGDLDownloadTask!
            operationQueue.sync {
                task = fetchTask(validURL)
                if let task = task {
                    task.update(headers, newFileName: fileName)
                } else {
                    task = ZYGDLDownloadTask(validURL,
                                             headers: headers,
                                             fileName: fileName,
                                             cache: cache,
                                             operationQueue: operationQueue)
                    task.manager = self
                    task.session = session
                    maintainTasks(with: .append(task))
                }
                storeTasks()
                start(task, onMainQueue: onMainQueue, handler: handler)
            }
            return task
        } catch {
            log(.error("create dowloadTask failed", error: error))
            return nil
        }
    }
    
    /// 批量开启多个下载任务, 所有任务都会并发下载
    ///
    /// - Parameters:
    ///   - urls: [URLConvertible]
    ///   - headers: headers
    ///   - fileNames: 下载文件的文件名，如果传nil，则默认为url的md5加上文件扩展名
    /// - Returns: 返回url数组中有效url对应的task数组
    @discardableResult
    public func multiDownload(_ urls: [ZYGDLURLConvertible],
                              headersArray: [[String: String]]? = nil,
                              fileNames: [String]? = nil,
                              onMainQueue: Bool = true,
                              handler: Handler<ZYGDLSessionManager>? = nil) -> [ZYGDLDownloadTask] {
        if let headersArray = headersArray, headersArray.count != 0 && headersArray.count != urls.count {
            log(.error("create multiple dowloadTasks failed", error: ZYGDLError.headersMatchFailed))
            return [ZYGDLDownloadTask]()
        }
        
        if let fileNames = fileNames, fileNames.count != 0 && fileNames.count != urls.count {
            log(.error("create multiple dowloadTasks failed", error: ZYGDLError.fileNamesMatchFailed))
            return [ZYGDLDownloadTask]()
        }
        
        var urlSet = Set<URL>()
        var uniqueTasks = [ZYGDLDownloadTask]()
        
        operationQueue.sync {
            for (index, url) in urls.enumerated() {
                let fileName = fileNames?.safeObject(at: index)
                let headers = headersArray?.safeObject(at: index)
                
                guard let validURL = try? url.asURL() else {
                    log(.error("create dowloadTask failed", error: ZYGDLError.invalidURL(url: url)))
                    continue
                }
                guard urlSet.insert(validURL).inserted else {
                    log(.error("create dowloadTask failed", error: ZYGDLError.duplicateURL(url: url)))
                    continue
                }
                
                var task: ZYGDLDownloadTask!
                task = fetchTask(validURL)
                if let task = task {
                    task.update(headers, newFileName: fileName)
                } else {
                    task = ZYGDLDownloadTask(validURL,
                                             headers: headers,
                                             fileName: fileName,
                                             cache: cache,
                                             operationQueue: operationQueue)
                    task.manager = self
                    task.session = session
                    maintainTasks(with: .append(task))
                }
                uniqueTasks.append(task)
            }
            storeTasks()
            ZYGDLExecuter(onMainQueue: onMainQueue, handle: handler).execute(self)
            operationQueue.async {
                uniqueTasks.forEach { task in
                    if task.status != .succeeded {
                        self._start(task)
                    }
                }
            }
        }
        return uniqueTasks
    }
}

// MARK: - single task control
extension ZYGDLSessionManager {
    
    public func fetchTask(_ url: ZYGDLURLConvertible) -> ZYGDLDownloadTask? {
        do {
            let validURL = try url.asURL()
            return protectedState.read {
                $0.taskMapper[validURL.absoluteString]
            }
        } catch {
            log(.error("fetch task failed", error: ZYGDLError.invalidURL(url: url)))
            return nil
        }
    }
    
    internal func mapTask(_ currentURL: URL) -> ZYGDLDownloadTask? {
        protectedState.read {
            let url = $0.urlMapper[currentURL] ?? currentURL
            return $0.taskMapper[url.absoluteString]
        }
    }
    
    /// 开启任务
    /// 会检查存放下载完成的文件中是否存在跟fileName一样的文件
    /// 如果存在则不会开启下载，直接调用task的successHandler
    public func start(_ url: ZYGDLURLConvertible,
                      onMainQueue: Bool = true,
                      handler: Handler<ZYGDLDownloadTask>? = nil) {
        operationQueue.async {
            self._start(url, onMainQueue: onMainQueue, handler: handler)
        }
    }
    
    public func start(_ task: ZYGDLDownloadTask,
                      onMainQueue: Bool = true,
                      handler: Handler<ZYGDLDownloadTask>? = nil) {
        operationQueue.async {
            guard let _ = self.fetchTask(task.url) else {
                self.log(.error("can't start downloadTask", error: ZYGDLError.fetchDownloadTaskFailed(url: task.url)))
                return
            }
            self._start(task, onMainQueue: onMainQueue, handler: handler)
        }
    }
    
    private func _start(_ url: ZYGDLURLConvertible,
                        onMainQueue: Bool = true,
                        handler: Handler<ZYGDLDownloadTask>? = nil) {
        guard let task = self.fetchTask(url) else {
            log(.error("can't start downloadTask", error: ZYGDLError.fetchDownloadTaskFailed(url: url)))
            return
        }
        _start(task, onMainQueue: onMainQueue, handler: handler)
    }
    
    private func _start(_ task: ZYGDLDownloadTask,
                        onMainQueue: Bool = true,
                        handler: Handler<ZYGDLDownloadTask>? = nil) {
        task.controlExecuter = ZYGDLExecuter(onMainQueue: onMainQueue, handle: handler)
        didStart()
        if !shouldCreatSession {
            task.download()
        } else {
            task.status = .suspended
            if !restartTasks.contains(task) {
                restartTasks.append(task)
            }
        }
    }
    
    /// 暂停任务，会触发sessionDelegate的完成回调
    public func suspend(_ url: ZYGDLURLConvertible,
                        onMainQueue: Bool = true,
                        handler: Handler<ZYGDLDownloadTask>? = nil) {
        operationQueue.async {
            guard let task = self.fetchTask(url) else {
                self.log(.error("can't suspend downloadTask", error: ZYGDLError.fetchDownloadTaskFailed(url: url)))
                return
            }
            task.suspend(onMainQueue: onMainQueue, handler: handler)
        }
    }
    
    public func suspend(_ task: ZYGDLDownloadTask,
                        onMainQueue: Bool = true,
                        handler: Handler<ZYGDLDownloadTask>? = nil) {
        operationQueue.async {
            guard let _ = self.fetchTask(task.url) else {
                self.log(.error("can't suspend downloadTask", error: ZYGDLError.fetchDownloadTaskFailed(url: task.url)))
                return
            }
            task.suspend(onMainQueue: onMainQueue, handler: handler)
        }
    }
    
    /// 取消任务
    /// 不会对已经完成的任务造成影响
    /// 其他状态的任务都可以被取消，被取消的任务会被移除
    /// 会删除还没有下载完成的缓存文件
    /// 会触发sessionDelegate的完成回调
    public func cancel(_ url: ZYGDLURLConvertible,
                       onMainQueue: Bool = true,
                       handler: Handler<ZYGDLDownloadTask>? = nil) {
        operationQueue.async {
            guard let task = self.fetchTask(url) else {
                self.log(.error("can't cancel downloadTask", error: ZYGDLError.fetchDownloadTaskFailed(url: url)))
                return
            }
            task.cancel(onMainQueue: onMainQueue, handler: handler)
        }
    }
    
    public func cancel(_ task: ZYGDLDownloadTask,
                       onMainQueue: Bool = true,
                       handler: Handler<ZYGDLDownloadTask>? = nil) {
        operationQueue.async {
            guard let _ = self.fetchTask(task.url) else {
                self.log(.error("can't cancel downloadTask", error: ZYGDLError.fetchDownloadTaskFailed(url: task.url)))
                return
            }
            task.cancel(onMainQueue: onMainQueue, handler: handler)
        }
    }
    
    /// 移除任务
    /// 所有状态的任务都可以被移除
    /// 会删除还没有下载完成的缓存文件
    /// 可以选择是否删除下载完成的文件
    /// 会触发sessionDelegate的完成回调
    ///
    /// - Parameters:
    ///   - url: URLConvertible
    ///   - completely: 是否删除下载完成的文件
    public func remove(_ url: ZYGDLURLConvertible,
                       completelty: Bool = false,
                       onMainQueue: Bool = true,
                       handler: Handler<ZYGDLDownloadTask>? = nil) {
        operationQueue.async {
            guard let task = self.fetchTask(url) else {
                self.log(.error("can't remove downloadTask", error: ZYGDLError.fetchDownloadTaskFailed(url: url)))
                return
            }
            task.remove(completely: completelty, onMainQueue: onMainQueue, handler: handler)
        }
    }
    
    public func remove(_ task: ZYGDLDownloadTask,
                       completelty: Bool = false,
                       onMainQueue: Bool = true,
                       handler: Handler<ZYGDLDownloadTask>? = nil) {
        operationQueue.async {
            guard let _ = self.fetchTask(task.url) else {
                self.log(.error("can't remove downloadTask", error: ZYGDLError.fetchDownloadTaskFailed(url: task.url)))
                return
            }
            task.remove(completely: completelty, onMainQueue: onMainQueue, handler: handler)
        }
    }
    
    public func moveTask(at sourceIndex: Int, to destinationIndex: Int) {
        operationQueue.sync {
            let range = (0..<tasks.count)
            guard range.contains(sourceIndex) && range.contains(destinationIndex) else {
                log(.error("move task failed, sourceIndex: \(sourceIndex), destinationIndex: \(destinationIndex)",
                                error: ZYGDLError.indexOutOfRange))
                return
            }
            if sourceIndex == destinationIndex {
                return
            }
            protectedState.write {
                let task = $0.tasks[sourceIndex]
                $0.tasks.remove(at: sourceIndex)
                $0.tasks.insert(task, at: destinationIndex)
            }
        }
    }
    
}

// MARK: - total tasks control
extension ZYGDLSessionManager {
    
    public func totalStart(onMainQueue: Bool = true,
                           handler: Handler<ZYGDLSessionManager>? = nil) {
        operationQueue.async {
            self.tasks.forEach { task in
                if task.status != .succeeded {
                    self._start(task)
                }
            }
            ZYGDLExecuter(onMainQueue: onMainQueue, handle: handler).execute(self)
        }
    }
    
    public func totalSuspend(onMainQueue: Bool = true,
                             handler: Handler<ZYGDLSessionManager>? = nil) {
        operationQueue.async {
            guard self.status == .running ||
                    self.status == .waiting else {
                return
            }
            self.status = .willSuspend
            self.controlExecuter = ZYGDLExecuter(onMainQueue: onMainQueue, handle: handler)
            self.tasks.forEach { task in
                task.suspend()
            }
        }
    }
    
    public func totalCancel(onMainQueue: Bool = true,
                            handler: Handler<ZYGDLSessionManager>? = nil) {
        operationQueue.async {
            guard self.status != .succeeded &&
                    self.status != .canceled else {
                return
            }
            self.status = .willCancel
            self.controlExecuter = ZYGDLExecuter(onMainQueue: onMainQueue, handle: handler)
            self.tasks.forEach { task in
                task.cancel()
            }
        }
    }
    
    public func totalRemove(completely: Bool = false,
                            onMainQueue: Bool = true,
                            handler: Handler<ZYGDLSessionManager>? = nil) {
        operationQueue.async {
            guard self.status != .removed else {
                return
            }
            self.status = .willRemove
            self.controlExecuter = ZYGDLExecuter(onMainQueue: onMainQueue, handle: handler)
            self.tasks.forEach { task in
                task.remove(completely: completely)
            }
        }
    }
    
    public func tasksSort(by areInIncreasingOrder: (ZYGDLDownloadTask, ZYGDLDownloadTask) throws -> Bool) rethrows {
        try operationQueue.sync {
            try protectedState.write {
                try $0.tasks.sort(by: areInIncreasingOrder)
            }
        }
    }
    
}

// MARK: - status handle
extension ZYGDLSessionManager {
    
    internal func maintainTasks(with action: MaintainTasksAction) {
        switch action {
        case let .append(task):
            protectedState.write {
                $0.tasks.append(task)
                $0.taskMapper[task.url.absoluteString] = task
                $0.urlMapper[task.currentURL] = task.url
            }
        case let .remove(task):
            protectedState.write {
                if $0.status == .willRemove {
                    $0.taskMapper.removeValue(forKey: task.url.absoluteString)
                    $0.urlMapper.removeValue(forKey: task.currentURL)
                    if $0.taskMapper.values.isEmpty {
                        $0.tasks.removeAll()
                        $0.succeededTasks.removeAll()
                    }
                } else if $0.status == .willCancel {
                    $0.taskMapper.removeValue(forKey: task.url.absoluteString)
                    $0.urlMapper.removeValue(forKey: task.currentURL)
                    if $0.taskMapper.values.count == $0.succeededTasks.count {
                        $0.tasks = $0.succeededTasks
                    }
                } else {
                    $0.taskMapper.removeValue(forKey: task.url.absoluteString)
                    $0.urlMapper.removeValue(forKey: task.currentURL)
                    $0.tasks.removeAll {
                        $0.url.absoluteString == task.url.absoluteString
                    }
                    if task.status == .removed {
                        $0.succeededTasks.removeAll {
                            $0.url.absoluteString == task.url.absoluteString
                        }
                    }
                }
            }
        case let .succeeded(task):
            succeededTasks.append(task)
        case let .appendRunningTasks(task):
            protectedState.write {
                $0.runningTasks.append(task)
            }
        case let .removeRunningTasks(task):
            protectedState.write {
                $0.runningTasks.removeAll {
                    $0.url.absoluteString == task.url.absoluteString
                }
            }
        }
    }
    
    internal func updateUrlMapper(with task: ZYGDLDownloadTask) {
        protectedState.write {
            $0.urlMapper[task.currentURL] = task.url
        }
    }
    
    private func restoreStatus() {
        if self.tasks.isEmpty {
            return
        }
        session?.getTasksWithCompletionHandler({ [weak self] (dataTasks, uploadTasks, downloadTasks) in
            guard let self = self else {
                return
            }
            downloadTasks.forEach { downloadTask in
                if downloadTask.state == .running,
                    let currentURL = downloadTask.currentRequest?.url,
                    let task = self.mapTask(currentURL) {
                    self.didStart()
                    self.maintainTasks(with: .appendRunningTasks(task))
                    task.status = .running
                    task.sessionTask = downloadTask
                }
            }
            //  处理mananger状态
            if !self.shouldComplete() {
                self.shouldComplete()
            }
        })
    }
    
    private func shouldComplete() -> Bool {
        let isSucceeded = self.tasks.allSatisfy { task in
            task.status == .succeeded
        }
        let isCompleted = isSucceeded ? isSucceeded : self.tasks.allSatisfy({ task in
            task.status == .succeeded || task.status == .failed
        })
        guard isCompleted else {
            return false
        }
        
        if status == .succeeded || status == .failed {
            return true
        }
        timeRemaining = 0
        progressExecuter?.execute(self)
        status = isSucceeded ? .succeeded : .failed
        executeCompletion(isSucceeded)
        return true
    }
    
    private func shouldSuspend() {
        let isSuspended = tasks.allSatisfy { task in
            task.status == .suspended ||
            task.status == .succeeded ||
            task.status == .failed
        }
        
        if isSuspended {
            if status == .suspended {
                return
            }
            status = .suspended
            executeControl()
            executeCompletion(false)
            if shouldCreatSession {
                session?.invalidateAndCancel()
                session = nil
            }
        }
    }
    
    internal func didStart() {
        if status != .running {
            createTimer()
            status = .running
            progressExecuter?.execute(self)
        }
    }
    
    internal func updateProgress() {
        if isControlNetworkActivityIndicator {
            DispatchQueue.tr.executeOnMain {
                UIApplication.shared.isNetworkActivityIndicatorVisible = true
            }
        }
        progressExecuter?.execute(self)
        NotificationCenter.default.postNotification(name: ZYGDLSessionManager.runningNotification, sessionManager: self)
    }
    
    internal func didCancelOrRemove(_ task: ZYGDLDownloadTask) {
        maintainTasks(with: .remove(task))
        
        // 处理使用单个任务操作移除最后一个task时，manager状态
        if tasks.isEmpty {
            if task.status == .canceled {
                status = .willCancel
            }
            if task.status == .removed {
                status = .willRemove
            }
        }
    }
    
    internal func storeTasks() {
        cache.storeTasks(tasks)
    }
    
    internal func determineStatus(fromRunningTask: Bool) {
        if isControlNetworkActivityIndicator {
            DispatchQueue.tr.executeOnMain {
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
            }
        }
        
        // removed
        if status == .willRemove {
            if tasks.isEmpty {
                status = .removed
                executeControl()
                ending(false)
            }
            return
        }
        
        // canceled
        if status == .willCancel {
            let succeededTasksCount = protectedState.directValue.taskMapper.values.count
            if tasks.count == succeededTasksCount {
                status = .canceled
                executeControl()
                ending(false)
            }
            return
        }
        
        // completed
        let isCompleted = tasks.allSatisfy { task in
            task.status == .succeeded || task.status == .failed
        }
        
        if isCompleted {
            if status == .succeeded || status == .failed {
                storeTasks()
                return
            }
            timeRemaining = 0
            progressExecuter?.execute(self)
            let isSucceeded = tasks.allSatisfy { task in
                task.status == .succeeded
            }
            status = isSucceeded ? .succeeded : .failed
            ending(isSucceeded)
            return
        }
        
        // suspended
        let isSuspended = tasks.allSatisfy { task in
            task.status == .suspended || task.status == .succeeded || task.status == .failed
        }
        
        if isSuspended {
            if status == .suspended {
                storeTasks()
                return
            }
            status = .suspended
            if shouldCreatSession {
                session?.invalidateAndCancel()
                session = nil
            } else {
                executeControl()
                ending(false)
            }
            return
        }
        
        if status == .willSuspend {
            return
        }
        
        storeTasks()
        
        if fromRunningTask {
            // next task
            operationQueue.async {
                self.startNextTask()
            }
        }
    }
    
    private func ending(_ isSucceeded: Bool) {
        executeCompletion(isSucceeded)
        storeTasks()
        invalidateTimer()
    }
    
    private func startNextTask() {
        guard let waitingTask = tasks.first(where: { $0.status == .waiting }) else {
            return
        }
        waitingTask.download()
    }
    
}

// MARK: - info
extension ZYGDLSessionManager {
    
    static let refreshInterval: Double = 1
    
    private func createTimer() {
        if timer == nil {
            timer = DispatchSource.makeTimerSource(flags: .strict, queue: operationQueue)
            timer?.schedule(deadline: .now(), repeating: Self.refreshInterval)
            timer?.setEventHandler(handler: { [weak self] in
                guard let self = self else {
                    return
                }
                self.updateSpeedAndTimeRemaining()
            })
            timer?.resume()
        }
    }
    
    private func invalidateTimer() {
        timer?.cancel()
        timer = nil
    }
    
    internal func updateSpeedAndTimeRemaining() {
        let speed = runningTasks.reduce(Int64(0)) { partialResult, task in
            task.updateSpeedAndTimeRemaining()
            return partialResult + task.speed
        }
        updateTimeRemaining(speed)
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
    
    internal func log(_ type: ZYGDLLogType) {
        logger.log(type)
    }
    
}

// MARK: - closure
extension ZYGDLSessionManager {
    
    @discardableResult
    public func progress(onMainQueue: Bool = true, handler: @escaping Handler<ZYGDLSessionManager>) -> Self {
        progressExecuter = ZYGDLExecuter(onMainQueue: onMainQueue, handle: handler)
        return self
    }
    
    @discardableResult
    public func success(onMainQueue: Bool = true, handler: @escaping Handler<ZYGDLSessionManager>) -> Self {
        successExecuter = ZYGDLExecuter(onMainQueue: onMainQueue, handle: handler)
        if status == .succeeded && completionExecuter == nil {
            operationQueue.async {
                self.successExecuter?.execute(self)
            }
        }
        return self
    }
    
    @discardableResult
    public func failure(onMainQueue: Bool = true, handler: @escaping Handler<ZYGDLSessionManager>) -> Self {
        failureExecuter = ZYGDLExecuter(onMainQueue: onMainQueue, handle: handler)
        if completionExecuter == nil &&
            (status == .suspended ||
             status == .canceled ||
             status == .removed ||
             status == .failed) {
            operationQueue.async {
                self.failureExecuter?.execute(self)
            }
        }
        return self
    }
    
    @discardableResult
    public func completion(onMainQueue: Bool = true, handler: @escaping Handler<ZYGDLSessionManager>) -> Self {
        completionExecuter = ZYGDLExecuter(onMainQueue: onMainQueue, handle: handler)
        
        if status == .suspended ||
            status == .canceled ||
            status == .removed ||
            status == .succeeded ||
            status == .failed {
            operationQueue.async {
                self.completionExecuter?.execute(self)
            }
        }
        return self
    }
    
    private func executeCompletion(_ isSucceeded: Bool) {
        if let completionExecuter = completionExecuter {
            completionExecuter.execute(self)
        } else if isSucceeded {
            successExecuter?.execute(self)
        } else {
            failureExecuter?.execute(self)
        }
        NotificationCenter.default.postNotification(name: ZYGDLSessionManager.didCompleteNotification, sessionManager: self)
    }
    
    private func executeControl() {
        controlExecuter?.execute(self)
        controlExecuter = nil
    }
    
}

// MARK: - call back
extension ZYGDLSessionManager {
    
    internal func didBecomeInvalidation(withError error: Error?) {
        createSession { [weak self] in
            guard let self = self else {
                return
            }
            self.restartTasks.forEach { task in
                self._start(task)
            }
            self.restartTasks.removeAll()
        }
    }
    
    internal func didFinishEvent(forBackgroundURLSession session: URLSession) {
        DispatchQueue.tr.executeOnMain {
            self.completionHandler?()
            self.completionHandler = nil
        }
    }
    
}
