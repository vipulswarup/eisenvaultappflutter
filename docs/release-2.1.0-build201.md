# Release 2.1.0 (build 201) checklist

Version bumped from 2.0.0+200 in: `pubspec.yaml`, `msix_config.yaml` and the
`msix_config` block in `pubspec.yaml` (Store version 2.1.201.0), Android
`build.gradle.kts` (versionCode 201, versionName 2.1.0), iOS and macOS Info.plists
and Xcode projects (including the share/context-menu extensions), and the Windows
`Runner.rc` fallbacks.

New in this release: desktop upload (files, folders, drag and drop) and desktop
scanning (`packages/ev_scanner`, see `desktop-uploads.md`).

## Built and checked here
- Android: `release-artifacts/2.1.0+201/EisenVault-2.1.0-build201-playstore.aab`
  (SHA-256 df6c84de9406cead2cd2ad0ab5bb7fa4e43078acf64bc61ea0190f6b6e1e3711),
  signed with the same upload certificate as build 200 (SHA-256 11:CD:CF:02:...:26:82).
- macOS: `flutter build macos --release` succeeds; version 2.1.0 (201); sandbox with
  USB scanner entitlement; local-network usage text and Bonjour services added for
  network scanners.
- iOS: `flutter build ios --release --no-codesign` succeeds.
- `flutter test` passes.

## Still to do
- **iOS / macOS App Store:** this Mac only has an "Apple Development" identity, so
  the builds are unsigned for distribution. Archive in Xcode (or `flutter build ipa`)
  with a distribution certificate and profile, then upload to App Store Connect.
- **macOS keychain group:** `macos/Runner/*.entitlements` lists
  `$(AppIdentifierPrefix)com.example.eisenvaultappflutter` but the bundle id is
  `com.eisenvault.eisenvaultappflutter`. Check this against the provisioning profile
  before uploading. It was not changed because it would orphan keychain items of
  users already on a build.
- **Windows Store:** build the x64 MSIX on an x64 Windows machine
  (`dart run msix:create`); the ARM64 VM here would produce an ARM64 package and
  does not bundle the x64-only `TWAINDSM.dll` (it falls back to WIA). Confirm the
  scanner works from the packaged app, and run the Windows App Certification Kit.
- Account-side checks: Play Console must not have used versionCode 201; App Store
  Connect build 201 for 2.1.0; Partner Center submission.
- Scanner hardware not yet tried: USB, feeder/duplex (the HP tested is flatbed only).
- Store descriptions: Microsoft Store text mentions scanning; App Store / Play Store
  descriptions are mobile-focused and unchanged.
