# Dustfall III — iOS app

A Capacitor wrapper around `dustfall-3/index.html`. The game itself is not edited here.

- Bundle ID `com.brianward.dustfall3`, team `55NAZA6UKE`, iPhone only, landscape only.
- Build: Actions → "Dustfall III iOS" → Run workflow. It builds on a GitHub Mac, signs with Apple's cloud signing and uploads to TestFlight.
- Needs three repository secrets: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` (an App Store Connect API key with the Admin role).
- The build number is the workflow run number. Change the version (1.0) in `ios/App/App.xcodeproj` when releasing an update.
