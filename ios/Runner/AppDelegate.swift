import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let uploadChannel = FlutterMethodChannel(
      name: "uploadChannel",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )

    uploadChannel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "getUploadData":
        result(self.getUploadDataFromAppGroups())
      case "saveDMSCredentials":
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

    if let baseUrl = args["baseUrl"] as? String {
      userDefaults.set(baseUrl, forKey: "DMSBaseUrl")
      print("🔍 DEBUG: Saved DMSBaseUrl: \(baseUrl)")
    }
    if let authToken = args["authToken"] as? String {
      userDefaults.set(authToken, forKey: "DMSAuthToken")
      print("🔍 DEBUG: Saved DMSAuthToken: Present (\(authToken.count) chars)")
    }
    if let instanceType = args["instanceType"] as? String {
      userDefaults.set(instanceType, forKey: "DMSInstanceType")
      print("🔍 DEBUG: Saved DMSInstanceType: \(instanceType)")
    }
    if let customerHostname = args["customerHostname"] as? String {
      userDefaults.set(customerHostname, forKey: "DMSCustomerHostname")
      print("🔍 DEBUG: Saved DMSCustomerHostname: \(customerHostname)")
    }

    userDefaults.synchronize()

    let savedBaseUrl = userDefaults.string(forKey: "DMSBaseUrl")
    let savedAuthToken = userDefaults.string(forKey: "DMSAuthToken")
    let savedInstanceType = userDefaults.string(forKey: "DMSInstanceType")
    let savedCustomerHostname = userDefaults.string(forKey: "DMSCustomerHostname")

    print("🔍 DEBUG: Verification - DMSBaseUrl: \(savedBaseUrl ?? "nil")")
    print("🔍 DEBUG: Verification - DMSAuthToken: \(savedAuthToken != nil ? "Present (\(savedAuthToken!.count) chars)" : "nil")")
    print("🔍 DEBUG: Verification - DMSInstanceType: \(savedInstanceType ?? "nil")")
    print("🔍 DEBUG: Verification - DMSCustomerHostname: \(savedCustomerHostname ?? "nil")")
    print("🔍 DEBUG: DMS credentials saved to App Groups successfully")
  }
}
