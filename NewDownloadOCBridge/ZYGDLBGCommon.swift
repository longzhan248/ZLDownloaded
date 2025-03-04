//
//  ZYGDLBGCommon.swift
//  ZygoteNetwork
//
//  Created by zhanlong on 2025/3/4.
//

import Foundation

@objc public enum ZYGDLBGStatus: Int {
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
    
    internal init(_ status: ZYGDLStatus) {
        switch status {
        case .waiting:
            self = .waiting
        case .running:
            self = .running
        case .suspended:
            self = .suspended
        case .canceled:
            self = .canceled
        case .failed:
            self = .failed
        case .removed:
            self = .removed
        case .succeeded:
            self = .succeeded
        case .willSuspend:
            self = .willSuspend
        case .willCancel:
            self = .willCancel
        case .willRemove:
            self = .willRemove
        }
    }
    
}

@objc public enum ZYGDLBGFileVerificationType: Int {
    case md5
    case sha1
    case sha256
    case sha512
}
