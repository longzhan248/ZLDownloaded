/*
 * 公司版权声明: Copyright (c) 广州心娱网络科技有限公司. All rights reserved.
 * 开发人员: 詹龙 zhanlong@yunqi688.com
 * 员工工号: XY-0398
 * 内部IM ID: 957
 * 手机尾号: 5352
 * 创建日期: 2026-10-14
 */

//
//  ZYGDLBGSessionManager.swift
//  ZygoteNetwork
//
//  Created by zhanlong on 2025/3/4.
//

import UIKit
import ZLDownloaded

// 在下载队列调用协议转换，支持自定义 URLConvertible，避免强制类型转换。
private struct ZYGDLBGAsyncURLConvertible: ZYGDLURLConvertible {
    let value: ZYGDLBGURLConvertible
    func asURL() throws -> URL { return try value.bg_asURL() }
}

/// 业务完成代理；不替换 URLSession 的内部代理，也不覆盖现有任务闭包。
@objc public protocol ZYGDLBGSessionManagerDownloadDelegate: AnyObject {
    /// 主线程异步回调，业务方按 URL 和当前订阅状态处理重试及重复事件。
    func downloadManager(_ manager: ZYGDLBGSessionManager, didComplete task: ZYGDLBGDownloadTask)
}

@objcMembers public class ZYGDLBGSessionManager: NSObject, ZYGDLSessionManagerDownloadDelegate {
    /// 弱引用代理，请在主线程设置。
    public weak var downloadDelegate: ZYGDLBGSessionManagerDownloadDelegate?

    
    private let sessionManager: ZYGDLSessionManager
    
    public let operationQueue: DispatchQueue
    
    public let cache: ZYGDLBGCache
    
    public let identifier: String
    
    public var completionHandler: (() -> Void)? {
        get {
            return sessionManager.completionHandler
        }
        set {
            sessionManager.completionHandler = newValue
        }
    }
    
    public var configuration: ZYGDLBGSessionConfiguration {
        didSet {
            configuration.sessionManager = sessionManager
            var config = ZYGDLSessionConfiguration()
            config.timeoutIntervalForRequest = configuration.timeoutIntervalForRequest
            config.maxConcurrentTasksLimit = configuration.maxConcurrentTasksLimit
            config.allowsCellularAccess = configuration.allowsCellularAccess
            sessionManager.configuration = config
        }
    }
    
    public var status: ZYGDLBGStatus {
        return ZYGDLBGStatus(sessionManager.status)
    }
    
    private let tasksLock = NSLock()
    private var storedTasks: [ZYGDLBGDownloadTask] = []

    public var tasks: [ZYGDLBGDownloadTask] {
        tasksLock.lock()
        defer { tasksLock.unlock() }
        return storedTasks
    }

    private func bridgeTask(_ task: ZYGDLDownloadTask) -> ZYGDLBGDownloadTask {
        tasksLock.lock()
        defer { tasksLock.unlock() }
        if let existing = storedTasks.first(where: { $0.downloadTask === task }) { return existing }
        let wrapped = ZYGDLBGDownloadTask(task)
        storedTasks.append(wrapped)
        return wrapped
    }

    private func removeBridgeTasks(url: URL? = nil) {
        tasksLock.lock()
        defer { tasksLock.unlock() }
        if let url = url { storedTasks.removeAll { $0.url == url } }
        else { storedTasks.removeAll() }
    }
    
    
    public var completedTasks: [ZYGDLBGDownloadTask] {
        return tasks.filter { $0.status == .succeeded }
    }
    
    public var progress: Progress {
        return sessionManager.progress
    }
    
    public var speed: Int64 {
        return sessionManager.speed
    }
    
