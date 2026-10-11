#!/usr/bin/env python3
"""Compile and run small programs against the worker's real toolchains."""
import json, os, plistlib, subprocess, tempfile, time
from pathlib import Path

results = []
def run(args, cwd, timeout=180):
    result = subprocess.run(args, cwd=cwd, capture_output=True, text=True, timeout=timeout)
    if result.returncode:
        raise RuntimeError(" ".join(args[:2]) + ": " + result.stderr[-1800:])
    return result.stdout

def verify(name, action):
    started = time.time()
    action()
    results.append({"check": name, "status": "passed", "seconds": round(time.time()-started, 2)})
    print(name + ": passed", flush=True)

developer = Path.home() / "Developer"
developer.mkdir(exist_ok=True)
with tempfile.TemporaryDirectory(prefix="fleet-native-", dir=developer) as temp:
    root = Path(temp)
    samples = [
        ("C", "main.c", '#include <stdio.h>\nint main(void){puts("FLEET_READY");return 0;}\n', ["clang", "main.c", "-o", "c-check"], ["./c-check"]),
        ("Swift", "main.swift", 'print("FLEET_READY")\n', ["swiftc", "main.swift", "-o", "swift-check"], ["./swift-check"]),
        ("Rust", "main.rs", 'fn main(){println!("FLEET_READY");}\n', ["rustc", "main.rs", "-o", "rust-check"], ["./rust-check"]),
        ("Go", "main.go", 'package main\nimport "fmt"\nfunc main(){fmt.Println("FLEET_READY")}\n', ["go", "build", "-o", "go-check", "main.go"], ["./go-check"]),
        ("Java", "Main.java", 'class Main {public static void main(String[] args){System.out.println("FLEET_READY");}}\n', ["javac", "Main.java"], ["java", "Main"]),
    ]
    for name, filename, text, compile_args, execute_args in samples:
        (root / filename).write_text(text)
        def action(c=compile_args, e=execute_args):
            run(c, root)
            assert "FLEET_READY" in run(e, root)
        verify(name, action)

    def ios():
        sdk = run(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-path"], root).strip()
        source = root / "FleetSmoke.swift"
        source.write_text('import SwiftUI\n@main struct FleetSmoke: App {var body: some Scene {WindowGroup {Text("FLEET_READY")}}}\n')
        app = root / "FleetSmoke.app"
        app.mkdir()
        info = {"CFBundleIdentifier":"com.noisyneighbor.fleetverifier","CFBundleExecutable":"FleetSmoke",
                "CFBundleName":"FleetSmoke","CFBundlePackageType":"APPL","CFBundleVersion":"1",
                "CFBundleShortVersionString":"1.0","MinimumOSVersion":"18.0","LSRequiresIPhoneOS":True,
                "UIDeviceFamily":[1,2],"UILaunchScreen":{}}
        (app / "Info.plist").write_bytes(plistlib.dumps(info))
        run(["swiftc","-parse-as-library","-sdk",sdk,"-target","arm64-apple-ios18.0-simulator",
             "-module-name","FleetSmoke",str(source),"-o",str(app / "FleetSmoke")], root)
        run(["codesign","--force","--sign","-",str(app)], root)
        devices = json.loads(run(["xcrun","simctl","list","devices","booted","-j"], root))
        booted = [d["udid"] for group in devices["devices"].values() for d in group if d["state"]=="Booted"]
        if not booted: raise RuntimeError("Boot an iOS simulator before this check.")
        run(["xcrun","simctl","install",booted[0],str(app)], root)
        output = run(["xcrun","simctl","launch",booted[0],"com.noisyneighbor.fleetverifier"], root)
        assert "com.noisyneighbor.fleetverifier" in output
    verify("iOS simulator app compile, install, launch", ios)

destination = Path.home()/".config/agent-worker/native-build-results.json"
destination.write_text(json.dumps({"checkedAt":time.time(),"results":results}, indent=2)+"\n")
print("Native build verification complete.")
