# 公司版权声明: Copyright (c) 广州心娱网络科技有限公司. All rights reserved.
# 开发人员: 詹龙 zhanlong@yunqi688.com
# 员工工号: XY-0398
# 内部IM ID: 957
# 手机尾号: 5352
# 创建日期: 2026-10-14

import pathlib
import subprocess
import tempfile
root = pathlib.Path(__file__).resolve().parents[1]
s = (root / "Downloaded/Download/Core/ZYGDLDownloadTask.swift").read_text()
a = s.index("    internal func didFinishDownloading(")
b = s.index("    internal func didComplete(", a)
method = s[a:b]
fixture = r"""
import Foundation
final class URLSessionDownloadTask {
    let response: Any? = HTTPURLResponse()
}
final class HTTPURLResponse { let statusCode = 200 }
enum ZYGDLFileType { case zip, other; init(fileExtension: String) { self = fileExtension == "zip" ? .zip : .other } }
var failExtraction = false
extension FileManager {
    func unzipItem(at: URL, to: URL) throws {
        try Data("解压内容".utf8).write(to: to.appendingPathComponent("content"))
        if failExtraction { throw NSError(domain: "ZIPRegression", code: 7) }
    }
}
final class Cache {
    var moves = 0
    func storeFile(at: URL, to: URL) { moves += 1 }
    func removeTmpFile(_ name: String?) {}
}
final class Task {
    let acceptableStatusCodes = 200..<300
    let pathExtension: String? = "zip"
    let filePath: String
    let tmpFileName: String? = nil
    let cache = Cache()
    var error: Error?
    init(_ path: String) { filePath = path }
METHOD
}
let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
defer { try? FileManager.default.removeItem(at: root) }
let task = Task(root.appendingPathComponent("ok.zip").path)
task.didFinishDownloading(task: URLSessionDownloadTask(), to: root.appendingPathComponent("source"))
precondition(task.cache.moves == 0, "ZIP 解压后仍移动目录到自身")
precondition(task.error == nil)
precondition(FileManager.default.fileExists(atPath: task.filePath + "/content"))
failExtraction = true
let failed = Task(root.appendingPathComponent("failed.zip").path)
failed.didFinishDownloading(task: URLSessionDownloadTask(), to: root.appendingPathComponent("source"))
precondition(failed.error != nil, "解压失败未保留错误")
precondition(!FileManager.default.fileExists(atPath: failed.filePath), "解压失败留下不完整缓存")
print("PASS: ZIP 成功不移动自身；解压失败保留错误并清理不完整缓存")
"""
with tempfile.TemporaryDirectory() as directory:
    main = pathlib.Path(directory) / "main.swift"
    main.write_text(fixture.replace("METHOD", method))
    binary = pathlib.Path(directory) / "regression"
    subprocess.run(["swiftc", "-swift-version", "5", str(main), "-o", str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
