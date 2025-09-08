import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Set up method channel for upload handling
    let controller = window?.rootViewController as! FlutterViewController
    let uploadChannel = FlutterMethodChannel(
      name: "uploadChannel",
      binaryMessenger: controller.binaryMessenger
    )

    uploadChannel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "getUploadData":
        // Return any upload data from Share Extension
        result(self.getUploadDataFromAppGroups())
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func getUploadDataFromAppGroups() -> [String: Any]? {
    print("🔍 DEBUG: Checking App Groups for upload data...")

    guard let userDefaults = UserDefaults(suiteName: "group.com.eisenvault.eisenvaultappflutter") else {
      print("🔍 DEBUG: Failed to access App Groups UserDefaults")
      return nil
    }

    let uploadData = userDefaults.object(forKey: "UploadData") as? [String: Any]
    print("🔍 DEBUG: Upload data found: \(String(describing: uploadData))")

    if uploadData != nil {
      print("🔍 DEBUG: Upload data found in App Groups")
      // Clear the data after reading
      userDefaults.removeObject(forKey: "UploadData")
      userDefaults.synchronize()
    } else {
      print("🔍 DEBUG: No upload data found in App Groups")
    }

    return uploadData
  }
}
