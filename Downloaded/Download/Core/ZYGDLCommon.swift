//
//  ZYGDLCommon.swift
//  ZygoteNetwork
//
//  Created by zhanlong on 2025/2/19.
//

import Foundation

// 表示日志选项。
public enum ZYGDLLogOption {
    // 默认日志选项。
    case `default`
    // 不记录日志的选项。
    case none
}

// 表示日志类型。
public enum ZYGDLLogType {
    // 表示 SessionManager 的日志类型，包含消息和 SessionManager 实例。
    case sessionManager(_ message: String, manager: ZYGDLSessionManager)
    // 表示 DownloadTask 的日志类型，包含消息和 DownloadTask 实例。
    case downloadTask(_ message: String, task: ZYGDLDownloadTask)
    // 表示错误的日志类型，包含消息和错误信息。
    case error(_ message: String, error: Error)
}

// 表示可记录日志的对象。
public protocol ZYGDLLogable {
    // 定义一个只读属性 identifier，用于标识日志记录对象。
    var identifier: String { get }
    
    // 定义一个可读写属性 option，用于设置日志选项。
    var option: ZYGDLLogOption { get set }
    
    // 定义一个方法 log，用于记录日志。
    func log(_ type: ZYGDLLogType)
}

public struct ZYGDLLogger: ZYGDLLogable {
    
    // 用于标识日志记录对象。
    public var identifier: String
    
    // 用于设置日志选项。
    public var option: ZYGDLLogOption
    
    // 用于记录日志。
    public func log(_ type: ZYGDLLogType) {
        // 如果日志选项不是默认选项，则返回。
        guard option == .default else { return }
        
        // 初始化一个字符串数组，用于存储日志信息。
        var strings = ["************************ ZYGDownloadedLog ************************"]
        
        // 添加标识符信息到日志中。
        strings.append("identifier    :  \(identifier)")
        
        switch type {
        case let .sessionManager(message, manager):
            strings.append("Message       :  [SessionManager] \(message), tasks.count: \(manager.tasks.count)")
        case let .downloadTask(message, task):
            strings.append("Message       :  [DownloadTask] \(message)")
            strings.append("Task URL      :  \(task.url.absoluteString)")
            if let error = task.error, task.status == .failed {
                strings.append("Error         :  \(error)")
            }
        case let .error(message, error):
            strings.append("Message       :  [Error] \(message)")
            strings.append("Description   :  \(error)")
        }
        
        // 添加一个空行到日志中。
        strings.append("")
        
        // 打印日志信息。
        print(strings.joined(separator: "\n"))
                
    }
    
}

// 用于表示下载任务的状态。
public enum ZYGDLStatus: String {
    // 等待状态。
    case waiting
    // 运行状态。
    case running
    // 暂停状态。
    case suspended
    // 取消状态。
    case canceled
    // 失败状态。
    case failed
    // 移除状态。
    case removed
    // 成功状态。
    case succeeded
    // 即将暂停状态。
    case willSuspend
    // 即将取消状态。
    case willCancel
    // 即将移除状态。
    case willRemove
}

// 定义文件类型枚举
enum ZYGDLFileType {
    case zip
    case mp4
    case text
    case json
    case other(String)  // 其他未知类型保存原始扩展名
    
    // 根据文件扩展名初始化
    init(fileExtension: String) {
        let ext = fileExtension.lowercased()
        switch ext {
        case "zip": self = .zip
        case "mp4": self = .mp4
        case "txt": self = .text
        case "json": self = .json
        default: self = .other(fileExtension)
        }
    }
}

// 用于包装其他类型。
public struct ZYGDLWrapper<Base> {
    // 用于存储被包装的对象。
    internal let base: Base
    
    internal init(_ base: Base) {
        self.base = base
    }
}

// 用于表示可与 downloaded 兼容的对象。
public protocol ZYGDLCompatible {
    
}

extension ZYGDLCompatible {
    
    // 定义一个计算属性 tr，返回一个包装了自身的 ZYGDLWrapper 实例。
    public var tr: ZYGDLWrapper<Self> {
        get {
            ZYGDLWrapper(self)
        }
    }
    
    // 定义一个计算属性 tr，返回 ZYGDLWrapper 的类型。
    public static var tr: ZYGDLWrapper<Self>.Type {
        get {
            ZYGDLWrapper<Self>.self
        }
    }
    
}
