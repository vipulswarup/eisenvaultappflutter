#include "ev_scanner_plugin.h"

#include <windows.h>

#include <algorithm>
#include <cctype>
#include <map>
#include <thread>

#include "scan_core.h"

namespace ev_scanner {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;
using Result = flutter::MethodResult<EncodableValue>;

namespace {

constexpr UINT kRunOnPlatform = WM_APP + 0x4553;

std::wstring ExeDir() {
  wchar_t buf[MAX_PATH];
  DWORD n = GetModuleFileNameW(nullptr, buf, MAX_PATH);
  std::wstring p(buf, n);
  size_t slash = p.find_last_of(L"\\/");
  return slash == std::wstring::npos ? L"." : p.substr(0, slash);
}

template <typename T>
T Arg(const EncodableMap& m, const char* key, T fallback) {
  auto it = m.find(EncodableValue(key));
  if (it == m.end()) return fallback;
  if (auto* v = std::get_if<T>(&it->second)) return *v;
  return fallback;
}

evscan::ScanParams ParseParams(const EncodableMap& m) {
  evscan::ScanParams p;
  p.device_id = Arg<std::string>(m, "deviceId", "");
  p.source = Arg<std::string>(m, "source", "flatbed");
  p.color_mode = Arg<std::string>(m, "colorMode", "color");
  p.dpi = Arg<int>(m, "dpi", 300);
  p.width_mm = Arg<double>(m, "widthMm", 210);
  p.height_mm = Arg<double>(m, "heightMm", 297);
  p.output_dir = evscan::Wide(Arg<std::string>(m, "outputDir", ""));
  p.use_own_dialog = Arg<bool>(m, "useOwnDialog", false);
  return p;
}

std::string Lower(std::string s) {
  for (auto& c : s) c = (char)std::tolower((unsigned char)c);
  return s;
}

}  // namespace

void EvScannerPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto plugin = std::make_unique<EvScannerPlugin>(registrar);
  registrar->AddPlugin(std::move(plugin));
}

EvScannerPlugin::EvScannerPlugin(flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar), alive_(std::make_shared<std::atomic<bool>>(true)) {
  channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      registrar->messenger(), "ev_scanner/native",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    HandleMethodCall(call, std::move(result));
  });
  delegate_id_ = registrar->RegisterTopLevelWindowProcDelegate(
      [](HWND, UINT message, WPARAM, LPARAM lparam) -> std::optional<LRESULT> {
        if (message == kRunOnPlatform) {
          std::unique_ptr<std::function<void()>> fn(
              reinterpret_cast<std::function<void()>*>(lparam));
          (*fn)();
          return 0;
        }
        return std::nullopt;
      });
}

EvScannerPlugin::~EvScannerPlugin() {
  *alive_ = false;
  evscan::g_cancel = true;
  registrar_->UnregisterTopLevelWindowProcDelegate(delegate_id_);
}

void EvScannerPlugin::PostToPlatform(std::function<void()> fn) {
  HWND view = registrar_->GetView() ? registrar_->GetView()->GetNativeWindow()
                                    : nullptr;
  HWND top = view ? GetAncestor(view, GA_ROOT) : nullptr;
  auto* heap = new std::function<void()>(std::move(fn));
  if (!top || !PostMessageW(top, kRunOnPlatform, 0,
                            reinterpret_cast<LPARAM>(heap))) {
    delete heap;
  }
}

void EvScannerPlugin::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<Result> result) {
  const std::string& method = call.method_name();
  std::shared_ptr<Result> res(std::move(result));
  auto alive = alive_;

  if (method == "cancel") {
    evscan::g_cancel = true;
    res->Success();
    return;
  }

  if (method == "listDevices") {
    std::thread([this, res, alive]() {
      evscan::ScanError twain_err, wia_err;
      auto devices = evscan::TwainListDevices(ExeDir(), &twain_err);
      auto wia = evscan::WiaListDevices(&wia_err);
      // A device TWAIN already lists is not offered twice.
      for (auto& w : wia) {
        bool dup = std::any_of(devices.begin(), devices.end(), [&](auto& t) {
          return Lower(t.name) == Lower(w.name);
        });
        if (!dup) devices.push_back(w);
      }
      PostToPlatform([res, alive, devices]() {
        if (!*alive) return;
        EncodableList list;
        for (const auto& d : devices) {
          list.push_back(EncodableValue(EncodableMap{
              {EncodableValue("id"), EncodableValue(d.id)},
              {EncodableValue("name"), EncodableValue(d.name)},
              {EncodableValue("hasFeeder"), EncodableValue(d.has_feeder)},
              {EncodableValue("hasDuplex"), EncodableValue(d.has_duplex)},
          }));
        }
        res->Success(EncodableValue(list));
      });
    }).detach();
    return;
  }

  if (method == "scan") {
    const auto* args = std::get_if<EncodableMap>(call.arguments());
    if (!args) {
      res->Error("failed", "Missing scan arguments.");
      return;
    }
    if (busy_.exchange(true)) {
      res->Error("deviceBusy", "A scan is already running.");
      return;
    }
    evscan::g_cancel = false;
    evscan::ScanParams params = ParseParams(*args);
    std::thread([this, res, alive, params]() {
      auto progress = [this, alive](int n) {
        PostToPlatform([this, alive, n]() {
          if (!*alive) return;
          channel_->InvokeMethod(
              "progress", std::make_unique<EncodableValue>(EncodableMap{
                              {EncodableValue("pagesScanned"), EncodableValue(n)}}));
        });
      };
      evscan::ScanOutcome out;
      if (params.device_id.rfind("wia:", 0) == 0) {
        out = evscan::WiaScan(params, progress);
      } else {
        out = evscan::TwainScan(ExeDir(), params, progress);
      }
      PostToPlatform([this, res, alive, out]() {
        if (!*alive) return;
        busy_ = false;
        if (out.ok) {
          EncodableList pages;
          for (const auto& p : out.pages) pages.push_back(EncodableValue(evscan::Utf8(p)));
          res->Success(EncodableValue(EncodableMap{
              {EncodableValue("pages"), EncodableValue(pages)}}));
        } else {
          res->Error(out.error.code, out.error.message);
        }
      });
    }).detach();
    return;
  }

  res->NotImplemented();
}

}  // namespace ev_scanner
