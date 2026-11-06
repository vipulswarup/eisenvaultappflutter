import Cocoa
import FlutterMacOS
import ImageCaptureCore

/// Image Capture bridge. USB scanners and AirScan/eSCL network MFPs that
/// macOS knows about appear here; nothing else does.
public class EvScannerPlugin: NSObject, FlutterPlugin, ICDeviceBrowserDelegate, ICScannerDeviceDelegate {
  private var channel: FlutterMethodChannel!
  private let browser = ICDeviceBrowser()
  private var devices: [String: ICScannerDevice] = [:]

  // Active scan state.
  private var scanResult: FlutterResult?
  private var scanDevice: ICScannerDevice?
  private var pages: [String] = []
  private var request: [String: Any] = [:]
  private var cancelled = false
  private var pendingListResults: [FlutterResult] = []

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "ev_scanner/native", binaryMessenger: registrar.messenger)
    let instance = EvScannerPlugin()
    instance.channel = channel
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "listDevices": listDevices(result)
    case "scan": startScan(call.arguments as? [String: Any] ?? [:], result)
    case "cancel":
      cancelled = true
      scanDevice?.cancelScan()
      result(nil)
    default: result(FlutterMethodNotImplemented)
    }
  }

  // MARK: Discovery

  private func listDevices(_ result: @escaping FlutterResult) {
    if browser.delegate == nil {
      browser.delegate = self
      let mask = ICDeviceTypeMask.scanner.rawValue
        | ICDeviceLocationTypeMask.local.rawValue
        | ICDeviceLocationTypeMask.remote.rawValue
      browser.browsedDeviceTypeMask = ICDeviceTypeMask(rawValue: mask)!
    }
    if !browser.isBrowsing { browser.start() }
    // Browsing is asynchronous and network devices take a moment.
    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
      let list: [[String: Any]] = self.devices.map { (id, d) in
        ["id": id, "name": d.name ?? id, "hasFeeder": true, "hasDuplex": false]
      }.sorted { ($0["name"] as! String) < ($1["name"] as! String) }
      result(list)
    }
  }

  public func deviceBrowser(_ browser: ICDeviceBrowser, didAdd device: ICDevice, moreComing: Bool) {
    guard let scanner = device as? ICScannerDevice, let id = device.uuidString else { return }
    devices[id] = scanner
  }

  public func deviceBrowser(_ browser: ICDeviceBrowser, didRemove device: ICDevice, moreGoing: Bool) {
    if let id = device.uuidString { devices.removeValue(forKey: id) }
  }

  // MARK: Scanning

  private func fail(_ code: String, _ message: String) {
    let r = scanResult
    cleanup()
    r?(FlutterError(code: code, message: message, details: nil))
  }

  private func cleanup() {
    scanDevice?.requestCloseSession()
    scanDevice = nil
    scanResult = nil
  }

  private func startScan(_ args: [String: Any], _ result: @escaping FlutterResult) {
    guard scanResult == nil else {
      return result(FlutterError(code: "deviceBusy", message: "A scan is already running.", details: nil))
    }
    guard let id = args["deviceId"] as? String, let device = devices[id] else {
      return result(FlutterError(code: "driverMissing",
        message: "The scanner is no longer available. Refresh the list.", details: nil))
    }
    request = args
    pages = []
    cancelled = false
    scanResult = result
    scanDevice = device
    device.delegate = self
    if device.hasOpenSession { selectUnit(device) } else { device.requestOpenSession() }
  }

  public func device(_ device: ICDevice, didOpenSessionWithError error: Error?) {
    if let error = error { fail("deviceBusy", "The scanner could not be opened: \(error.localizedDescription)") }
  }

  public func didRemove(_ device: ICDevice) {
    if scanResult != nil { fail("failed", "The scanner was disconnected.") }
  }

  public func device(_ device: ICDevice, didCloseSessionWithError error: Error?) {}
  public func deviceDidBecomeReady(_ device: ICDevice) {
    if let d = device as? ICScannerDevice, scanResult != nil, d === scanDevice { selectUnit(d) }
  }

  private func selectUnit(_ device: ICScannerDevice) {
    let source = request["source"] as? String ?? "flatbed"
    let wanted: ICScannerFunctionalUnitType = source == "flatbed" ? .flatbed : .documentFeeder
    let available = device.availableFunctionalUnitTypes.map { $0.intValue }
    guard available.contains(Int(wanted.rawValue)) else {
      return fail("failed", "This scanner does not offer that source.")
    }
    if device.selectedFunctionalUnit.type == wanted { configureAndScan(device) }
    else { device.requestSelect(wanted) }
  }

  public func scannerDevice(_ scanner: ICScannerDevice, didSelect functionalUnit: ICScannerFunctionalUnit, error: Error?) {
    guard scanner === scanDevice, scanResult != nil else { return }
    if let error = error { return fail("failed", error.localizedDescription) }
    configureAndScan(scanner)
  }

  private func configureAndScan(_ scanner: ICScannerDevice) {
    let unit = scanner.selectedFunctionalUnit
    let source = request["source"] as? String ?? "flatbed"
    let dpi = request["dpi"] as? Int ?? 300
    let wMm = request["widthMm"] as? Double ?? 210
    let hMm = request["heightMm"] as? Double ?? 297
    if let feeder = unit as? ICScannerFunctionalUnitDocumentFeeder {
      if !feeder.documentLoaded {
        return fail("feederEmpty", "The document feeder is empty. Load paper and try again.")
      }
      feeder.duplexScanningEnabled = (source == "duplex") && feeder.supportsDuplexScanning
    }
    unit.measurementUnit = .inches
    // Pick the supported resolution closest to the request.
    let supported = unit.supportedResolutions
    if !supported.isEmpty {
      let best = supported.min { abs($0 - dpi) < abs($1 - dpi) }!
      unit.resolution = best
    }
    switch request["colorMode"] as? String ?? "color" {
    case "grayscale": unit.pixelDataType = .gray; unit.bitDepth = .depth8Bits
    case "blackAndWhite": unit.pixelDataType = .BW; unit.bitDepth = .depth1Bit
    default: unit.pixelDataType = .RGB; unit.bitDepth = .depth8Bits
    }
    unit.scanArea = NSRect(x: 0, y: 0, width: wMm / 25.4, height: hMm / 25.4)
    scanner.transferMode = .fileBased
    scanner.downloadsDirectory = URL(fileURLWithPath: request["outputDir"] as? String ?? NSTemporaryDirectory())
    scanner.documentName = "page"
    scanner.documentUTI = "public.png"
    scanner.requestScan()
  }

  public func scannerDevice(_ scanner: ICScannerDevice, didScanTo url: URL) {
    pages.append(url.path)
    channel.invokeMethod("progress", arguments: ["pagesScanned": pages.count])
  }

  public func scannerDevice(_ scanner: ICScannerDevice, didCompleteScanWithError error: Error?) {
    guard scanner === scanDevice, let result = scanResult else { return }
    if cancelled { return fail("cancelled", "Scan cancelled.") }
    if !pages.isEmpty || error == nil {
      let out = pages.sorted()
      cleanup()
      result(["pages": out])
      return
    }
    let text = error!.localizedDescription.lowercased()
    if text.contains("jam") { fail("paperJam", "Paper jam. Clear the jam and try again.") }
    else if text.contains("busy") { fail("deviceBusy", "The scanner is busy. Wait for it to finish, then try again.") }
    else { fail("failed", "The scan failed: \(error!.localizedDescription)") }
  }
}
