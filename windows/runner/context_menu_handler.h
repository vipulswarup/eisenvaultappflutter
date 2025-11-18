#ifndef CONTEXT_MENU_HANDLER_H_
#define CONTEXT_MENU_HANDLER_H_

#include <windows.h>
#include <string>

// Export functions for use by Flutter
extern "C" {
    __declspec(dllexport) bool RegisterContextMenuHandler();
    __declspec(dllexport) bool UnregisterContextMenuHandler();
    __declspec(dllexport) bool IsContextMenuHandlerRegistered();
}

#endif  // CONTEXT_MENU_HANDLER_H_

