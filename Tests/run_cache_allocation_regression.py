# 公司版权声明: Copyright (c) 广州心娱网络科技有限公司. All rights reserved.
# 开发人员: 詹龙 zhanlong@yunqi688.com
# 员工工号: XY-0398
# 内部IM ID: 957
# 手机尾号: 5352
# 创建日期: 2026-11-10
import argparse, pathlib, subprocess, tempfile, os
parser = argparse.ArgumentParser()
parser.add_argument("--zip-source", required=True, type=pathlib.Path)
parser.add_argument("--simulator", required=True)
parser.add_argument("--optimized", action="store_true")
parser.add_argument("--baseline", action="store_true", help="使用 HEAD 中的旧缓存实现验证回归样本会崩溃")
args = parser.parse_args()
root = pathlib.Path(__file__).resolve().parents[1]
sdk = subprocess.check_output(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-path"], text=True).strip()
base = ["-sdk", sdk, "-target", "arm64-apple-ios27.2-simulator"]
with tempfile.TemporaryDirectory(prefix="download-cache-regression-") as folder:
    folder = pathlib.Path(folder)
    def run(command, **kwargs):
        subprocess.run(command, check=True, timeout=180, **kwargs)
    run(["xcrun", "clang", "-dynamiclib", "-isysroot", sdk, "-target", "arm64-apple-ios27.2-simulator"] + [str(root / "Tests/CacheAllocationFailure.c"), "-o", str(folder / "libAllocation.dylib")])
    run(["xcrun", "swiftc", "-swift-version", "5"] + base + ["-emit-library", "-emit-module", "-module-name", "ZIPFoundation"] + [str(p) for p in args.zip_source.glob("*.swift")] + ["-o", str(folder / "libZIPFoundation.dylib")], cwd=folder)
    (folder / "Prefix.h").write_text("#import <UIKit/UIKit.h>\n")
    (folder / "main.swift").write_text((root / "Tests/CacheAllocationRegression.swift").read_text())
    sources = [str(p) for p in (root / "Downloaded/Download").rglob("*.swift") if "Bridge" not in p.parts]
    if args.baseline:
        old = subprocess.check_output(["git", "show", "HEAD:Downloaded/Download/Core/ZYGDLCache.swift"], cwd=root, text=True)
        original = folder / "OriginalCache.swift"
        original.write_text(old)
        sources = [str(original) if pathlib.Path(p).name == "ZYGDLCache.swift" else p for p in sources]
    run(["xcrun", "swiftc", "-swift-version", "5", "-O" if args.optimized else "-Onone"] + base + ["-import-objc-header", str(folder / "Prefix.h"), "-I", str(folder), "-L", str(folder), "-lAllocation", "-lZIPFoundation", "-Xlinker", "-rpath", "-Xlinker", str(folder)] + sources + [str(folder / "main.swift"), "-o", str(folder / "probe")])
    env = dict(os.environ, SIMCTL_CHILD_DYLD_INSERT_LIBRARIES=str(folder / "libAllocation.dylib"))
    run(["xcrun", "simctl", "spawn", args.simulator, str(folder / "probe")], env=env)
