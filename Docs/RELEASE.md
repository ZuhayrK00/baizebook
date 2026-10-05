# Release status — 5 October 2026

## Current App Store status

Version **1.0 (6)** is **Waiting for Review**, resubmitted on 5 October 2026 at 12:15 PM Europe/London with the renamed repository’s support links. The listing screenshots use fictional players Alex and Jamie. Automatic release after approval is selected. App Store availability is pending Apple’s approval. App source and the support site share the public [BaizeBook repository](https://github.com/ZuhayrK00/baizebook). Full submission details are in `Docs/APP_STORE.md`.

## Build 6 — support-link migration

Version **1.0 (6)** updates Settings → Help and support for the renamed `baizebook` repository. Phone and Watch archives passed signed-package checks with matching versions, assets and privacy manifests. The archived Release binary contains the new help URL and excludes the old URL. Apple accepted the upload on 5 October 2026 at 12:06 PM Europe/London and completed processing. The internal group shows **1 Tester / 5 Builds**, with **1.0 (6) Testing** and a 90-day expiry. Build-specific testing notes were saved. The last observed installation remains build 5; installation or physical testing of build 6 has not been performed by the agent. Build ID: `b6ec5c57-3b92-47ec-b163-b9b9e5deeb9d`.

Support and privacy pages at `https://zuhayrk00.github.io/baizebook/` and `https://zuhayrk00.github.io/baizebook/privacy.html` both returned HTTP 200. App Store and TestFlight website URLs are saved at these new addresses. The repository remains public to view. Only the owner account has write access; there are no collaborators, pending invitations or deploy keys. Active rules block force pushes and deletions on all branches; GitHub Actions defaults to read-only access and cannot approve pull requests.

Submission ID: `c964283e-c732-4821-9841-0e983fbbea88`. App Store Connect visibly confirmed **1.0 (6) Waiting for Review** at 12:15 PM. The earlier build-5 submission was withdrawn to replace its old Help URL. Receipt: `build/AppStore-Build6-Submitted.jpg`. The current `build/BaizeBook.xcarchive` and `build/Distribution/BaizeBook.ipa` contain build 6.

## Build 5 — available in TestFlight

Version **1.0 (5)** fits short bottom sheets to their content, with minimal padding beneath the final action or Cancel. This covers multiple reds, frame winners, session closure, match deletion, fouls, free balls, score adjustments and player editing. Longer content scrolls at large accessibility text sizes.

Settings → Your data now includes **Clear all data**, with a permanent-deletion warning and explicit confirmation. It removes all players and match history, resets preferences, clears the active match and Watch snapshot, and returns navigation to the empty home screen. Exported backups remain intact and can be imported again. An import already being read cannot repopulate the preview after a reset.

Verification: 13 storage/watch-command checks and six phone UI journeys passed across the two changes. These include cancellation, reset persistence after relaunch, new player creation after reset, preference clearing, preserved backup restoration and stale Watch command rejection. Sheet screenshots were inspected on iPhone 17 Pro Max and iPhone SE with very large text; release screenshots are in `Docs/Screenshots/Build5/`. The signed archive and exported IPA passed package checks, with phone and Watch both verified as **1.0 (5)**. Apple accepted the upload on 5 October 2026 at 10:27 BST and completed processing. The **BaizeBook Personal Testing** group shows **1 Tester / 4 Builds**, with **1.0 (5) Testing** and a 90-day expiry. Build ID: `819815d9-4762-438f-8d21-be9cad8f35e6`. Build-specific testing notes were saved and the UI confirmed Saved. The tester row reports **Installed 1.0 (5)** on an iPhone 17 Pro Max / iOS 27.0; the agent did not perform that installation or physical-device testing.

Build dashboard: https://appstoreconnect.apple.com/teams/eabaf5a9-8c35-49d2-b366-e1752af655ca/apps/6819089436/testflight/ios/819815d9-4762-438f-8d21-be9cad8f35e6. Those archive and IPA paths have since been replaced by build 6.

## Build 4 — available in TestFlight

Version **1.0 (4)** moves multiple reds out of the three-dot menu. Immediately after a single red is potted, **Potted multiple reds?** appears above Foul / End turn. The selected total includes the first red, revises the same shot, and restores/redoes all reds with one undo/redo action. The prompt disappears after the next scoring action or confirming a multiple-red shot; a single remaining red does not offer it. Stale corrections are rejected if a Watch action changes the shot.

Frame-winner selection, ending an open session and deleting a match now use consistent rounded sheets, with explicit actions and cancellation instead of anchored confirmation popovers. The scoring layout keeps both score values the same size on small screens, with a 44-point tap area for the new prompt.

Verification: 38 core checks passed (the unchanged private import-fixture check was skipped in this run), including three new multiple-red tests. One storage/backup/revision check and three iPhone SE UI journeys passed, covering inline totals, undo/redo, winner selection/cancellation, ending sessions and history deletion. A layout follow-up passed after visual refinement. Final screenshots are in `Docs/Screenshots/Build4/`. The signed phone/Watch archive and export passed package validation, and both targets in the IPA were verified as 1.0 (4). Upload succeeded on 5 October 2026 at 10:00 BST; Apple processed the package. The **BaizeBook Personal Testing** group shows **1 Tester / 3 Builds**, with **1.0 (4) Testing** and a 90-day expiry. Build ID: `28d9507a-6315-40ac-b5d9-b5de878084c5`. The tester row reports **Installed 1.0 (4)** on an iPhone 17 Pro Max / iOS 27.0; physical scoring validation remains with the account holder. Build-specific testing notes were saved and the UI confirmed Saved.

## Build 3 — available in TestFlight

Build **1.0 (3)** introduced these changes. This update adds SnookerMate import with profile linking, manual past-game entry, open sessions, a fixed phone scoring screen, simpler fouls, tapping names to switch players, grouped frame stories, explicit frame winners, history corrections, undo/redo, match deletion and simpler wrist controls. Imports are read off the UI thread and merged in one local database transaction. No backend or account requirement was added to the app.

Verification: **36 core tests**, including the supplied export's 50 matches / 242 frames / 13,103 shots, **10 storage/watch-command tests**, and **6 phone UI journeys** passed across the verification runs. The supplied JSON is not bundled or committed. Checks cover manual 52–32 scores, the screenshot's 53–30 frame, preserved legacy penalties, backup round trips, duplicate imports, redo branching, historical corrections, local reloads, session closure, explicit winner selection, past-game entry/edit/undo/redo/deletion and grouped ball visits. The iPhone SE scoring screen is usable without scrolling; it was also inspected with very large system text. A paired iOS/watchOS 26.5 simulator also verified a wrist pot changing the persisted phone score from 24 to 25 exactly once. The compact watch layout fits without a scrolling main score page. Phone/watch release packaging checks passed, including matching build numbers, assets, privacy manifests and signatures. New images are in `Docs/Screenshots/Build3/`.

An additional iOS/watchOS 27 **beta runtime** integration run stalled in UI automation and was interrupted; it is not counted as a successful test. The completed UI verification used iOS 26.5. Physical phone/watch testing remains with the account holder through TestFlight.

**Build 3 was uploaded successfully on 5 October 2026 at 09:35 BST.** The account holder restored the Xcode sign-in, Apple accepted and processed the package. The existing **BaizeBook Personal Testing** group shows **1 Tester / 2 Builds**, with **1.0 (3) Testing** and a 90-day expiry. Build ID: `35598f9f-bef0-49ed-80d4-0c9964870c52`. Build-specific testing notes were saved and the UI confirmed Saved. The account holder can open TestFlight and update BaizeBook; physical installation has not been performed by the agent. No credential is saved in the repository. The current `build/BaizeBook.xcarchive` and `build/Distribution/BaizeBook.ipa` have since been replaced by build 4.

The sections below record the previous shipped build 2 and existing App Store setup.

## Previously shipped build 2

BaizeBook 1.0 (build 2), iOS/iPadOS 17+ and watchOS 10+. Native Liquid Glass on iOS 26. Local SwiftData storage and JSON backups. Embedded watch app with compact WatchConnectivity score snapshots and revision-checked scoring commands.

Project: `BaizeBook.xcodeproj`. Apple team: `7NW33277C8`. Phone bundle ID: `com.zuhayrk.baizebook`. Watch bundle ID: `com.zuhayrk.baizebook.watchkitapp`.

Build 2 was archived, exported and uploaded with the phone and watch apps. The archive and exported IPA at those paths now contain build 6. The corrected package includes compiled iPhone/iPad/watch icons and privacy manifests. `scripts/verify-archive.py` checks these artifacts before export/upload.

## Verification

- 30 shared scoring tests passed on macOS and iOS. They also passed again with the refreshed Xcode 27 toolchain after the packaging fix.
- 7 storage/watch tests passed on iOS: merge import, invalid files, duplicate imports, local edits, player archiving, stale/duplicate wrist commands, small snapshots and malformed snapshots.
- iPhone journeys cover player creation, new match, legal ball enabling, score/undo, foul, end turn, relaunch recovery and history. Screenshot journey covers home, scoring, statistics and settings. Traditional scoring and frame-result undo are also tested.
- iPad scoring/statistics screenshots and tests passed.
- iPhone SE simulator in dark appearance and accessibility-extra-extra-large text passed the screenshot journey after layout refinement. At accessibility sizes, score metrics, controls and stats stack vertically, and the ball grid uses wider columns.
- Paired watch/iPhone simulator communication was verified: the watch displayed the selected frame and a wrist pot changed the phone's persisted score from 24 to 25.
- A watch rendering crash on clearing a match was fixed by capturing player names for the rendered snapshot. Regression tests with the watch active completed without crash attachments.
- Final archive signature verification passed for the phone and embedded watch app. Release binaries exclude demo and simulator probe options.
- Simulator and signed release builds succeeded. Privacy manifest and opaque 1024px icon are included. Debug-only demo and simulator probe code are excluded from Release.

Apple distribution validation, upload and processing succeeded. Physical-device testing and App Review have not occurred. The watch controls for advanced fouls remain on iPhone; the watch supports basic fouls and pots.

## Public support pages

- Support: https://zuhayrk00.github.io/baizebook/
- Privacy: https://zuhayrk00.github.io/baizebook/privacy.html
- App and support repository: https://github.com/ZuhayrK00/baizebook

Both pages returned HTTP 200 after publication. GitHub Pages reported a completed build. Hosting is free; the app has no server dependency. Support requests can use the repository’s Issues. App source and website source now share this repository; the `gh-pages` branch serves the website. Historical screenshots referenced in older release notes are retained in the local development archive. Only current screenshots with fictional players are published.

Listing copy and reviewer notes are in `Docs/APP_STORE.md`. Simulator screenshot sets are in `Docs/Screenshots/`.

## TestFlight setup

The internal group **BaizeBook Personal Testing** was created with automatic distribution enabled, and the account holder was added as its one tester. Beta description, testing guidance and public marketing/privacy URLs were saved and verified. Dashboard: https://appstoreconnect.apple.com/teams/eabaf5a9-8c35-49d2-b366-e1752af655ca/apps/6819089436/testflight.

**Previous build:** BaizeBook **1.0 (2)** passed upload validation and processing on 5 October 2026. The private group shows **1 Tester / 1 Build**, build status **Testing**, and tester status **Invited**. The invitation is addressed to the account holder. Accept it on an iPhone through Apple TestFlight. This dashboard is a management link, not a public installation link. The build expires after 90 days.

Build dashboard: https://appstoreconnect.apple.com/teams/eabaf5a9-8c35-49d2-b366-e1752af655ca/apps/6819089436/testflight/ios/d6d6ca15-bf04-430d-b384-f5cdbc8e4817. Build-specific testing notes were saved. This records build 2’s original release; build 6 is now the current update.

## Distribution setup

App Store Connect Account Holder/Admin and Shift TestFlight access were verified. Shift's Supabase dashboard was verified; BaizeBook does not use it.

The phone and watch bundle IDs are registered. The BaizeBook App Store Connect record was created with iOS, English (UK), SKU `baizebook-ios-001` and full user access. The name is reserved. Apple app ID: `6819089436`; dashboard: https://appstoreconnect.apple.com/apps/6819089436/distribution.

The Mac was unlocked, Xcode system setup completed and the Apple account session was refreshed. No password was needed by the agent or stored in the project. The first upload exposed a generated-project resource omission: the asset catalogs and privacy manifest were not attached to their targets. Build 2 fixes this and adds artifact checks. Both targets now include their correct icon catalog and privacy manifest. Version/build numbers come from the shared project settings.

The user's refreshed Xcode installation is Xcode 27.0, build `27A266a`, with iOS/watchOS 27 SDKs. Deployment targets remain iOS 17 / watchOS 10. The prior functional simulator journeys passed with Xcode 26.6; the 30 core tests also pass on the refreshed toolchain. A simulator inventory command did not return after the Xcode component update, so no repeat simulator journey is claimed for build 2; app logic is unchanged.

## Remaining launch work

1. Complete physical iPhone/Watch scoring and backup/recovery checks using `Docs/TESTFLIGHT.md`.
2. Await App Review and respond to any feedback. Required listing assets, pricing, age rating, content rights, privacy disclosure and reviewer contact are complete. Optional accessibility labels remain unspecified until verified.
3. Confirm Apple’s approval and actual storefront availability before announcing the release.

There are no subscriptions or in-app purchases to configure. There is no authentication service, remote database or analytics service to operate.
