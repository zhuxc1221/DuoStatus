#!/bin/zsh
set -eu
cd "${0:A:h:h}"
mkdir -p .build assets/logo
/usr/bin/xcrun swiftc -O -file-prefix-map "$PWD=." -framework AppKit scripts/render-assets.swift -o .build/render-assets
.build/render-assets "$PWD"
/usr/bin/iconutil -c icns .build/DuoStatus.iconset -o assets/logo/DuoStatus.icns
