# ZLDownloaded

## 1.0.12：异步任务准备与业务完成代理

`downloadAsync` 将 URL 转换、任务查询、创建和启动安排放在下载队列中执行，调用方不再同步等待该队列。原有 `download`、通知及 success/failure/completion 接口继续兼容。

仅升级版本不会改变旧调用的同步行为。首装资源批量下载的调用方必须改用新接口。

```swift
final class ResourceDownloadOwner: NSObject, ZYGDLBGSessionManagerDownloadDelegate {
    private let manager = ZYGDLBGSessionSingleton.shared.sessionManager

    // 在主线程设置；delegate 为弱引用，宿主需持续持有本对象。
    func configure() {
        manager.downloadDelegate = self
    }

    func download(_ url: NSURL) {
        manager.downloadAsync(url: url) { task, error in
            // 主线程：准备回调恰好一次；处理错误、登记 task 和业务订阅。
            // 缓存命中、已取消/移除任务应结合 task.status 处理。
        }
    }

    func downloadManager(_ manager: ZYGDLBGSessionManager, didComplete task: ZYGDLBGDownloadTask) {
        // 主线程异步回调；结合 task.status、task.error 和 URL 完成业务订阅。
    }
}
```

完成代理独立于已有任务闭包，不使用 NotificationCenter。库仍保留通知以兼容其他调用方。每个 manager 只有一个弱引用 `downloadDelegate`，共享 manager 的业务方应由同一个宿主按 URL 分发订阅，不要互相覆盖代理。

准备回调成功只表示任务已建立并安排启动，不表示文件已下载完成。已有 canceled/removed 任务沿用原行为，不自动重启。完成事件可因重试或缓存再次请求而多次触发，调用方需按当前业务订阅去重。首次构造 manager 的缓存恢复和 session 初始化仍保留原行为。

## 验证

运行 `python3 Tests/run_async_regression.py`。测试编译并执行发布源码中的异步调度和代理分发方法，替换 iOS 网络和缓存依赖，覆盖繁忙队列非阻塞、主队列回调、转换失败、重复 URL、准备/完成顺序及代理回调重入。

此测试不代表完整 iOS 编译、Objective-C 桥接验证、网络下载或真机首装卡顿验收。需要在主工程接入后验证首装登录、已有缓存、成功/失败、后台恢复和与旧模块共存。
