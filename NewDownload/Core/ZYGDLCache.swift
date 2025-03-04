//
//  ZYGDLCache.swift
//  ZygoteNetwork
//
//  Created by zhanlong on 2025/2/19.
//

import UIKit

public class ZYGDLCache {
    
    // 用于处理文件操作，确保线程安全。
    private let ioQueue: DispatchQueue
    
    // debouncer 是一个防抖动器，用于延迟执行某些操作，避免频繁调用。
    private var debouncer: ZYGDLDebouncer
    
    // downloadPath 是下载文件的存储路径。
    public let downloadPath: String
    
    // downloadTmpPath 是下载临时文件的存储路径。
    public let downloadTmpPath: String
    
    // downloadFilePath 是下载完成后的文件存储路径。
    public let downloadFilePath: String
    
    // identifier 是缓存的标识符，用于区分不同的下载模块。
    public let identifier: String
    
    // fileManager 是文件管理器，用于执行文件操作。
    private let fileManager = FileManager.default
    
    // encoder 是属性列表编码器，用于将下载任务编码为 plist 文件。
    private let encoder = PropertyListEncoder()
    
    // manager 是会话管理器的弱引用，用于下载等操作。
    internal weak var manager: ZYGDLSessionManager?
    
    // decoder 是属性列表解码器，用于从 plist 文件解码下载任务。
    private let decoder = PropertyListDecoder()
    
    // 生成默认的磁盘缓存路径。
    public static func defaultDiskCachePathClosure(_ cacheName: String) -> String {
        let dstPath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
        return (dstPath as NSString).appendingPathComponent(cacheName)
    }
    
    /// 初始化方法
    /// - Parameters:
    ///   - identifier: 不同的identifier代表不同的下载模块。如果没有自定义下载目录，Cache会提供默认的目录，这些目录跟identifier相关
    ///   - downloadPath: 存放用于DownloadTask持久化的数据，默认提供的downloadTmpPath、downloadFilePath也是在里面
    ///   - downloadTmpPath: 存放下载中的临时文件
    ///   - downloadFilePath: 存放下载完成后的文件
    public init(_ identifier: String,
                downloadPath: String? = nil,
                downloadTmpPath: String? = nil,
                downloadFilePath: String? = nil) {
        self.identifier = identifier
        
        // 初始化 ioQueue，使用 identifier 生成唯一的队列名称。
        let ioQueueName = "com.ZYG.Downloaded.Cache.ioQueue.\(identifier)"
        ioQueue = DispatchQueue(label: ioQueueName, autoreleaseFrequency: .workItem)
        
        // 初始化 debouncer，使用 ioQueue 作为队列。
        debouncer = ZYGDLDebouncer(queue: ioQueue)
        
        let cacheName = "com.ZYG.Downloaded.Cache.\(identifier)"
        
        // 生成磁盘缓存路径。
        let diskCachePath = ZYGDLCache.defaultDiskCachePathClosure(cacheName)
        
        // 如果没有提供 downloadPath，则使用默认路径。
        let path = downloadPath ?? (diskCachePath as NSString).appendingPathComponent("ZYGDLDownloads")
        
        self.downloadPath = path
        
        // 如果没有提供 downloadTmpPath，则使用默认路径。
        self.downloadTmpPath = downloadTmpPath ?? (path as NSString).appendingPathComponent("ZYGDLTmp")
        
        // 如果没有提供 downloadFilePath，则使用默认路径。
        self.downloadFilePath = downloadFilePath ?? (path as NSString).appendingPathComponent("ZYGDLFile")
        
        // 创建缓存目录。
        createDirectory()
        
        // 将当前缓存实例添加到解码器的 userInfo 中。
        decoder.userInfo[.cache] = self
    }
    
    public func invalidata() {
        // 使缓存失效，将缓存实例从解码器的 userInfo 中移除。
        decoder.userInfo[.cache] = nil
    }
    
}

// MARK: - file
extension ZYGDLCache {
    
    // 创建缓存目录的方法。
    internal func createDirectory() {
        // 如果 downloadPath 不存在，则创建该目录。
        if !fileManager.fileExists(atPath: downloadPath) {
            do {
                try fileManager.createDirectory(atPath: downloadPath, withIntermediateDirectories: true, attributes: nil)
            } catch {
                manager?.log(.error("create directory failed",
                                    error: ZYGDLError.cacheError(reason: .cannotCreateDirectory(path: downloadPath, error: error))))
            }
        }
        
        // 如果 downloadTmpPath 不存在，则创建该目录。
        if !fileManager.fileExists(atPath: downloadTmpPath) {
            do {
                try fileManager.createDirectory(atPath: downloadTmpPath, withIntermediateDirectories: true, attributes: nil)
            } catch {
                manager?.log(.error("create directory failed",
                                    error: ZYGDLError.cacheError(reason: .cannotCreateDirectory(path: downloadTmpPath, error: error))))
            }
        }
        
        // 如果 downloadFilePath 不存在，则创建该目录。
        if !fileManager.fileExists(atPath: downloadFilePath) {
            do {
                try fileManager.createDirectory(atPath: downloadFilePath, withIntermediateDirectories: true, attributes: nil)
            } catch {
                manager?.log(.error("create directory failed",
                                    error: ZYGDLError.cacheError(reason: .cannotCreateDirectory(path: downloadFilePath, error: error))))
            }
        }
    }
    
