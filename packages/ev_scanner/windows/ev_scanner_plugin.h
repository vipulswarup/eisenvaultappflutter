#ifndef FLUTTER_PLUGIN_EV_SCANNER_PLUGIN_H_
#define FLUTTER_PLUGIN_EV_SCANNER_PLUGIN_H_

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/method_result.h>
#include <flutter/standard_method_codec.h>
#include <flutter/plugin_registrar_windows.h>

#include <atomic>
#include <functional>
#include <memory>

namespace ev_scanner {

class EvScannerPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  explicit EvScannerPlugin(flutter::PluginRegistrarWindows* registrar);
  ~EvScannerPlugin() override;

  EvScannerPlugin(const EvScannerPlugin&) = delete;
  EvScannerPlugin& operator=(const EvScannerPlugin&) = delete;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  // Runs [fn] on the platform thread (the thread Flutter calls us on).
  void PostToPlatform(std::function<void()> fn);

  flutter::PluginRegistrarWindows* registrar_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  int delegate_id_ = -1;
  std::shared_ptr<std::atomic<bool>> alive_;
  std::atomic<bool> busy_{false};
};

}  // namespace ev_scanner

#endif  // FLUTTER_PLUGIN_EV_SCANNER_PLUGIN_H_
