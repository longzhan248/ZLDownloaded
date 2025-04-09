//
//  ZYGDLBGSessionConfiguration.swift
//  ZygoteNetwork
//
//  Created by zhanlong on 2025/3/4.
//

import Foundation
import ZLDownloaded

@objcMembers public class ZYGDLBGSessionConfiguration: NSObject {
    
    internal weak var sessionManager: ZYGDLSessionManager?
    
    // 请求超时时间
    public var timeoutIntervalForRequest: TimeInterval = 60.0 {
        didSet {
            sessionManager?.configuration.timeoutIntervalForRequest = timeoutIntervalForRequest
        }
    }
    
    // 最大并发数
    private var _maxConcurrentTasksLimit: Int = MaxConcurrentTasksLimitBG {
        didSet {
            sessionManager?.configuration.maxConcurrentTasksLimit = _maxConcurrentTasksLimit
        }
    }
    
    public var maxConcurrentTasksLimit: Int {
        get {
            return _maxConcurrentTasksLimit
        }
        set {
            if newValue > MaxConcurrentTasksLimit {
                _maxConcurrentTasksLimit = MaxConcurrentTasksLimitBG
            } else if newValue < 1 {
                _maxConcurrentTasksLimit = 1
            } else {
                _maxConcurrentTasksLimit = newValue
            }
        }
    }
    
    // 是否允许蜂窝网络下载
    public var allowsCellularAccess: Bool = false {
        didSet {
            sessionManager?.configuration.allowsCellularAccess = allowsCellularAccess
        }
    }
    
}

var MaxConcurrentTasksLimitBG: Int {
    if #available(iOS 11.0, *) {
        return 6
    } else {
        return 3
    }
}
