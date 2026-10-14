/*
 * 公司版权声明: Copyright (c) 广州心娱网络科技有限公司. All rights reserved.
 * 开发人员: 詹龙 zhanlong@yunqi688.com
 * 员工工号: XY-0398
 * 内部IM ID: 957
 * 手机尾号: 5352
 * 创建日期: 2026-10-14
 */

import Foundation
import Dispatch

// 测试只替换 iOS 网络/文件依赖；执行发布源码中的异步调度和代理分发方法。
public protocol ZYGDLURLConvertible { func asURL() throws -> URL }
extension String: ZYGDLURLConvertible {
    public func asURL() throws -> URL { return URL(string: self)! }
}
struct InvalidURL: ZYGDLURLConvertible {
    func asURL() throws -> URL { throw NSError(domain: "Regression", code: 1) }
}
public final class ZYGDLDownloadTask {
    let url: URL
    init(_ url: URL) { self.url = url }
}
public final class ZYGDLSessionManager {
    let operationQueue = DispatchQueue(label: "regression.download")
    public weak var downloadDelegate: ZYGDLSessionManagerDownloadDelegate?
    var tasks: [URL: ZYGDLDownloadTask] = [:]
    func prepareDownload(_ url: URL, headers: [String: String]?, fileName: String?) -> ZYGDLDownloadTask {
        if let task = tasks[url] { return task }
        let task = ZYGDLDownloadTask(url)
        tasks[url] = task
        return task
    }
    func start(_ task: ZYGDLDownloadTask) {
        operationQueue.async { self.notifyDownloadDelegate(task) }
    }
}
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError(message) }
}
let manager = ZYGDLSessionManager()
let gate = DispatchSemaphore(value: 0)
let entered = DispatchSemaphore(value: 0)
manager.operationQueue.async { entered.signal(); gate.wait() }
entered.wait()
var preparedCount = 0
var completeCount = 0
var errorCount = 0
var firstTask: ZYGDLDownloadTask?
let mainKey = DispatchSpecificKey<Bool>()
DispatchQueue.main.setSpecific(key: mainKey, value: true)
func checkMain() { check(DispatchQueue.getSpecific(key: mainKey) == true, "回调未在主队列执行") }
func finishIfReady() {
    if preparedCount == 3 && completeCount == 3 && errorCount == 1 {
        manager.downloadDelegate = nil
        check(manager.downloadDelegate == nil, "代理解绑失败")
        print("PASS: 繁忙下载队列不阻塞调用方；主队列回调；无效 URL；重复任务；准备先于完成；代理重入下载")
        exit(0)
    }
}
final class Delegate: ZYGDLSessionManagerDownloadDelegate {
    func downloadManager(_ manager: ZYGDLSessionManager, didComplete task: ZYGDLDownloadTask) {
        checkMain()
        check(preparedCount > completeCount, "完成事件先于任务准备回调")
        completeCount += 1
        if completeCount == 1 {
            manager.downloadAsync("https://example.com/reentry") { task, error in
                checkMain(); check(task != nil && error == nil, "重入下载失败")
                preparedCount += 1; finishIfReady()
            }
        }
        finishIfReady()
    }
}
let delegate = Delegate()
manager.downloadDelegate = delegate
let begin = DispatchTime.now().uptimeNanoseconds
for _ in 0..<2 {
    manager.downloadAsync("https://example.com/resource") { task, error in
        checkMain(); check(task != nil && error == nil, "任务准备失败")
        if let firstTask = firstTask { check(firstTask === task, "重复 URL 未复用底层任务") }
        else { firstTask = task }
        preparedCount += 1; finishIfReady()
    }
}
manager.downloadAsync(InvalidURL()) { task, error in
    checkMain(); check(task == nil && error != nil, "无效 URL 未回调失败")
    errorCount += 1; finishIfReady()
}
check(DispatchTime.now().uptimeNanoseconds - begin < 100_000_000, "调用同步等待了下载队列")
DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
    check(preparedCount == 0 && completeCount == 0, "阻塞下载队列时任务意外执行")
    gate.signal()
}
DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(5)) { fatalError("回调缺失或下载重入死锁") }
dispatchMain()
