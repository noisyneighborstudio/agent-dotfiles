#!/usr/bin/env python3
"""Install from N2's feed after verifying its signature and publisher."""
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import urllib.request
import xml.etree.ElementTree as ET

APP = Path("/Applications/N2 Agents.app")
BUNDLE_ID = "dev.sethwebster.n2agents"
TEAM = "P8ZBH5878Q"
SPARKLE = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"


def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True)


def validate(app):
    info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    if info.get("CFBundleIdentifier") != BUNDLE_ID:
        raise RuntimeError("Downloaded bundle is not N2 Agents.")
    run("codesign", "--verify", "--deep", "--strict", str(app))
    signature = run("codesign", "-dv", str(app)).stderr
    if f"TeamIdentifier={TEAM}" not in signature.splitlines():
        raise RuntimeError("N2 signing team differs from the verified current Mac.")
    if not (app / "Contents/Resources/agents").is_file():
        raise RuntimeError("N2 bundle is missing its CLI.")


def main():
    channel = sys.argv[1] if len(sys.argv) > 1 else "continuous"
    if channel not in ("stable", "continuous"):
        raise RuntimeError("Channel must be stable or continuous.")
    if APP.exists():
        validate(APP)
        print("Existing signed N2 retained. Update separately with agents update.")
        return
    feed = f"https://raw.githubusercontent.com/noisyneighborstudio/n2-agents/appcasts/{channel}/appcast.xml"
    with urllib.request.urlopen(feed, timeout=60) as response:
        xml = ET.fromstring(response.read())
    releases = []
    for enclosure in xml.findall("./channel/item/enclosure"):
        build = enclosure.get(SPARKLE + "version", "")
        url = enclosure.get("url", "")
        if build.isdigit() and url.startswith("https://github.com/noisyneighborstudio/n2-agents/releases/download/"):
            releases.append((int(build), url))
    if not releases:
        raise RuntimeError("No matching release in the N2 feed.")
    _, url = max(releases)
    with tempfile.TemporaryDirectory(prefix="agent-n2-") as temporary:
        temp = Path(temporary)
        archive = temp / "N2Agents.zip"
        with urllib.request.urlopen(url, timeout=120) as response, archive.open("wb") as output:
            shutil.copyfileobj(response, output)
        unpacked = temp / "unpacked"
        run("ditto", "-xk", str(archive), str(unpacked))
        apps = list(unpacked.glob("*.app"))
        if len(apps) != 1:
            raise RuntimeError("Release must contain exactly one app.")
        validate(apps[0])
        if os.access(APP.parent, os.W_OK):
            run("ditto", str(apps[0]), str(APP))
        else:
            run("sudo", "ditto", str(apps[0]), str(APP))
        validate(APP)
        print(f"Installed verified N2 Agents from {channel}.")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"N2 installation failed: {error}", file=sys.stderr)
        sys.exit(1)
