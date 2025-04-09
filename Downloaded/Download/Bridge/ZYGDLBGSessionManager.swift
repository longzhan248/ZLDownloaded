//
//  ZYGDLBGSessionManager.swift
//  ZygoteNetwork
//
//  Created by zhanlong on 2025/3/4.
//

import UIKit
import ZLDownloaded

@objcMembers public class ZYGDLBGSessionManager: NSObject {
    
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
    
    public private(set) var tasks: [ZYGDLBGDownloadTask] = []
    
    
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
        tasks = sessionManager.tasks.map { ZYGDLBGDownloadTask($0) }
        
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
            let convertDownloadTask = ZYGDLBGDownloadTask(downloadTask)
            tasks.append(convertDownloadTask)
            return convertDownloadTask
        } else {
            return nil
        }
    }
    
    @discardableResult
    public func download(url: ZYGDLBGURLConvertible) -> ZYGDLBGDownloadTask? {
        return download(url: url, headers: nil, fileName: nil)
    }

    
    
    @discardableResult
    public func multiDownload(urls: [ZYGDLBGURLConvertible],
                              headers: [[String: String]]?,
                              fileNames: [String]?) -> [ZYGDLBGDownloadTask] {
        let convertURLs = urls.map { asURLConvertible($0) }
        let downloadTasks = sessionManager.multiDownload(convertURLs, headersArray: headers, fileNames: fileNames)
        let convertDownloadTasks = downloadTasks.map { ZYGDLBGDownloadTask($0) }
        tasks.append(contentsOf: convertDownloadTasks)
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
        tasks.removeAll { $0.url == task.url}
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
        tasks.removeAll { $0.url == task.url}
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
        tasks.removeAll()
        sessionManager.totalCancel(onMainQueue: onMainQueue) { [weak self] _ in
            guard let self = self else { return }
            handler?(self)
        }
    }
    
    public func totalCancel() {
        totalCancel(onMainQueue: true, handler: nil)
    }
    
    public func totalRemove(completely: Bool, onMainQueue: Bool, handler: Handler<ZYGDLBGSessionManager>?) {
        tasks.removeAll()
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
