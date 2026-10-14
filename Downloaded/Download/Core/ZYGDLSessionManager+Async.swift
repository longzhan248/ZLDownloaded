/*
 * 公司版权声明: Copyright (c) 广州心娱网络科技有限公司. All rights reserved.
 * 开发人员: 詹龙 zhanlong@yunqi688.com
 * 员工工号: XY-0398
 * 内部IM ID: 957
 * 手机尾号: 5352
 * 创建日期: 2026-10-14
 */

import Foundation

/// 独立于已有 success/failure/completion 闭包的完成事件，不覆盖任务回调。
public protocol ZYGDLSessionManagerDownloadDelegate: AnyObject {
    /// 主线程异步调用；缓存命中也会通知。任务可能因重试产生多次完成事件。
    func downloadManager(_ manager: ZYGDLSessionManager, didComplete task: ZYGDLDownloadTask)
}

extension ZYGDLSessionManager {
    /// 异步创建并启动任务，调用方不等待下载队列。
    /// prepared 在主线程异步调用一次，失败时返回 nil 和错误；成功时先安排
    /// prepared，再启动任务。URLConvertible 的转换在下载队列执行。
    public func downloadAsync(_ url: ZYGDLURLConvertible,
                              headers: [String: String]? = nil,
                              fileName: String? = nil,
                              prepared: @escaping (ZYGDLDownloadTask?, Error?) -> Void) {
        operationQueue.async {
            do {
                let validURL = try url.asURL()
                let task = self.prepareDownload(validURL, headers: headers, fileName: fileName)
                DispatchQueue.main.async { prepared(task, nil) }
                self.start(task)
            } catch {
                DispatchQueue.main.async { prepared(nil, error) }
            }
        }
    }

    internal func notifyDownloadDelegate(_ task: ZYGDLDownloadTask) {
        // 不在下载队列同步调用业务代码，允许业务回调重新发起下载。
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.downloadDelegate?.downloadManager(self, didComplete: task)
        }
    }
}
