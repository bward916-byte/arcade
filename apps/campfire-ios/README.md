# Quartzsite Campfire for iPhone (native trial)

A native Swift app that reads the ads from the live site. This trial has the For Sale list and the ad screen.

- No Mac needed. The "Campfire iOS" workflow builds it on a GitHub Mac and uploads it to TestFlight.
- The Xcode project is generated from `project.yml` by XcodeGen, so there is no `.xcodeproj` in the repo.
- The build result (compile errors, upload outcome, screenshots) is pushed to the `campfire-ios-buildlog` branch.

It lives on the `campfire-ios` branch of the arcade repo because the signing secrets (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`) are already here. The website itself is in the quartzsite-campfire repo.

The App Store Connect record "Quartzsite Campfire" was created on Nov 21, 2026.