    public var timeRemaining: Int64 {
        return sessionManager.timeRemaining
    }
    
    
    public init(identifier: String,
                configuration: ZYGDLBGSessionConfiguration,
                cache: ZYGDLBGCache? = nil,
                operationQueue: DispatchQueue = DispatchQueue(label: "com.ZYG.Downloaded.SessionManager.operationQueue",
                                                              autoreleaseFrequency: .workItem)) {
        self.identifier = identifier
        self.operationQueue = operationQueue
        var config = ZYGDLSessionConfiguration()
        config.timeoutIntervalForRequest = configuration.timeoutIntervalForRequest
        config.maxConcurrentTasksLimit = configuration.maxConcurrentTasksLimit
        config.allowsCellularAccess = configuration.allowsCellularAccess
        self.configuration = configuration
        self.cache = cache ?? ZYGDLBGCache(identifier)
        sessionManager = ZYGDLSessionManager(identifier, configuration: config, cache:self.cache.cache, operationQueue: operationQueue)
        self.configuration.sessionManager = sessionManager
        super.init()
        storedTasks = sessionManager.tasks.map { ZYGDLBGDownloadTask($0) }
        sessionManager.downloadDelegate = self
        
    }
    
    public convenience init(identifier: String,
                            configuration: ZYGDLBGSessionConfiguration,
                            operationQueue: DispatchQueue) {
        self.init(identifier: identifier, configuration: configuration, cache: nil, operationQueue: operationQueue)
    }

    public convenience init(identifier: String,
                            configuration: ZYGDLBGSessionConfiguration) {
        self.init(identifier: identifier, configuration: configuration, operationQueue: DispatchQueue(label: "com.ZYG.Downloaded.SessionManager.operationQueue"))
    }
    
    public func invalidate() {
        sessionManager.invalidate()
    }

    @discardableResult
    public func download(url: ZYGDLBGURLConvertible,
                         headers: [String: String]?,
                         fileName: String?) -> ZYGDLBGDownloadTask? {
        if let downloadTask = sessionManager.download(asURLConvertible(url), headers: headers, fileName: fileName) {
            let convertDownloadTask = bridgeTask(downloadTask)
            return convertDownloadTask
        } else {
            return nil
        }
    }
    
    @discardableResult
    public func download(url: ZYGDLBGURLConvertible) -> ZYGDLBGDownloadTask? {
        return download(url: url, headers: nil, fileName: nil)
    }

    
    
    /// 非阻塞下载入口；prepared 在主线程异步回调一次，随后接收完成代理事件。
    /// 无效 URL 返回 nil 和错误。相同底层任务复用同一个桥接对象。
    public func downloadAsync(url: ZYGDLBGURLConvertible,
                              headers: [String: String]?,
                              fileName: String?,
                              prepared: @escaping (ZYGDLBGDownloadTask?, NSError?) -> Void) {
        sessionManager.downloadAsync(ZYGDLBGAsyncURLConvertible(value: url), headers: headers, fileName: fileName) { task, error in
            guard let task = task else {
                prepared(nil, error.map { $0 as NSError })
                return
            }
            prepared(self.bridgeTask(task), nil)
        }
    }

    public func downloadAsync(url: ZYGDLBGURLConvertible,
                              prepared: @escaping (ZYGDLBGDownloadTask?, NSError?) -> Void) {
        downloadAsync(url: url, headers: nil, fileName: nil, prepared: prepared)
    }

    @nonobjc public func downloadManager(_ manager: ZYGDLSessionManager, didComplete task: ZYGDLDownloadTask) {
        guard let delegate = downloadDelegate else { return }
        // 终态移除后不重新插入桥接任务集合。
        let wrapped = tasks.first { $0.downloadTask === task } ?? ZYGDLBGDownloadTask(task)
        delegate.downloadManager(self, didComplete: wrapped)
    }

    @discardableResult
    public func multiDownload(urls: [ZYGDLBGURLConvertible],
                              headers: [[String: String]]?,
                              fileNames: [String]?) -> [ZYGDLBGDownloadTask] {
        let convertURLs = urls.map { asURLConvertible($0) }
        let downloadTasks = sessionManager.multiDownload(convertURLs, headersArray: headers, fileNames: fileNames)
        let convertDownloadTasks = downloadTasks.map { bridgeTask($0) }
        return convertDownloadTasks
    }
    
    
    @discardableResult
    public func multiDownload(urls: [ZYGDLBGURLConvertible]) -> [ZYGDLBGDownloadTask] {
        return multiDownload(urls: urls, headers: nil, fileNames: nil)
    }
    

    
    
    public func fetchTask(url: ZYGDLBGURLConvertible) -> ZYGDLBGDownloadTask? {
        do {
            let validURL = try url.bg_asURL()
            return tasks.first { $0.url == validURL }
        } catch {
            return nil
        }
    }
    
