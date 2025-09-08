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
      case "saveDMSCredentials":
        // Save DMS credentials to App Groups for Share Extension
        if let args = call.arguments as? [String: Any] {
          self.saveDMSCredentialsToAppGroups(args: args)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
        }
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

  private func saveDMSCredentialsToAppGroups(args: [String: Any]) {
    print("🔍 DEBUG: Saving DMS credentials to App Groups...")

    guard let userDefaults = UserDefaults(suiteName: "group.com.eisenvault.eisenvaultappflutter") else {
      print("🔍 DEBUG: Failed to access App Groups UserDefaults")
      return
    }

    // Save DMS credentials
    if let baseUrl = args["baseUrl"] as? String {
      userDefaults.set(baseUrl, forKey: "DMSBaseUrl")
    }
    if let authToken = args["authToken"] as? String {
      userDefaults.set(authToken, forKey: "DMSAuthToken")
    }
    if let instanceType = args["instanceType"] as? String {
      userDefaults.set(instanceType, forKey: "DMSInstanceType")
    }
    if let customerHostname = args["customerHostname"] as? String {
      userDefaults.set(customerHostname, forKey: "DMSCustomerHostname")
    }

    userDefaults.synchronize()
    print("🔍 DEBUG: DMS credentials saved to App Groups successfully")
  }
}
