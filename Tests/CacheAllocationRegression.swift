// 公司版权声明: Copyright (c) 广州心娱网络科技有限公司. All rights reserved.
// 开发人员: 詹龙 zhanlong@yunqi688.com
// 员工工号: XY-0398
// 内部IM ID: 957
// 手机尾号: 5352
// 创建日期: 2026-11-10
import Foundation
let root = FileManager.default.temporaryDirectory.appendingPathComponent("download-probe-" + UUID().uuidString)
let cache = ZYGDLCache("probe", downloadPath: root.path)
let queue = DispatchQueue(label: "probe.operations")
let tasks = (0..<128).map { i in ZYGDLDownloadTask(URL(string: "http://127.0.0.1:18769/file?id=\(i)")!, cache: cache, operationQueue: queue) }
@_silgen_name("probe_arm") func probeArm()
@_silgen_name("probe_disarm") func probeDisarm()
for (i,task) in tasks.enumerated() {
 task.protectedState.write { $0.headers = ["X-Payload": "汉字<&>\n" + String(repeating: "x", count: 65536) + String(i)] }
}

// 先验证旧二进制 plist 可读取，再模拟缓存总体超过可分配连续块的情况。
let path = root.appendingPathComponent("probe_Tasks.plist")
let legacy = PropertyListEncoder()
legacy.outputFormat = .binary
try legacy.encode(Array(tasks.prefix(1))).write(to: path)
precondition(cache.retrieveAllTasks().count == 1)
print("ARM allocation failure"); fflush(stdout)
probeArm()
cache.storeTasks(tasks)
Thread.sleep(forTimeInterval: 2)
probeDisarm()
let restored = cache.retrieveAllTasks()
precondition(restored.count == 128, "保存失败或任务被丢弃")
precondition(restored.last?.headers == tasks.last?.headers, "字段不一致")
let xml = try Data(contentsOf: path)
precondition(xml.starts(with: Data("<?xml".utf8)))
print("PASS allocation-limit legacy-read=1 saved=128 bytes=\(xml.count)")
cache.storeTasks([])
Thread.sleep(forTimeInterval: 0.5)
precondition(cache.retrieveAllTasks().isEmpty)
print("PASS empty-array")
enum ProbeError: Error { case expected }
final class FailingTask: ZYGDLDownloadTask {
    override func encode(to encoder: any Encoder) throws { throw ProbeError.expected }
}
let previous = try Data(contentsOf: path)
let failing = FailingTask(URL(string: "https://example.com/failure")!, cache: cache, operationQueue: queue)
cache.storeTasks([failing])
Thread.sleep(forTimeInterval: 0.5)
let afterFailure = try Data(contentsOf: path)
precondition(afterFailure == previous, "编码失败覆盖了旧缓存")
let leftovers = try FileManager.default.contentsOfDirectory(atPath: root.path)
precondition(!leftovers.contains(where: { $0.hasSuffix(".tmp") }))
print("PASS failure-preserves-cache temporary-file-cleanup XML-escaping")
try FileManager.default.removeItem(at: root)
