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
  
  // Add this method to set the initial window size
  override func applicationDidFinishLaunching(_ notification: Notification) {
    if let window = NSApplication.shared.windows.first {
      window.setContentSize(NSSize(width: 1000, height: 800))
      window.center()
    }
    super.applicationDidFinishLaunching(notification)
  }
}
