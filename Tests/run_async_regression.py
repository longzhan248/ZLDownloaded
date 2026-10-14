# 公司版权声明: Copyright (c) 广州心娱网络科技有限公司. All rights reserved.
# 开发人员: 詹龙 zhanlong@yunqi688.com
# 员工工号: XY-0398
# 内部IM ID: 957
# 手机尾号: 5352
# 创建日期: 2026-10-14

import pathlib
import subprocess
import tempfile
import sys

root = pathlib.Path(__file__).resolve().parents[1]
source = root / "Downloaded/Download/Core/ZYGDLSessionManager+Async.swift"
assert source.exists(), "缺少非阻塞异步下载入口"
with tempfile.TemporaryDirectory() as directory:
    main = pathlib.Path(directory) / "main.swift"
    implementation = source.read_text()
    blocking_probe = "--verify-blocking-regression" in sys.argv
    if blocking_probe:
        implementation = implementation.replace("operationQueue.async {", "operationQueue.sync {", 1)
    main.write_text((root / "Tests/AsyncRegression.swift").read_text() + "\n" + implementation)
    binary = pathlib.Path(directory) / "regression"
    subprocess.run(["swiftc", "-swift-version", "5", str(main), "-o", str(binary)], check=True)
    if blocking_probe:
        try:
            subprocess.run([str(binary)], check=True, timeout=3)
        except subprocess.TimeoutExpired:
            print("PASS: 将异步入口退化为同步等待后，回归测试能检出阻塞")
        else:
            raise AssertionError("测试没有检出同步阻塞")
    else:
        subprocess.run([str(binary)], check=True, timeout=20)
