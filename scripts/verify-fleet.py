#!/usr/bin/env python3
"""Readiness checks for the complete fleet-development profile; no model requests."""
import json, os, shutil, socket, subprocess, time
from pathlib import Path

results=[]
def check(name, action):
    try:
        detail=action()
        results.append({"check":name,"status":"passed","detail":str(detail or "")})
        print("OK      "+name,flush=True)
    except Exception as error:
        results.append({"check":name,"status":"failed","detail":str(error)})
        print("FAILED  "+name+": "+str(error),flush=True)

def run(*args, timeout=90):
    p=subprocess.run(args,capture_output=True,text=True,timeout=timeout)
    if p.returncode:raise RuntimeError((p.stderr or p.stdout)[-1200:])
    return p.stdout

def app(name):
    p=Path("/Applications")/(name+".app")
    if not p.is_dir():raise RuntimeError("application not installed")
    run("codesign","--verify","--strict",str(p))
    return "installed; code signature valid"

for name in ("T3 Code (Nightly)","ChatGPT","Claude","Cursor","Visual Studio Code","Ghostty","Expo Orbit","N2 Agents"):
    check(name,lambda name=name:app(name))
for binary in ("t3","code","cursor","pnpm","eas","wrangler","playwright","playwright-cli",
               "python3","cmake","ninja","rustc","cargo","go","java","javac","adb","android",
               "ffmpeg","magick","pdftotext"):
    def executable(binary=binary):
        path=shutil.which(binary)
        if not path:raise RuntimeError("command missing")
        flags={"go":["version"],"java":["-version"],"javac":["-version"],"adb":["version"],"android":["-V"],"ffmpeg":["-version"],"magick":["-version"],"pdftotext":["-v"]}.get(binary,["--version"])
        run(binary,*flags,timeout=30)
        return path
    check(binary,executable)

def t3():
    status=run("t3","service","status")
    if "Status: installed" not in status:raise RuntimeError("native T3 service needs repair")
    with socket.create_connection(("127.0.0.1",3773),timeout=5):pass
    return "native login service healthy; loopback server responds"
check("T3 background service",t3)

def ios():
    data=json.loads(run("xcrun","simctl","list","runtimes","-j"))
    names=[r["name"] for r in data["runtimes"] if r.get("isAvailable") and r["name"].startswith("iOS")]
    if not names:raise RuntimeError("no usable iOS runtime")
    return ", ".join(names)
check("iOS simulator runtime",ios)

def android():
    sdk=Path(os.environ.get("ANDROID_HOME",Path.home()/"Library/Android/sdk"))
    if not (sdk/"platforms/android-36/android.jar").is_file():raise RuntimeError("Android 36 SDK missing")
    if not run("android","emulator","list").strip():raise RuntimeError("no Android virtual device")
    return "SDK, build tools, emulator, and AVD installed"
check("Android development",android)
check("Expo/EAS authentication",lambda:run("eas","whoami",timeout=45).splitlines()[0])
def cloud():
    out=run("wrangler","whoami",timeout=45)
    if "logged in with" not in out:raise RuntimeError("Cloudflare sign-in missing")
    return "authenticated"
check("Cloudflare authentication",cloud)
check("Container engine",lambda:run("docker","version","--format","{{.Server.Version}}"))
def bot_identity():
    author=run("git","dougbot","config","--get","user.name").strip()
    user=run("gh","api","user","--jq",".login").strip()
    if author!="dougbot-agent" or user!="dougbot-agent":raise RuntimeError("bot identity mismatch")
    return "dougbot-agent"
check("Git bot identity",bot_identity)
report={"checkedAt":time.time(),"hostname":socket.gethostname(),"results":results}
destination=Path.home()/".config/agent-worker/fleet-readiness.json"
destination.write_text(json.dumps(report,indent=2)+"\n")
raise SystemExit(any(r["status"]!="passed" for r in results))
