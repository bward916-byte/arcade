# Dustfall III — native iOS

A Swift rewrite of `dustfall-3/index.html`, built alongside the web-wrapped app in `apps/dustfall3-ios`. No web view: the rules are in `Sources/Game.swift` and every shape is drawn with CoreGraphics in `Sources/Draw.swift`.

**Stage 1 (this build): the first town.** Ride, toss coins, hire drifters, rebuild the store, saloon, sheriff's office, stable and bank, raise the two gates, make deputies and prospectors, collect the morning payout, and hold off the night raids with the six-shooter. Strongboxes, coin refunds, one building under construction at a time, and the web game's costs, payouts, day length and raid sizes are carried over.

Not ported yet: saving, the other four towns and the train, the territory map, weather, the story cutscenes, the duel, the bank's and stable's own jobs, the west-side sites (ghost town, trading post, oil derrick), wild horses and cattle, the stagecoach, and most of the scenery and effects.

- Same bundle ID as the web-wrapped app (`com.brianward.dustfall3`, team `55NAZA6UKE`), so a finished native build can replace it in the same App Store record. Until then it uploads as **version 1.1** with build numbers from 101, so it sits in its own TestFlight group and cannot be confused with the 1.0 builds in review.
- The Xcode project is generated from `project.yml` by XcodeGen, so there is no `.xcodeproj` in the repo.
- Build: the "Dustfall III Native iOS" workflow runs on every push to this branch that touches this folder. It compiles on a GitHub Mac, takes simulator screenshots, uploads to TestFlight, and writes the result to the `dustfall3-native-buildlog` branch.
