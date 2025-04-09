//
//  ZYGDLBGCache.swift
//  ZygoteNetwork
//
//  Created by zhanlong on 2025/3/4.
//

import UIKit
import ZLDownloaded

@objcMembers public class ZYGDLBGCache: NSObject {
    
    public let cache: ZYGDLCache
    
    public var downloadPath: String {
        return cache.downloadPath
    }

    public var downloadTmpPath: String {
        return cache.downloadTmpPath
    }
    
    public var downloadFilePath: String {
        return cache.downloadFilePath
    }
    
    public var identifier: String {
        return cache.identifier
    }
    
    public static func defaultDiskCachePathClosure(_ cacheName: String) -> String {
        let dstPath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
        return (dstPath as NSString).appendingPathComponent(cacheName)
    }
    
    public init(_ name: String) {
        self.cache = ZYGDLCache(name)
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
        self.cache = ZYGDLCache(identifier, downloadPath: downloadPath, downloadTmpPath: downloadTmpPath, downloadFilePath: downloadFilePath)
    }
    
    internal init(cache: ZYGDLCache) {
        self.cache = cache
    }
    
    public func filePath(fileName: String) -> String? {
        return cache.filePath(fileName: fileName)
    }
    
    public func fileURL(fileName: String) -> URL? {
        return cache.fileURL(fileName: fileName)
    }
    
    public func fileExists(fileName: String) -> Bool {
        return cache.fileExists(fileName: fileName)

    }
    
    public func fileType(fileName: String) -> ZYGDLBGFileType {
       
        let ext = (fileName as NSString).pathExtension.lowercased()
        var type:ZYGDLBGFileType = .other
        switch ext {
        case "zip": type = .zip
        case "mp4": type = .mp4
        case "txt": type = .text
        case "json": type = .json
        case "svga": type = .svga
        case "vap": type = .vap
        default: type = .other
        }
        return type
    }
    
    public func filePath(url: ZYGDLBGURLConvertible) -> String? {
        return cache.filePath(url: asURLConvertible(url))
    }
    
    public func fileURL(url: ZYGDLBGURLConvertible) -> URL? {
        return cache.fileURL(url: asURLConvertible(url))

    }
    
    public func fileExists(url: ZYGDLBGURLConvertible) -> Bool {
        return cache.fileExists(url: asURLConvertible(url))

    }
    
    public func filePathExists(url: ZYGDLBGURLConvertible) -> Bool {
        return cache.filePathExists(url: asURLConvertible(url))
    }
    
    public func clearDiskCache(onMainQueue: Bool, handler: Handler<ZYGDLBGCache>?) {
        cache.clearDiskCache(onMainQueue: onMainQueue) { [weak self] _ in
            guard let self = self else { return }
            handler?(self)
        }
    }
    
    public func clearDiskCache() {
        clearDiskCache(onMainQueue: true, handler: nil)
    }
    
}
