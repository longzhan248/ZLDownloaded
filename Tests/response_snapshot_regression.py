# 公司版权声明: Copyright (c) 广州心娱网络科技有限公司. All rights reserved.
# 开发人员: 詹龙 zhanlong@yunqi688.com
# 员工工号: XY-0398
# 内部IM ID: 957
# 手机尾号: 5352
# 创建日期: 2026-11-23

from pathlib import Path
import subprocess
import tempfile
source=(Path(__file__).resolve().parents[1] / 'Downloaded/Download/Core/ZYGDLDownloadTask.swift').read_text()
helper=source[source.index('internal struct ZYGDLResponseSnapshot:'):]
harness='''import Foundation
final class UnarchivableResponse: HTTPURLResponse, @unchecked Sendable {
    override func encode(with coder: NSCoder) { fatalError("不能归档原始响应") }
}
let url = URL(string: "https://example.com/file")!
let response = UnarchivableResponse(url: url, statusCode: 206, httpVersion: "HTTP/1.1", headerFields: ["Content-Type":"application/octet-stream", "ETag":"中文-value", "Content-Length":"1024"])!
let snapshot = ZYGDLResponseSnapshot(response: response)!
let encoder = PropertyListEncoder()
let data = try encoder.encode(snapshot)
let restored = try PropertyListDecoder().decode(ZYGDLResponseSnapshot.self, from: data).makeResponse()!
precondition(restored.url == url && restored.statusCode == 206)
precondition(restored.value(forHTTPHeaderField: "Content-Length") == "1024")
precondition(restored.value(forHTTPHeaderField: "ETag") == "中文-value")
let empty = HTTPURLResponse(url: url, statusCode: 204, httpVersion: nil, headerFields: nil)!
precondition(ZYGDLResponseSnapshot(response: empty)!.makeResponse()!.statusCode == 204)
let oldData = try NSKeyedArchiver.archivedData(withRootObject: empty, requiringSecureCoding: true)
let oldResponse = try NSKeyedUnarchiver.unarchivedObject(ofClass: HTTPURLResponse.self, from: oldData)!
precondition(ZYGDLResponseSnapshot(response: oldResponse)!.makeResponse()!.statusCode == 204)
for _ in 0..<10000 { _ = try encoder.encode(snapshot) }
print("PASS: 响应快照往返、空响应头、非 ASCII 响应头、禁止归档原对象、10000 次编码")
'''
with tempfile.TemporaryDirectory(prefix="response-snapshot-") as directory:
    test = Path(directory) / 'main.swift'
    test.write_text('import Foundation\n'+helper+'\n'+harness)
    subprocess.run(['swift', str(test)], check=True)
