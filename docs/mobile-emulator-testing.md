# Automatic mobile emulator tests

The `Mobile emulator tests` GitHub Actions workflow runs on pull requests,
pushes to `main`, and manual dispatch. It runs the regular Flutter test suite
and analysis, then boots Android and iOS devices to run the same application
smoke test on each platform.

The device smoke test launches the real app, waits for bootstrap to reach the
sign-in screen, checks the expected fields, and verifies required-field errors.
It does not sign in or require server credentials. The existing opt-in Alfresco
integration tests remain separate because they create and remove server-side
test workflows and documents.

To run the device test locally after starting an emulator or simulator:

```sh
flutter test --no-pub integration_test/mobile_app_smoke_test.dart -d <device-id>
```

The local machine needs an installed Android SDK system image or Xcode iOS
Simulator runtime. Use `flutter devices` to find the device ID.
