# Quartzsite Winter — native iOS prototype

Working title. A winter in the desert around Quartzsite, AZ: pick who you are (nomad or RVer), a first rig and a look, then walk the camp strip.

In the prototype: title cinematic, player selection, the hold-to-fill price ring (money comes back if you let go, walk off or run short), firewood, the pop-up grocery, KB Tools solar, the rock and mineral show, a Skooliepalooza oddities booth (the nomad gathering out west in Ehrenberg, not part of Quartzsite), your own sale table, the used-rig lot, tap-to-drive rigs, day and night, health and cred, saving.

No web view. Rules are in `Sources/Game.swift`; every shape is drawn with CoreGraphics in `Sources/Draw.swift`; words are drawn by `TextLayer` in `Sources/App.swift`.

- Bundle ID `com.brianward.quartzsitewinter`, team `55NAZA6UKE`, iPhone only, landscape only.
- The Xcode project is generated from `project.yml` by XcodeGen.
- Build: the "Quartzsite Winter iOS" workflow compiles on a GitHub Mac, takes simulator screenshots and uploads to TestFlight. It uses the same three secrets as the other apps.
- TestFlight needs the bundle ID registered and an app record in App Store Connect before the upload step can succeed.
