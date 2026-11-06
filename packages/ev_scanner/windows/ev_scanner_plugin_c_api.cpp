#include "include/ev_scanner/ev_scanner_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "ev_scanner_plugin.h"

void EvScannerPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  ev_scanner::EvScannerPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
