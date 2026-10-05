#!/usr/bin/env python3
"""Check the release artifacts that Apple's uploader expects."""
from pathlib import Path
import plistlib
import subprocess
import sys

archive = Path(sys.argv[1] if len(sys.argv) > 1 else 'build/BaizeBook.xcarchive')
phone = archive / 'Products/Applications/BaizeBook.app'
watch = phone / 'Watch/BaizeBookWatch.app'
versions = []
for app, identifier in [(phone, 'com.zuhayrk.baizebook'), (watch, 'com.zuhayrk.baizebook.watchkitapp')]:
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    assert info['CFBundleIdentifier'] == identifier, f'{app.name}: unexpected identifier'
    assert (app / 'Assets.car').is_file(), f'{app.name}: asset catalog missing'
    privacy = plistlib.loads((app / 'PrivacyInfo.xcprivacy').read_bytes())
    assert privacy['NSPrivacyTracking'] is False, f'{app.name}: unexpected privacy declaration'
    assert info['CFBundleIcons']['CFBundlePrimaryIcon']['CFBundleIconName'] == 'AppIcon', f'{app.name}: primary icon missing'
    versions.append((info['CFBundleShortVersionString'], info['CFBundleVersion']))
    executable = app / info['CFBundleExecutable']
    strings = subprocess.check_output(['strings', str(executable)], text=True)
    assert '--demo' not in strings and '--connection-probe' not in strings, f'{app.name}: debug probes in Release'
    print(f'{identifier}: {versions[-1]}, icons and privacy manifest present')
assert versions[0] == versions[1], 'Phone and watch versions differ'
phone_info = plistlib.loads((phone / 'Info.plist').read_bytes())
assert phone_info['CFBundleIcons~ipad']['CFBundlePrimaryIcon']['CFBundleIconName'] == 'AppIcon', 'iPad icon missing'
subprocess.run(['codesign', '--verify', '--deep', '--strict', str(phone)], check=True)
print('Archive package checks passed')
