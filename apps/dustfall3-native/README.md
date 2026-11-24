# Dustfall III — native iOS

A Swift rewrite of `dustfall-3/index.html`, built alongside the web-wrapped app in `apps/dustfall3-ios`. No web view: the rules are in `Sources/Game.swift` and every shape is drawn with CoreGraphics in `Sources/Draw.swift`.

**Stage 1: the first town.** Ride, toss coins, hire drifters, rebuild the store, saloon and sheriff's office, raise the two gates, make deputies and prospectors, collect the morning payout, and hold off the night raids with the six-shooter. Strongboxes, coin refunds, one building under construction at a time, and the web game's costs, payouts, day length and raid sizes are carried over.

**Stage 2 (this build): the railroad.** Rebuild the station and the rails are laid from the east; the train rolls in and waits. A ticket paid at the passenger car takes you to the next town down the line (Dustfall, Redwater, Last Hope, Cold Creek, Bitter End) with half of purse and bank, never under 8 nor over 25. Prices rise a quarter per town and raids start a night harder. The stable (a faster horse) and the bank (deposits raiders cannot touch, a little interest each dawn) open from the second town on, as in the web game. The game saves itself at every dawn, when something is built, and whenever the app is left; the title screen offers Continue. Controls: a coin button and a gun button, both repeating while held.

Simplified against the web game for now: the line runs straight (no forks, no map), every town uses the desert look, the bank has one level, and reloading follows the web rule (5 seconds, a second off per store level).

Not ported yet: the territory map and forks, each town's own country and weather, the story cutscenes, the duel, ranchers and cattle, the later buildings (town centre, bordello, doctor, church, blacksmith, telegraph, barbed wire, claim, stagecoach), the west-side sites, wild horses, and most of the scenery and effects.

- Same bundle ID as the web-wrapped app (`com.brianward.dustfall3`, team `55NAZA6UKE`), so a finished native build can replace it in the same App Store record. Until then it uploads as **version 1.1** with build numbers from 101, so it sits in its own TestFlight group and cannot be confused with the 1.0 builds in review.
- The Xcode project is generated from `project.yml` by XcodeGen, so there is no `.xcodeproj` in the repo.
- Build: the "Dustfall III Native iOS" workflow runs on every push to this branch that touches this folder. It compiles on a GitHub Mac, takes simulator screenshots, uploads to TestFlight, and writes the result to the `dustfall3-native-buildlog` branch.
