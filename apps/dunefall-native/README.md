# Dunefall — native iOS trial

A Swift rewrite of part of `dunefall/index.html`: the title screen and the first town (ride, toss coins, recruit nomads, rebuild, hold off the night raids). No web view: the game logic is in `Sources/Game.swift` and every shape is drawn with CoreGraphics in `Sources/Draw.swift`.

Not in the trial: towns 2 to 5, cutscenes, weather, the tomb, fishing, the shop upgrades, the treasury, saving, music.

- Bundle ID `com.brianward.dunefall`, team `55NAZA6UKE`, iPhone only, landscape only.
- The Xcode project is generated from `project.yml` by XcodeGen (`xcodegen generate`), so there is no `.xcodeproj` in the repo.
- Build: the "Dunefall Native iOS" workflow runs on every push that touches this folder. It compiles on a GitHub Mac, takes simulator screenshots, and uploads to TestFlight. It uses the same three secrets as Dustfall III (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`).
- TestFlight needs an app record for `com.brianward.dunefall` in App Store Connect before the upload step can succeed.
