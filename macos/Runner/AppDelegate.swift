import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
  
  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    
    // Set up method channel for context menu integration
    let controller = mainFlutterWindow?.contentViewController as! FlutterViewController
    let contextMenuChannel = FlutterMethodChannel(
      name: "contextMenuChannel",
      binaryMessenger: controller.engine.binaryMessenger
    )
    
    contextMenuChannel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "setContextMenuEnabled":
        if let enabled = call.arguments as? Bool {
          self.setContextMenuEnabled(enabled)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
        }
      case "isContextMenuEnabled":
        result(self.isContextMenuEnabled())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
  
  override func application(_ app: NSApplication, open urls: [URL]) {
    // Handle URL scheme for context menu uploads
    print("AppDelegate: Received URLs: \(urls)")
    for url in urls {
      print("AppDelegate: Processing URL: \(url)")
      if url.scheme == "eisenvault" && url.host == "upload" {
        print("AppDelegate: Handling context menu upload URL")
        handleContextMenuUpload(url: url)
      } else {
        print("AppDelegate: URL scheme/host mismatch - scheme: \(url.scheme ?? "nil"), host: \(url.host ?? "nil")")
      }
    }
  }
  
  private func handleContextMenuUpload(url: URL) {
    print("AppDelegate: handleContextMenuUpload called with URL: \(url)")
    
    // Extract file paths from URL
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
          let queryItems = components.queryItems,
          let filesItem = queryItems.first(where: { $0.name == "files" }),
          let filesString = filesItem.value else {
      print("AppDelegate: No files found in URL")
      return
    }
    
    print("AppDelegate: Files string: \(filesString)")
    
    let filePaths = filesString.components(separatedBy: ",")
    let decodedPaths = filePaths.compactMap { $0.removingPercentEncoding }
    
    print("AppDelegate: Decoded file paths: \(decodedPaths)")
    
    // Send file paths to Flutter app
    guard let controller = mainFlutterWindow?.contentViewController as? FlutterViewController else {
      print("AppDelegate: Could not get Flutter view controller")
      return
    }
    
    let contextMenuChannel = FlutterMethodChannel(
      name: "contextMenuChannel",
      binaryMessenger: controller.engine.binaryMessenger
    )
    
    print("AppDelegate: Sending file paths to Flutter: \(decodedPaths)")
    contextMenuChannel.invokeMethod("openContextMenuUpload", arguments: decodedPaths)
  }
  
  private func setContextMenuEnabled(_ enabled: Bool) {
    UserDefaults.standard.set(enabled, forKey: "EisenVaultContextMenuEnabled")
    UserDefaults.standard.synchronize()
  }
  
  private func isContextMenuEnabled() -> Bool {
    return UserDefaults.standard.bool(forKey: "EisenVaultContextMenuEnabled")
  }
}
