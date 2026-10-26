# 公司版权声明: Copyright (c) 广州心娱网络科技有限公司. All rights reserved.
# 开发人员: 詹龙 zhanlong@yunqi688.com
# 员工工号: XY-0398
# 内部IM ID: 957
# 手机尾号: 5352
# 创建日期: 2026-10-26

"""直接执行源码中的关联扩展；仅验证关联生命周期，不构建 iOS 工程。"""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / "Downloaded/Download/Core/ZYGDLCommon.swift").read_text()
# 仅替代依赖 UIKit 的业务任务类型，关联容器与扩展使用实际生产源码。
association = source[source.index("extension URLSessionTask {"):]
helper_marker = "private final class ZYGDLWeakDownloadTaskReference"
if helper_marker in source:
    association = source[source.index(helper_marker):]
harness = """
import Foundation
import ObjectiveC.runtime

final class ZYGDLDownloadTask: NSObject {
    var sessionTask: URLSessionTask?
}
""" + association + """

let session = URLSession(configuration: .ephemeral)
let networkTask = session.downloadTask(with: URL(string: "https://example.invalid/test")!)
var owner: ZYGDLDownloadTask? = ZYGDLDownloadTask()
weak var weakOwner = owner
owner?.sessionTask = networkTask
networkTask.zygdlTask = owner
precondition(networkTask.zygdlTask === owner, "存活时应返回原对象")
owner = nil
precondition(weakOwner == nil, "关联不能形成循环引用")
precondition(networkTask.zygdlTask == nil, "对象释放后应安全返回 nil")

let first = ZYGDLDownloadTask()
let second = ZYGDLDownloadTask()
networkTask.zygdlTask = first
networkTask.zygdlTask = second
precondition(networkTask.zygdlTask === second, "替换关联后应返回新对象")
networkTask.zygdlTask = nil
precondition(networkTask.zygdlTask == nil, "显式清空后应返回 nil")

for _ in 0..<1000 {
    autoreleasepool {
        let transient = ZYGDLDownloadTask()
        networkTask.zygdlTask = transient
        precondition(networkTask.zygdlTask === transient)
    }
    precondition(networkTask.zygdlTask == nil, "反复释放后不应残留悬空引用")
}
session.invalidateAndCancel()
print("PASS: 存活读取、无循环引用、释放后读取、替换、清空及反复释放")
"""
with tempfile.TemporaryDirectory(prefix="zygdl-association-") as temporary:
    path = Path(temporary) / "main.swift"
    path.write_text(harness)
    result = subprocess.run(["swift", str(path)], capture_output=True, text=True)
    print(result.stdout)
    if result.returncode:
        print(result.stderr[-2500:])
    raise SystemExit(result.returncode)
