#ifndef EV_SCANNER_SCAN_CORE_H_
#define EV_SCANNER_SCAN_CORE_H_

#include <atomic>
#include <functional>
#include <string>
#include <vector>

// Windows scanning without any Flutter dependency: TWAIN 2 through the
// redistributable TWAIN DSM, with WIA 2.0 as the fallback. Device ids are
// "twain:<name>" or "wia:<id>".
namespace evscan {

struct DeviceInfo {
  std::string id;
  std::string name;
  bool has_feeder = false;
  bool has_duplex = false;
};

struct ScanParams {
  std::string device_id;
  std::string source;      // flatbed | adf | duplex
  std::string color_mode;  // color | grayscale | blackAndWhite
  int dpi = 300;
  double width_mm = 210;
  double height_mm = 297;
  std::wstring output_dir;
  bool use_own_dialog = false;
};

struct ScanError {
  std::string code;  // matches ScannerErrorKind names in Dart
  std::string message;
};

struct ScanOutcome {
  bool ok = false;
  std::vector<std::wstring> pages;
  ScanError error;
};

using ProgressFn = std::function<void(int pages_scanned)>;

extern std::atomic<bool> g_cancel;

// dsm_dir: folder containing TWAINDSM.dll (the app's directory).
std::vector<DeviceInfo> TwainListDevices(const std::wstring& dsm_dir,
                                         ScanError* error);
ScanOutcome TwainScan(const std::wstring& dsm_dir, const ScanParams& params,
                      const ProgressFn& progress);

std::vector<DeviceInfo> WiaListDevices(ScanError* error);
ScanOutcome WiaScan(const ScanParams& params, const ProgressFn& progress);

// Helpers shared by both back ends.
std::string Utf8(const std::wstring& w);
std::wstring Wide(const std::string& s);
// Saves a packed DIB (BITMAPINFOHEADER + pixels) as PNG. Returns false on error.
bool SaveDibAsPng(const void* dib, size_t dib_size, const std::wstring& path);

}  // namespace evscan

#endif  // EV_SCANNER_SCAN_CORE_H_