    // 根据文件名生成文件路径。
    public func filePath(fileName: String) -> String? {
        if fileName.isEmpty {
            return nil
        }
        let path = (downloadFilePath as NSString).appendingPathComponent(fileName)
        return path
    }
    
    // 根据文件名生成文件 URL。
    public func fileURL(fileName: String) -> URL? {
        guard let path = filePath(fileName: fileName) else { return nil }
        return URL(fileURLWithPath: path)
    }
    
    // 检查文件是否存在。
    public func fileExists(fileName: String) -> Bool {
        guard let path = filePath(fileName: fileName) else { return false }
        return fileManager.fileExists(atPath: path)
    }
    
    // 根据 URL 生成文件路径。
    public func filePath(url: ZYGDLURLConvertible) -> String? {
        do {
            let validURL = try url.asURL()
            let fileName = validURL.tr.fileName
            return filePath(fileName: fileName)
        } catch {
            return nil
        }
    }
    
    // 根据 URL 生成文件 URL。
    public func fileURL(url: ZYGDLURLConvertible) -> URL? {
        guard let path = filePath(url: url) else { return nil }
        return URL(fileURLWithPath: path)
    }
    
    // 检查 URL 对应的文件是否存在。
    public func fileExists(url: ZYGDLURLConvertible) -> Bool {
        guard let path = filePath(url: url) else { return false }
        return fileManager.fileExists(atPath: path)
    }
    
    // 清除磁盘缓存的方法。
    public func clearDiskCache(onMainQueue: Bool = true, handle: Handler<ZYGDLCache>? = nil) {
        ioQueue.async {
            guard self.fileManager.fileExists(atPath: self.downloadPath) else { return }
            do {
                try self.fileManager.removeItem(atPath: self.downloadPath)
            } catch {
                self.manager?.log(.error("clear disk cache failed",
                                         error: ZYGDLError.cacheError(reason: .cannotRemoveItem(path: self.downloadPath, error: error))))
            }
            self.createDirectory()
            if let handle = handle {
                ZYGDLExecuter(onMainQueue: onMainQueue, handle: handle).execute(self)
            }
        }
    }
}

// MARK: - retrieve
extension ZYGDLCache {
    
    // 检索所有下载任务的方法。
    internal func retrieveAllTask() -> [ZYGDLDownloadTask] {
        return ioQueue.sync {
            let path = (downloadPath as NSString).appendingPathComponent("\(identifier)_Tasks.plist")
            if fileManager.fileExists(atPath: path) {
                do {
                    let url = URL(fileURLWithPath: path)
                    let data = try Data(contentsOf: url)
                    let tasks = try decoder.decode([ZYGDLDownloadTask].self, from: data)
                    tasks.forEach { task in
                        task.cache = self
                        if task.status == .waiting {
                            task.protectedState.write {
                                $0.status = .suspended
                            }
                        }
                    }
                    return tasks
                } catch {
                    manager?.log(.error("retrieve all tasks failed", error: ZYGDLError.cacheError(reason: .cannotRetrieveAllTasks(path: path, error: error))))
                    return [ZYGDLDownloadTask]()
                }
            } else {
                return [ZYGDLDownloadTask]()
            }
        }
    }
    
    // 检索临时文件的方法。
    internal func retrieveTmpFile(_ tmpFileName: String?) -> Bool {
        return ioQueue.sync {
            guard let tmpFileName = tmpFileName, !tmpFileName.isEmpty else { return false }
            
            let backupFilePath = (downloadTmpPath as NSString).appendingPathComponent(tmpFileName)
            let originFilePath = (NSTemporaryDirectory() as NSString).appendingPathComponent(tmpFileName)
            let backupFileExists = fileManager.fileExists(atPath: backupFilePath)
            let originFileExists = fileManager.fileExists(atPath: originFilePath)
            guard backupFileExists || originFileExists else { return false }
            
            if originFileExists {
                do {
                    try fileManager.removeItem(atPath: backupFilePath)
                } catch {
                    self.manager?.log(.error("retrieve tmpFile failed",
                                             error: ZYGDLError.cacheError(reason: .cannotRemoveItem(path: backupFilePath, error: error))))
                }
            } else {
                do {
                    try fileManager.moveItem(atPath: backupFilePath, toPath: originFilePath)
                } catch {
                    self.manager?.log(.error("retrieve tmpFile failed",
                                             error: ZYGDLError.cacheError(reason: .cannotMoveItem(atPath: backupFilePath, toPath: originFilePath, error: error))))
                }
            }
            return true
        }
    }
}

