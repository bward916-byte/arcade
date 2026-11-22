# Floor Zero — native iOS

A Swift rewrite of `floor-zero/index.html`. No web view: the game logic is in `Sources/Game.swift` and every shape is drawn with CoreGraphics in `Sources/Draw.swift`.

In this first stage: the title, a five-shot opening, all three towers (Cole 83 floors, Maya 48, Jo 60) from roof to street, swing combos, power moves, zombies, runners, dogs, rats, bloaters and Dr. Marr, the sample and the water main, floor holes, burning stairwells, elevator hold-outs, fire walls with the office bypass, twelve upgrades picked one of two every six floors, saving, pause, sound and haptics.

Not ported yet: the helicopter roof and other outside help, the emergency-exit rides to other buildings, survivors and notes, the illustrated story panels, the demo and the map.

- Bundle ID `com.brianward.floorzero`, team `55NAZA6UKE`, iPhone only, landscape only.
- The Xcode project is generated from `project.yml` by XcodeGen (`xcodegen generate`), so there is no `.xcodeproj` in the repo.
- Build: the "Floor Zero Native iOS" workflow runs on every push that touches this folder. It compiles on a GitHub Mac, takes simulator screenshots, runs a bot through all three towers, and uploads to TestFlight with the same three secrets as the other apps (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`). The result is written to the `floorzero-native-buildlog` branch.
- TestFlight upload needs an App Store Connect app record for `com.brianward.floorzero`.
