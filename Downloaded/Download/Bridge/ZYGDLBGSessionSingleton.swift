//
//  ZYGDLBGSessionSingleton.swift
//  yuanqi
//
//  Created by zhanlong on 2025/3/7.
//  Copyright © 2025 XYWL. All rights reserved.
//

import UIKit

@objcMembers public class ZYGDLBGSessionSingleton: NSObject {
    // 静态常量，持有单例实例
    public static let shared = ZYGDLBGSessionSingleton()
    
    public var sessionManager: ZYGDLBGSessionManager
    
    // 私有化初始化方法，防止外部实例化
    private override init() {
        // 初始化代码
        let configuration = ZYGDLBGSessionConfiguration()
        configuration.allowsCellularAccess = true;
        sessionManager = ZYGDLBGSessionManager(identifier: Bundle.main.bundleIdentifier ?? "com.zyg.download", configuration: configuration)
    }
    
    
}
