//
//  ZYGDLSessionConfiguration.swift
//  ZygoteNetwork
//
//  Created by zhanlong on 2025/2/20.
//

import Foundation

// 用于配置下载会话。
public struct ZYGDLSessionConfiguration {
    
    // 请求超时时间，默认值为 60 秒。
    public var timeoutIntervalForRequest: TimeInterval = 60.0
    
    // 表示最大并发任务数
    private var _maxConcurrentTasksLimit: Int = MaxConcurrentTasksLimit
    
    // 用于获取和设置最大并发任务数。
    public var maxConcurrentTasksLimit: Int {
        get {
            // 返回 _maxConcurrentTasksLimit 的值。
            return _maxConcurrentTasksLimit
        }
        set {
            // 根据 newValue 的值设置 _maxConcurrentTasksLimit，确保其在 1 到 MaxConcurrentTasksLimit 之间。
            if newValue > MaxConcurrentTasksLimit {
                _maxConcurrentTasksLimit = MaxConcurrentTasksLimit
            } else if newValue < 1 {
                _maxConcurrentTasksLimit = 1
            } else {
                _maxConcurrentTasksLimit = newValue
            }
        }
    }
    
    // 表示是否允许昂贵的网络访问，默认值为 true。
    public var allowsExpensiveNetworkAccess: Bool = true
    
    // 表示是否允许受限的网络访问，默认值为 true。
    public var allowsConstrainedNetworkAccess: Bool = true
    
    // 表示是否允许蜂窝网络下载，默认值为 false。
    public var allowsCellularAccess: Bool = false
    
    public init() {
        
    }
}

// 用于获取最大并发任务数的限制。
var MaxConcurrentTasksLimit: Int {
    return 6
}
