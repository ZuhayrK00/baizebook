#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate
swift test
simulator_id="${1:-9E68FD2D-5CA2-4C6C-80D3-8D97BF85F630}"
xcodebuild -project BaizeBook.xcodeproj -scheme BaizeBook -destination "platform=iOS Simulator,id=$simulator_id" -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO test