// MARK: - store
extension ZYGDLCache {
    
    // 存储下载任务的方法。
    internal func storeTasks(_ tasks: [ZYGDLDownloadTask]) {
        debouncer.execute(label: "storeTasks", wallDeadline: .now() + 0.2) {
            var path = (self.downloadPath as NSString).appendingPathComponent("\(self.identifier)_Tasks.plist")
            do {
                let data = try self.encoder.encode(tasks)
                let url = URL(fileURLWithPath: path)
                try data.write(to: url)
            } catch {
                self.manager?.log(.error("store tasks failed",
                                         error: ZYGDLError.cacheError(reason: .cannotEncodeTasks(path: path, error: error))))
            }
            path = (self.downloadPath as NSString).appendingPathComponent("\(self.identifier)Tasks.plist")
            try? self.fileManager.removeItem(atPath: path)
        }
    }
    
    // 存储文件的方法。
    internal func storeFile(at srcURL: URL, to dstURL: URL) {
        ioQueue.sync {
            do {
                try fileManager.moveItem(at: srcURL, to: dstURL)
            } catch {
                self.manager?.log(.error("store file failed",
                                         error: ZYGDLError.cacheError(reason: .cannotMoveItem(atPath: srcURL.absoluteString, toPath: dstURL.absoluteString, error: error))))
            }
        }
    }
    
    // 存储临时文件的方法。
    internal func storeTmpFile(_ tmpFileName: String?) {
        ioQueue.sync {
            guard let tmpFileName = tmpFileName, !tmpFileName.isEmpty else { return }
            let tmpPath = (NSTemporaryDirectory() as NSString).appendingPathComponent(tmpFileName)
            let destination = (downloadTmpPath as NSString).appendingPathComponent(tmpFileName)
            if fileManager.fileExists(atPath: destination) {
                do {
                    try fileManager.removeItem(atPath: destination)
                } catch {
                    self.manager?.log(.error("store tmpFile failed",
                                             error: ZYGDLError.cacheError(reason: .cannotRemoveItem(path: destination, error: error))))
                }
            }
            if fileManager.fileExists(atPath: tmpPath) {
                do {
                    try fileManager.copyItem(atPath: tmpPath, toPath: destination)
                } catch {
                    self.manager?.log(.error("store tmpFile failed",
                                             error: ZYGDLError.cacheError(reason: .cannotCopyItem(atPath: tmpPath, toPath: destination, error: error))))
                }
            }
        }
    }
    
    // 更新文件名的方法。
    internal func updateFileName(_ filePath: String, _ newFileName: String) {
        ioQueue.sync {
            if fileManager.fileExists(atPath: filePath) {
                let newFilePath = self.filePath(fileName: newFileName)!
                do {
                    try fileManager.moveItem(atPath: filePath, toPath: newFilePath)
                } catch {
                    self.manager?.log(.error("update fileName failed",
                                             error: ZYGDLError.cacheError(reason: .cannotMoveItem(atPath: filePath, toPath: newFilePath, error: error))))
                }
            }
        }
    }
    
}

// MARK: - remove
extension ZYGDLCache {
    
    // 删除下载任务的方法。
    internal func remove(_ task: ZYGDLDownloadTask, completely: Bool) {
        removeTmpFile(task.tmpFileName)
        
        if completely {
            removeFile(task.filePath)
        }
    }
    
    // 删除文件的方法。
    internal func removeFile(_ filePath: String) {
        ioQueue.async {
            if self.fileManager.fileExists(atPath: filePath) {
                do {
                    try self.fileManager.removeItem(atPath: filePath)
                } catch {
                    self.manager?.log(.error("remove file failed",
                                             error: ZYGDLError.cacheError(reason: .cannotRemoveItem(path: filePath, error: error))))
                }
            }
        }
    }
    
    /// 删除保留在本地的临时缓存文件
    internal func removeTmpFile(_ tmpFileName: String?) {
        ioQueue.async {
            guard let tmpFileName = tmpFileName, !tmpFileName.isEmpty else { return }
            let path1 = (self.downloadTmpPath as NSString).appendingPathComponent(tmpFileName)
            let path2 = (NSTemporaryDirectory() as NSString).appendingPathComponent(tmpFileName)
            let paths: [String] = [path1, path2]
            paths.forEach { path in
                if self.fileManager.fileExists(atPath: path) {
                    do {
                        try self.fileManager.removeItem(atPath: path)
                    } catch {
                        self.manager?.log(.error("remove tmpFile failed",
                                                 error: ZYGDLError.cacheError(reason: .cannotRemoveItem(path: path, error: error))))
                    }
                }
            }

        }
    }
}

extension URL: ZYGDLCompatible {
    
}

extension ZYGDLWrapper where Base == URL {
    public var fileName: String {
        var fileName = base.absoluteString.tr.md5
        if !base.pathExtension.isEmpty {
            fileName += ".\(base.pathExtension)"
        }
        return fileName
    }
}
