# Far Horizon — native iOS

A Swift rewrite of `far-horizon/index.html`. No web view: the rules are in `Sources/Game.swift` and `Sources/Events.swift`, and every shape is drawn with CoreGraphics.

Ported so far: title, choosing a ship, stocking the hold, the sea chart, sailing with supplies, wages, spoilage, sickness and wounds, the sea events as choices, ports (market, tavern, shipwright, well), and the sword fight, which is deeper here than on the web (high and low parries, heavy blows to dodge, ripostes, wind, the rail).

Not ported yet: the other mini-games (steering, fishing, treasure island, kraken, cannon battle, wreck dive, whale hunt, man overboard, leaks, rowing), walking the port towns, the crew-posts view (posts are filled automatically), trade goods, quests, ship upgrades, saving, and the demo.

- Bundle ID `com.brianward.farhorizon`, team `55NAZA6UKE`, iPhone only, landscape only.
- The Xcode project is generated from `project.yml` by XcodeGen, so there is no `.xcodeproj` in the repo.
- Build: the "Far Horizon Native iOS" workflow runs on every push that touches this folder. It compiles on a GitHub Mac and takes simulator screenshots; the result goes to the `farhorizon-native-buildlog` branch.
- TestFlight upload is switched off until the App Store Connect record exists. Add an empty file named `TESTFLIGHT` to this folder to switch it on.
