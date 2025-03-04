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
    
    // 使用 UnfairLock 实现线程安全。
    private let lock = ZYGDLUnfairLock()
    
    // 执行任务的队列。
    private var queue: DispatchQueue
    
    // 存储任务的字典。
    private var workItems = [String: DispatchWorkItem]()
    
    // 初始化方法，设置队列。
    public init(queue: DispatchQueue) {
        self.queue = queue
    }
    
    public func execute(label: String, deadline: DispatchTime, execute work: @escaping @convention(block) () -> Void) {
        // 执行任务，使用 DispatchTime 作为时间参数。
        execute(label: label, time: deadline, execute: work)
    }
    
    public func execute(label: String, wallDeadline: DispatchWallTime, execute work: @escaping @convention(block) () -> Void) {
        // 执行任务，使用 DispatchWallTime 作为时间参数。
        execute(label: label, time: wallDeadline, execute: work)
    }
    
    private func execute<T: Comparable>(label: String, time: T, execute work: @escaping @convention(block) () -> Void) {
        lock.around {
            // 取消已有的任务。
            workItems[label]?.cancel()
            // 执行任务并移除任务。
            let workItem = DispatchWorkItem { [weak self] in
                work()
                self?.workItems.removeValue(forKey: label)
            }
            // 存储新的任务。
            workItems[label] = workItem
            if let time = time as? DispatchTime {
                // 使用 DispatchTime 延迟执行任务。
                queue.asyncAfter(deadline: time, execute: workItem)
            } else if let time = time as? DispatchWallTime {
                // 使用 DispatchWallTime 延迟执行任务。
                queue.asyncAfter(wallDeadline: time, execute: workItem)
            }
        }
    }
}
