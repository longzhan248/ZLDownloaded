//
//  ZYGDLProtector.swift
//  ZygoteNetwork
//
//  Created by zhanlong on 2025/2/19.
//

import Foundation

/// 不公平锁。
final public class ZYGDLUnfairLock {
    
    // 定义一个不公平锁类型的变量。
    private let unfairLock: os_unfair_lock_t
    
    // 初始化方法。
    public init() {
        // 分配内存空间。
        unfairLock = .allocate(capacity: 1)
        // 初始化不公平锁。
        unfairLock.initialize(to: os_unfair_lock())
    }
    
    // 析构方法。
    deinit {
        // 反初始化不公平锁。
        unfairLock.deinitialize(count: 1)
        // 释放内存空间。
        unfairLock.deallocate()
    }
    
    private func lock() {
        // 加锁。
        os_unfair_lock_lock(unfairLock)
    }
    
    private func unlock() {
        // 解锁。
        os_unfair_lock_unlock(unfairLock)
    }
    
    public func around<T>(_ closure: () throws -> T) rethrows -> T {
        // 在执行闭包前加锁，执行完毕后解锁。
        lock();
        defer {
            unlock()
        }
        // 执行闭包并返回结果。
        return try closure()
    }
    
    public func around(_ closure: () throws -> Void) rethrows -> Void {
        // 在执行闭包前加锁，执行完毕后解锁。
        lock();
        defer {
            unlock()
        }
        // 执行闭包并返回结果。
        return try closure()
    }
    
}

/// 用于保护某个值的线程安全访问。
final public class ZYGDLProtector<T> {
    
    // 使用 UnfairLock 实现线程安全。
    private let lock = ZYGDLUnfairLock()
    
    // 被保护的值。
    private var value: T
    
    public init(_ value: T) {
        // 初始化方法，设置初始值。
        self.value = value
    }
    
    public var directValue: T {
        // 获取值时加锁。
        get {
            return lock.around {
                value
            }
        }
        // 设置值时加锁。
        set {
            lock.around {
                value = newValue
            }
        }
    }
    
    public func read<U>(_ closure: (T) throws -> U) rethrows -> U {
        // 读取值时加锁，并执行闭包。
        return try lock.around {
            try closure(self.value)
        }
    }
    
    @discardableResult
    public func write<U>(_ closure: (inout T) throws -> U) rethrows -> U {
        // 写入值时加锁，并执行闭包。
        return try lock.around {
            try closure(&self.value)
        }
    }
}

/// 用于防抖动操作。
final public class ZYGDLDebouncer {
    
    private let dispatchQueue: DispatchQueue
    
    private let timeInterval: DispatchTimeInterval
    
    private var workItem: DispatchWorkItem?
    
    public init(timeInterval: DispatchTimeInterval) {
        self.dispatchQueue = DispatchQueue(label: UUID().uuidString)
        self.timeInterval = timeInterval
    }
    
    public func execute(on queue: DispatchQueue = .main, work: @escaping @convention(block) () -> Void) {
        dispatchQueue.sync {
            workItem?.cancel()
            let workItem = DispatchWorkItem { [weak self, weak queue] in
                queue?.async {
                    work()
                }
                self?.workItem = nil
            }
            self.workItem = workItem
            dispatchQueue.asyncAfter(deadline: .now() + timeInterval, execute: workItem)
        }
    }
    
}
