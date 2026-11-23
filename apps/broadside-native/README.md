# Broadside — native iOS

A Swift rewrite of `broadside/index.html`. No web view: the rules are in `Sources/Game.swift` and every shape is drawn with CoreGraphics in `Sources/Scene.swift`.

Ported so far (stage 1): title, the pier, beach and edge of town on Gull Cay, tap-to-walk, fishing, selling at the market, the hold shown as fish shapes, the coin-pour upgrades (rod, bait, fish cart, rowboat) with refunds, day and night, autosave.

Not ported yet: the Stride walking rig and townsfolk, the rest of the island and its buildings and levels, raids and the shore battery, crew and the tavern, the chart, voyages and the ship cutaway, sea battles, boarding, the duel, making port, the other islands, the brig and frigate, lighthouse, treasure maps, the dog, the demo and View Parts.

- Bundle ID `com.brianward.broadside`, team `55NAZA6UKE`, iPhone only, landscape only.
- The Xcode project is generated from `project.yml` by XcodeGen, so there is no `.xcodeproj` in the repo.
- Build: the "Broadside Native iOS" workflow runs on every push that touches this folder. It compiles on a GitHub Mac and takes simulator screenshots; the result goes to the `broadside-native-buildlog` branch.
- TestFlight upload is switched off until the App Store Connect record exists. Add an empty file named `TESTFLIGHT` to this folder to switch it on.
