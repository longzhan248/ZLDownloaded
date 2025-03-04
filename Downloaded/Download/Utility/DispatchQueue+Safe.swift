//
//  DispatchQueue+Safe.swift
//  ZygoteNetwork
//
//  Created by zhanlong on 2025/2/19.
//

import Foundation

extension DispatchQueue: ZYGDLCompatible {
    
}

extension ZYGDLWrapper where Base: DispatchQueue {
    
    public static func executeOnMain(_ block: @escaping () -> ()) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async {
                block()
            }
        }
    }
    
}
