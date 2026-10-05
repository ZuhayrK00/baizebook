# BaizeBook

An entirely local, free snooker scorer for iPhone, iPad and Apple Watch. No accounts, advertising, analytics, remote database or paid service.

## Launch scope

- Players with editable names, match/frame wins, win rate, highest break, 30/50/100 breaks, head-to-head results and match history.
- Best-of matches, 1–15 reds, alternating break-off, guided ball scoring and traditional manual scoreboard.
- Legal red/colour sequence, multiple reds, final colour after the last red, colour clearance, fouls (4–7), removed reds, free balls, pass-back, foul-and-miss replacement, concession, re-spotted black and reversible scoring.
- Points remaining, lead/deficit, minimum snookers estimate, current break and frame timer with pause/resume.
- Immediate local saves, resume after relaunch, validated versioned JSON backups with merge import and duplicate protection. User names stay on device. Import compatible BaizeBook files; other scorers need an actual sample export before a converter can be implemented.
- Watch companion shows the active frame and supports live scoring, end turn, undo and basic fouls. The iPhone is authoritative; disconnected watch controls are disabled rather than silently risking conflicting scores.
- Native SwiftUI navigation and Liquid Glass on iOS 26, accessible fallback on iOS 17+, light/dark themes, Dynamic Type, VoiceOver labels, large tap targets and optional haptics.

## Architecture

Shared pure Swift domain models and scoring reducer, local SwiftData records on iPhone, WatchConnectivity snapshots and revision-checked commands on watch. Native frameworks only. Events retain prior states for undo and history. Statistics are derived from the saved frames.

## Verification

Domain tests cover a 147, shortened frames, last-red fouls, free balls, multiple reds, colour fouls, final-black foul/tie, replay, undo, stats and malformed/duplicate imports. Build both platforms, run simulator UI journeys (players → match → scoring → undo → history → relaunch), inspect phone/iPad/watch layouts and archive the signed release.

## Release

Apple team 7NW33277C8 is configured locally; App Store Connect Account Holder/Admin and Shift TestFlight access were verified on 4 October 2026. Shift's Supabase dashboard was also verified and is healthy; BaizeBook does not need it. Reserve the selected name and bundle IDs, create the app record, prepare icon/screenshots/privacy/support pages and metadata, validate the archive, upload to TestFlight, then submit the reviewed build. Distribution signing and upload are verified separately from website access. Apple review timing is outside our control.

## Sources

- https://apps.apple.com/gb/app/snookermate-snooker-scoreboard/id6745492966
- https://www.wpbsa.com/rules/
- https://developer.apple.com/documentation/swiftdata
- https://developer.apple.com/documentation/watchconnectivity
- https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views
