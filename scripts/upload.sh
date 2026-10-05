#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/verify-archive.py
xcodebuild -exportArchive -archivePath build/BaizeBook.xcarchive -exportPath build/Upload -exportOptionsPlist ExportOptionsUpload.plist -allowProvisioningUpdates
