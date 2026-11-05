#!/bin/zsh
set -eu
cd "${0:A:h}"
app="${1:-dist/DuoStatus.app}"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
/usr/bin/xcrun swiftc -swift-version 5 -O -module-name DuoStatus -target arm64-apple-macos27.0 -file-prefix-map "$PWD=." -framework Carbon -framework AppKit -framework CoreWLAN -framework ApplicationServices -framework IOKit main.swift -o "$app/Contents/MacOS/DuoStatus"
cp Info.plist "$app/Contents/Info.plist"
cp assets/logo/DuoStatus.icns "$app/Contents/Resources/AppIcon.icns"
/usr/bin/codesign --force --sign - "$app"
"$app/Contents/MacOS/DuoStatus" --self-test
