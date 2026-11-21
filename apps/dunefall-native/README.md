# Dunefall — native iOS trial

A Swift rewrite of part of `dunefall/index.html`: the title screen and the first town (ride, toss coins, recruit nomads, rebuild, hold off the night raids). No web view: the game logic is in `Sources/Game.swift` and every shape is drawn with CoreGraphics in `Sources/Draw.swift`.

Stage 1 of the full conversion adds the treasury, the upgrade signposts, the trade caravan, the warlord, the bazaar crowd, music, saving at each dawn, a pause menu, haptics and game-controller support. Still to port: the far sites and the dock, towns 2 to 5 and their bosses, cutscenes, weather, the tomb, fishing.

- Bundle ID `com.brianward.dunefall`, team `55NAZA6UKE`, iPhone only, landscape only.
- The Xcode project is generated from `project.yml` by XcodeGen (`xcodegen generate`), so there is no `.xcodeproj` in the repo.
- Build: the "Dunefall Native iOS" workflow runs on every push that touches this folder. It compiles on a GitHub Mac, takes simulator screenshots, and uploads to TestFlight. It uses the same three secrets as Dustfall III (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`).
- The App Store Connect app record for `com.brianward.dunefall` exists (Apple ID 6837632400), so builds upload to TestFlight.
