#!/bin/bash
# Native UI needs NSApplication.run(), which the Swift Testing runner does not host.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/shortcut-ui
sources=()
for source in Sources/GotifyMac/*.swift Sources/GotifyMac/Views/*.swift Sources/GotifyMac/Views/Settings/*.swift; do
    case "$source" in
        */GotifyMacApp.swift) ;;
        *) sources+=("$source") ;;
    esac
done
swiftc -swift-version 6 -parse-as-library "${sources[@]}" scripts/shortcut-ui-smoke.swift -o build/shortcut-ui-smoke
build/shortcut-ui-smoke
