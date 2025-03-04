//
//  ZYGDLError.swift
//  ZygoteNetwork
//
//  Created by zhanlong on 2025/2/19.
//

import Foundation

// 定义一个公开的枚举 ZYGDLError，遵循 Error 协议。
public enum ZYGDLError: Error {
    
    // 定义一个嵌套的枚举 CacheErrorReason，用于表示缓存相关的错误原因。
    public enum CacheErrorReason {
        // 表示无法创建目录的错误，包含路径和错误信息。
        case cannotCreateDirectory(path: String, error: Error)
        // 表示无法移除项目的错误，包含路径和错误信息。
        case cannotRemoveItem(path: String, error: Error)
        // 表示无法复制项目的错误，包含源路径、目标路径和错误信息。
        case cannotCopyItem(atPath: String, toPath: String, error: Error)
        // 表示无法移动项目的错误，包含源路径、目标路径和错误信息。
        case cannotMoveItem(atPath: String, toPath: String, error: Error)
        // 表示无法检索所有任务的错误，包含路径和错误信息。
        case cannotRetrieveAllTasks(path: String, error: Error)
        // 表示无法编码任务的错误，包含路径和错误信息。
        case cannotEncodeTasks(path: String, error: Error)
        // 表示文件不存在的错误，包含路径信息。
        case fileDoesnotExist(path: String)
        // 表示读取数据失败的错误，包含路径信息。
        case readDataFailed(path: String)
    }
    
    // 表示未知错误。
    case unknown
    // 表示无效的 URL 错误，包含 URL 信息。
    case invalidURL(url: ZYGDLURLConvertible)
    // 表示重复的 URL 错误，包含 URL 信息。
    case duplicateURL(url: ZYGDLURLConvertible)
    // 表示索引超出范围的错误。
    case indexOutOfRange
    // 表示获取下载任务失败的错误，包含 URL 信息。
    case fetchDownloadTaskFailed(url: ZYGDLURLConvertible)
    // 表示头部数组与 URL 数量不匹配的错误。
    case headersMatchFailed
    // 表示文件名数组与 URL 数量不匹配的错误。
    case fileNamesMatchFailed
    // 表示不可接受的状态码错误，包含状态码信息。
    case unacceptableStatusCode(code: Int)
    // 表示缓存相关的错误，包含具体的错误原因。
    case cacheError(reason: CacheErrorReason)
}

// 扩展 ZYGDLError 以实现 LocalizedError 协议。
extension ZYGDLError: LocalizedError {
    
    // 提供本地化的错误描述。
    public var errorDescription: String? {
        
        switch self {
        case .unknown:
            // 返回未知错误的描述。
            return "unkown error"
        case let .invalidURL(url):
            // 返回无效 URL 错误的描述。
            return "URL is not valid: \(url)"
        case let .duplicateURL(url):
            // 返回重复 URL 错误的描述。
            return "URL is duplicate: \(url)"
        case .indexOutOfRange:
            // 返回索引超出范围错误的描述。
            return "index out of range"
        case let .fetchDownloadTaskFailed(url):
            // 返回获取下载任务失败错误的描述。
            return "did not find downloadTask in sessionManager: \(url)"
        case .headersMatchFailed:
            // 返回头部数组与 URL 数量不匹配错误的描述。
            return "HeaderArray.count != urls.count"
        case .fileNamesMatchFailed:
            // 返回文件名数组与 URL 数量不匹配错误的描述。
            return "FileNames.count != urls.count"
        case let .unacceptableStatusCode(code):
            // 返回不可接受状态码错误的描述。
            return "Response status code was unacceptable: \(code)"
        case let .cacheError(reason):
            // 返回缓存相关错误的描述。
            return reason.errorDescription
        }
    }
    
}

/// 扩展 CacheErrorReason 以提供本地化的错误描述。
extension ZYGDLError.CacheErrorReason {
    
    // 提供本地化的错误描述。
    public var errorDescription: String? {
        switch self {
        case let .cannotCreateDirectory(path, error):
            // 返回无法创建目录错误的描述。
            return "can not create directory, path: \(path), underlying: \(error)"
        case let .cannotRemoveItem(path, error):
            // 返回无法移除项目错误的描述。
            return "can not remove item, path: \(path), underlying: \(error)"
        case let .cannotCopyItem(atPath, toPath, error):
            // 返回无法复制项目错误的描述。
            return "can not copy item, atPath: \(atPath), toPath: \(toPath), underlying: \(error)"
        case let .cannotMoveItem(atPath, toPath, error):
            // 返回无法移动项目错误的描述。
            return "can not move item atPath: \(atPath), toPath: \(toPath), underlying: \(error)"
        case let .cannotRetrieveAllTasks(path, error):
            // 返回无法检索所有任务错误的描述。
            return "can not retrieve all tasks, path: \(path), underlying: \(error)"
        case let .cannotEncodeTasks(path, error):
            // 返回无法编码任务错误的描述。
            return "can not encode tasks, path: \(path), underlying: \(error)"
        case let .fileDoesnotExist(path):
            // 返回文件不存在错误的描述。
            return "file does not exist, path: \(path)"
        case let .readDataFailed(path):
            // 返回读取数据失败错误的描述。
            return "read data failed, path: \(path)"
        }
    }
    
}

// 扩展 ZYGDLError 以实现 CustomNSError 协议。
extension ZYGDLError: CustomNSError {
    
    // 定义错误域。
    public static let errorDomain: String =  "com.ZYG.Downloaded.Error"
    
    // 提供错误代码。
    public var errorCode: Int {
        if case .unacceptableStatusCode = self {
            // 返回不可接受状态码错误的代码。
            return 1001
        } else {
            // 返回默认错误代码。
            return -1
        }
        
    }
    
    // 提供错误的用户信息。
    public var errorUserInfo: [String : Any] {
        if let errorDescription = errorDescription {
            // 返回包含错误描述的用户信息。
            return [NSLocalizedDescriptionKey: errorDescription]
        } else {
            // 返回空的用户信息。
            return [String : Any]()
        }
        
    }
    
}
