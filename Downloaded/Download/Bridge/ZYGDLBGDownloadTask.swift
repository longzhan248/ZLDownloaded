//
//  ZYGDLBGDownloadTask.swift
//  ZygoteNetwork
//
//  Created by zhanlong on 2025/3/4.
//

import UIKit
import ZLDownloaded

@objcMembers public class ZYGDLBGDownloadTask: NSObject {
    
    @objc public enum ZYGDLBGValidation: Int {
        case unkown
        case correct
        case incorrect
    }
    
    internal let downloadTask: ZYGDLDownloadTask
    
    public var response: URLResponse? {
        downloadTask.response
    }
    
    public var statusCode: Int {
        downloadTask.statusCode ?? -1
    }

    public var filePath: String {
        return downloadTask.filePath
    }

    public var pathExtension: String? {
        return downloadTask.pathExtension
    }
    
    // 用户获取文件扩展枚举值
    public var fileType: ZYGDLBGFileType {
        return ZYGDLBGFileType(downloadTask.fileType)
    }
    
    public var status: ZYGDLBGStatus {
        return ZYGDLBGStatus(downloadTask.status)
    }
    
    public var validation: ZYGDLBGValidation {
        switch downloadTask.validation {
        case .unkown:
            return .unkown
        case .correct:
            return .correct
        case .incorrect:
            return .incorrect
        }
    }
    
    public var url: URL {
        return downloadTask.url
    }

    public var progress: Progress {
        return downloadTask.progress
    }

    public var startDate: Double {
        return downloadTask.startDate
    }

    public var endDate: Double {
        return downloadTask.endDate
    }

    public var speed: Int64 {
        return downloadTask.speed
    }

    public var fileName: String {
        return downloadTask.fileName
    }

    public var timeRemaining: Int64 {
        return downloadTask.timeRemaining
    }

    public var error: Error? {
        return downloadTask.error
    }

    internal init(_ downloadTask: ZYGDLDownloadTask) {
        self.downloadTask = downloadTask
    }
    
    @discardableResult
    public func validateFile(code: String,
                             type: ZYGDLBGFileVerificationType,
                             onMainQueue: Bool = true,
                             handler: @escaping Handler<ZYGDLBGDownloadTask>) -> Self {
        let convertType: ZYGDLFileChecksumHelper.VerificationType
        switch type {
        case .md5:
            convertType = .md5
        case .sha1:
            convertType = .sha1
        case .sha256:
            convertType = .sha256
        case .sha512:
            convertType = .sha512
        }
        downloadTask.validateFile(code: code, type: convertType, onMainQueue: onMainQueue) { [weak self] task in
            guard let self = self else {
                return
            }
            handler(self)
        }
        return self
    }
    
    @discardableResult
    public func progress(onMainQueue: Bool = true, handler: @escaping Handler<ZYGDLBGDownloadTask>) -> Self {
        downloadTask.progress(onMainQueue: onMainQueue) { [weak self] _ in
            guard let self = self else { return }
            handler(self)
        }
        return self
    }

    @discardableResult
    public func success(onMainQueue: Bool = true, handler: @escaping Handler<ZYGDLBGDownloadTask>) -> Self {
        downloadTask.success(onMainQueue: onMainQueue) { [weak self] _ in
            guard let self = self else { return }
            handler(self)
        }
        return self

    }

    @discardableResult
    public func failure(onMainQueue: Bool = true, handler: @escaping Handler<ZYGDLBGDownloadTask>) -> Self {
        downloadTask.failure(onMainQueue: onMainQueue) { [weak self] _ in
            guard let self = self else { return }
            handler(self)
        }
        return self
    }
    
    @discardableResult
    public func completion(onMainQueue: Bool = true, handler: @escaping Handler<ZYGDLBGDownloadTask>) -> Self {
        downloadTask.completion(onMainQueue: onMainQueue) { [weak self] _ in
            guard let self = self else { return }
            handler(self)
        }
        return self
    }
}
