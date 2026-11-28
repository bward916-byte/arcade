# TrailApp for iPhone (working title)

An offline-minded land map: USGS topo and satellite base maps, a public-land layer from BLM's Surface Management Agency
data, track recording and waypoints.

- Built the same way as the other native apps here: XcodeGen makes the project from `project.yml`, the "Trail iOS"
  workflow compiles it on a GitHub Mac and uploads to TestFlight, and the result lands on the `trail-ios-buildlog` branch.
- The map engine is MapLibre (Swift package). The map style is `Resources/style.json`.
- Tracks and waypoints are stored on the phone only.

Not in yet: downloading an area for offline use, parcel boundaries, email sign-in and sync.