    public func start(url: ZYGDLBGURLConvertible) {
        sessionManager.start(asURLConvertible(url))
    }
    
    public func start(task: ZYGDLBGDownloadTask) {
        sessionManager.start(task.downloadTask)
    }
    
    public func suspend(url: ZYGDLBGURLConvertible, onMainQueue: Bool, handler: Handler<ZYGDLBGDownloadTask>?) {
        sessionManager.suspend(asURLConvertible(url), onMainQueue: onMainQueue) { [weak self] _ in
            if let task = self?.fetchTask(url: url) {
                handler?(task)
            }
        }
    }
    
    public func suspend(url: ZYGDLBGURLConvertible) {
        suspend(url: url, onMainQueue: true, handler: nil)
    }


    public func cancel(url: ZYGDLBGURLConvertible, onMainQueue: Bool, handler: Handler<ZYGDLBGDownloadTask>?) {
        guard let task = fetchTask(url: url) else { return }
        removeBridgeTasks(url: task.url)
        sessionManager.cancel(asURLConvertible(url), onMainQueue: onMainQueue) { [weak self] _ in
            if let task = self?.fetchTask(url: url) {
                handler?(task)
            }
        }
    }
    
    public func cancel(url: ZYGDLBGURLConvertible) {
        cancel(url: url, onMainQueue: true, handler: nil)
    }
    
    public func remove(url: ZYGDLBGURLConvertible, completely: Bool, onMainQueue: Bool, handler: Handler<ZYGDLBGDownloadTask>?) {
        guard let task = fetchTask(url: url) else { return }
        removeBridgeTasks(url: task.url)
        sessionManager.remove(asURLConvertible(url), completely: completely, onMainQueue: onMainQueue) { [weak self] _ in
            if let task = self?.fetchTask(url: url) {
                 handler?(task)
             }
        }
    }
    
    public func remove(url: ZYGDLBGURLConvertible) {
        remove(url: url, completely: false, onMainQueue: true, handler: nil)
    }
    
    public func totalStart() {
        self.tasks.forEach { task in
            start(task: task)
        }
    }
    
    public func totalSuspend(onMainQueue: Bool, handler: Handler<ZYGDLBGSessionManager>?) {
        sessionManager.totalSuspend(onMainQueue: onMainQueue) { [weak self] _ in
            guard let self = self else { return }
            handler?(self)
        }
    }
    
    public func totalSuspend() {
        totalSuspend(onMainQueue: true, handler: nil)
    }
    
    public func totalCancel(onMainQueue: Bool, handler: Handler<ZYGDLBGSessionManager>?) {
        removeBridgeTasks()
        sessionManager.totalCancel(onMainQueue: onMainQueue) { [weak self] _ in
            guard let self = self else { return }
            handler?(self)
        }
    }
    
    public func totalCancel() {
        totalCancel(onMainQueue: true, handler: nil)
    }
    
    public func totalRemove(completely: Bool, onMainQueue: Bool, handler: Handler<ZYGDLBGSessionManager>?) {
        removeBridgeTasks()
        sessionManager.totalRemove(completely: completely, onMainQueue: onMainQueue) { [weak self] _ in
            guard let self = self else { return }
            handler?(self)
        }
    }
    
    public func totalRemove() {
        totalRemove(completely: false, onMainQueue: true, handler: nil)
    }
    
    @discardableResult
    public func progress(onMainQueue: Bool = true, handler: @escaping Handler<ZYGDLBGSessionManager>) -> Self {
        sessionManager.progress(onMainQueue: onMainQueue) { [weak self] _ in
            guard let self = self else { return }
            handler(self)
        }
        return self
    }
    
    @discardableResult
    public func success(onMainQueue: Bool = true, handler: @escaping Handler<ZYGDLBGSessionManager>) -> Self {
        sessionManager.success(onMainQueue: onMainQueue) { [weak self] _ in
            guard let self = self else { return }
            handler(self)
        }
        return self
    }
    
    @discardableResult
    public func failure(onMainQueue: Bool = true, handler: @escaping Handler<ZYGDLBGSessionManager>) -> Self {
        sessionManager.failure(onMainQueue: onMainQueue) { [weak self] _ in
            guard let self = self else { return }
            handler(self)
        }
        return self
    }
    
}
