//
//  ZYGDLNotifications.swift
//  ZygoteNetwork
//
//  Created by zhanlong on 2025/2/27.
//

import Foundation

public extension ZYGDLDownloadTask {
    
    static let runningNotification = Notification.Name(rawValue: "com.ZYG.Downloaded.notification.name.downloadTask.running")
    static let didCompleteNotification = Notification.Name(rawValue: "com.ZYG.Downloaded.notification.name.downloadTask.didComplete")
    
}

public extension ZYGDLSessionManager {
    
    static let runningNotification = Notification.Name(rawValue: "com.ZYG.Downloaded.notification.name.sessionManager.running")
    static let didCompleteNotification = Notification.Name(rawValue: "com.ZYG.Downloaded.notification.name.sessionManager.didComplete")
    
}

extension Notification {
    
    public var downloadTask: ZYGDLDownloadTask? {
        return userInfo?[String.downloadTaskKey] as? ZYGDLDownloadTask
    }
    
    public var sessionManager: ZYGDLSessionManager? {
        return userInfo?[String.sessionManagerKey] as? ZYGDLSessionManager
    }
    
    init(name: Notification.Name, downloadTask: ZYGDLDownloadTask) {
        self.init(name: name, object: nil, userInfo: [String.downloadTaskKey: downloadTask])
    }
    
    init(name: Notification.Name, sessionManager: ZYGDLSessionManager) {
        self.init(name: name, object: nil, userInfo: [String.sessionManagerKey: sessionManager])
    }
    
}

extension NotificationCenter {
    
    func postNotification(name: Notification.Name, downloadTask: ZYGDLDownloadTask) {
        let notification = Notification(name: name, downloadTask: downloadTask)
        post(notification)
    }
    
    func postNotification(name: Notification.Name, sessionManager: ZYGDLSessionManager) {
        let notification = Notification(name: name, sessionManager: sessionManager)
        post(notification)
    }
    
}


extension String {
    
    fileprivate static let downloadTaskKey = "com.ZYG.Downloaded.notification.key.downloadTask"
    fileprivate static let sessionManagerKey = "com.ZYG.Downloaded.notification.key.sessionManagerKey"
    
}
