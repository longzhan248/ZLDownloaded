//
//  Double+TaskInfo.swift
//  ZygoteNetwork
//
//  Created by zhanlong on 2025/2/20.
//

import Foundation

extension Double: ZYGDLCompatible {
    
}

extension ZYGDLWrapper where Base == Double {
    
    // 返回 yyyy-MM-dd HH:mm:ss格式的字符串
    public func convertTimeToDateString() -> String {
        let date = Date(timeIntervalSince1970: base)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
    
}
