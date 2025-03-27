//
//  ZYGDLExecuter.swift
//  ZygoteNetwork
//
//  Created by zhanlong on 2025/2/19.
//

import Foundation

// 定义一个泛型类型别名 Handler，表示一个接受类型 T 参数并返回空的闭包。
public typealias Handler<T> = (T) -> ()

// 定义一个泛型结构体 ZYGDLExecuter。
public struct ZYGDLExecuter<T> {
    
    // 表示是否在主队列上执行。
    private let onMainQueue: Bool
    
    // 表示要执行的处理程序。
    private let handler: Handler<T>?
    
    public init(onMainQueue: Bool, handler: Handler<T>?) {
        // 初始化 onMainQueue。
        self.onMainQueue = onMainQueue
        // 初始化 handler。
        self.handler = handler
    }
    
    public func execute(_ object: T) {
        if let handler = handler {
            // 如果需要在主队列上执行。
            if onMainQueue {
                // 使用 DispatchQueue.tr.executeOnMain 在主队列上执行 handler。
                DispatchQueue.tr.executeOnMain {
                    handler(object)
                }
            } else {
                // 否则直接执行 handler。
                handler(object)
            }
        }
    }
    
}
