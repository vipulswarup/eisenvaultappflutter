# AGENTS.md

## Cursor Cloud specific instructions

This repo is `eisenvaultappflutter` (EisenVault Desktop), a Flutter client for the EisenVault DMS. It is a client only; there is no backend server in this repo. See `README.md` for the standard Flutter workflow.

### Toolchain (already provisioned in the environment)
- Flutter SDK is installed at `/opt/flutter` (stable channel, Flutter 3.47.0 / Dart 3.13.0) and symlinked into `/usr/local/bin`, so `flutter`/`dart` are on `PATH`. The lockfile requires Flutter `>=3.44.0` and Dart `>=3.12.0`, so the stale revision in `.metadata` (3.29.3) is too old and must not be used.
- The startup update script runs `flutter pub get`. A root `flutter pub get` also resolves the local path package `packages/microsoft_viewer`; no separate install is needed for the main app.

### Running the app
- The supported target on this Linux VM is the Linux desktop (GTK) build: `flutter run -d linux` (requires `DISPLAY=:1`, which is already set on the VM desktop). Lint/test/build/run were verified on this target.
- Do NOT use the web target for testing. The app imports `dart:io`/`Platform` and uses native `sqflite`, so `flutter run -d chrome` (or `-d web-server`) hangs on the startup spinner and never reaches the login screen.
- Full end-to-end features (login, browse, upload, search) require a reachable remote EisenVault (Angora) or Alfresco 5.2+ server plus credentials, entered on the login screen or via `lib/config/dev_credentials.dart` (copy from `lib/config/dev_credentials_template.dart`). Without a server, the login flow still runs and returns an "Authentication failed" error dialog, which is expected.

### Non-obvious gotchas
- If a Linux build fails during the CMake compiler-test/configure stage (for example a missing toolchain lib), the leftover CMake cache makes the next build try to install to `/usr/local/...` and fail with `Permission denied`. Run `flutter clean` (or `rm -rf build/linux`) before rebuilding.
- On Linux, `flutter_secure_storage` triggers a GNOME keyring prompt ("Choose password for new keyring") on first secure-storage access. During manual testing you can click Cancel; the app continues.

### Lint / test
- Lint: `flutter analyze`. It reports many `info`-level "missing documentation" lints inside `packages/microsoft_viewer`; these are pre-existing and non-fatal (exit code 0).
- Tests: `flutter test` (the suite under `test/` passes).
