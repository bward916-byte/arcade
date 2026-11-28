# Havasu Campfire for iPhone

The sister app of Quartzsite Campfire, for winter visitors around Lake Havasu City. Same Swift code as `apps/campfire-ios`, with Havasu content.

- First edition: Guide, Shows and Map, all from the guide packed in `Resources/guide.json`. Nothing is fetched.
- For Sale, Alerts, Questions, Photos, "Am I on BLM land?" and map layers are in the code but switched off by `Site.live` in `Sources/Site.swift`, because Havasu has no server and no land-boundary file yet.
- The "Havasu iOS" workflow builds it on a GitHub Mac. The result (compile errors, upload outcome, screenshots) is pushed to the `havasu-ios-buildlog` branch.
- Bundle ID `com.brianward.havasucampfire`. The TestFlight upload needs an App Store Connect record for it.
