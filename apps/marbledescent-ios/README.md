# Marble Descent — iOS app

A Capacitor wrapper around `marble-descent/index.html`. The game itself is not edited here.

- Bundle ID `com.brianward.marbledescent`, team `55NAZA6UKE`, iPhone only, portrait only.
- Build: Actions → "Marble Descent iOS" → Run workflow. It builds on a GitHub Mac, signs with Apple's cloud signing and uploads to TestFlight.
- The Xcode project is not kept here. Each build copies the Dustfall III project (`apps/dustfall3-ios/ios`) and renames it: bundle ID, display name, portrait lock, `icon.png` and `splash.png`.
- Uses the same three repository secrets as Dustfall III: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`.
- The build number is the workflow run number. The version is set by `MARKETING_VERSION` in the workflow.
