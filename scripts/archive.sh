#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate
xcodebuild -project BaizeBook.xcodeproj -scheme BaizeBook -destination 'generic/platform=iOS' -derivedDataPath build/ReleaseData -archivePath build/BaizeBook.xcarchive -allowProvisioningUpdates archive
python3 scripts/verify-archive.py
xcodebuild -exportArchive -archivePath build/BaizeBook.xcarchive -exportPath build/Distribution -exportOptionsPlist ExportOptions.plist -allowProvisioningUpdates
