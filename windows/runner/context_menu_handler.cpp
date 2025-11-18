#include <windows.h>
#include <shlobj.h>
#include <string>
#include <vector>
#include <sstream>

// Registry key for context menu
const wchar_t* REGISTRY_KEY = L"Software\\Classes\\*\\shell\\EisenVaultUpload";
const wchar_t* REGISTRY_COMMAND_KEY = L"Software\\Classes\\*\\shell\\EisenVaultUpload\\command";
const wchar_t* REGISTRY_FOLDER_KEY = L"Software\\Classes\\Directory\\shell\\EisenVaultUpload";
const wchar_t* REGISTRY_FOLDER_COMMAND_KEY = L"Software\\Classes\\Directory\\shell\\EisenVaultUpload\\command";

// Function to get the application executable path
std::wstring GetApplicationPath() {
    wchar_t path[MAX_PATH];
    GetModuleFileNameW(NULL, path, MAX_PATH);
    return std::wstring(path);
}

// Function to escape file paths for URL
std::wstring EscapeFilePath(const std::wstring& filePath) {
    std::wstring escaped;
    for (wchar_t c : filePath) {
        if (c == L'\\') {
            escaped += L"/";
        } else if (c == L' ') {
            escaped += L"%20";
        } else if (c == L'&') {
            escaped += L"%26";
        } else if (c == L'?') {
            escaped += L"%3F";
        } else if (c == L'#') {
            escaped += L"%23";
        } else {
            escaped += c;
        }
    }
    return escaped;
}

// Function to register context menu
bool RegisterContextMenu() {
    HKEY hKey;
    LONG result;
    
    // Get application path
    std::wstring appPath = GetApplicationPath();
    std::wstring command = L"\"" + appPath + L"\" \"eisenvault://upload?files=%1\"";
    
    // Register for files
    result = RegCreateKeyExW(HKEY_CURRENT_USER, REGISTRY_KEY, 0, NULL, 
                            REG_OPTION_NON_VOLATILE, KEY_WRITE, NULL, &hKey, NULL);
    if (result == ERROR_SUCCESS) {
        RegSetValueExW(hKey, NULL, 0, REG_SZ, 
                      (const BYTE*)L"Upload to EisenVault", 
                      static_cast<DWORD>((wcslen(L"Upload to EisenVault") + 1) * sizeof(wchar_t)));
        RegCloseKey(hKey);
        
        // Set command
        result = RegCreateKeyExW(HKEY_CURRENT_USER, REGISTRY_COMMAND_KEY, 0, NULL, 
                                REG_OPTION_NON_VOLATILE, KEY_WRITE, NULL, &hKey, NULL);
        if (result == ERROR_SUCCESS) {
            RegSetValueExW(hKey, NULL, 0, REG_SZ, 
                          (const BYTE*)command.c_str(), 
                          static_cast<DWORD>((command.length() + 1) * sizeof(wchar_t)));
            RegCloseKey(hKey);
        }
    }
    
    // Register for folders
    result = RegCreateKeyExW(HKEY_CURRENT_USER, REGISTRY_FOLDER_KEY, 0, NULL, 
                            REG_OPTION_NON_VOLATILE, KEY_WRITE, NULL, &hKey, NULL);
    if (result == ERROR_SUCCESS) {
        RegSetValueExW(hKey, NULL, 0, REG_SZ, 
                      (const BYTE*)L"Upload to EisenVault", 
                      static_cast<DWORD>((wcslen(L"Upload to EisenVault") + 1) * sizeof(wchar_t)));
        RegCloseKey(hKey);
        
        // Set command
        result = RegCreateKeyExW(HKEY_CURRENT_USER, REGISTRY_FOLDER_COMMAND_KEY, 0, NULL, 
                                REG_OPTION_NON_VOLATILE, KEY_WRITE, NULL, &hKey, NULL);
        if (result == ERROR_SUCCESS) {
            RegSetValueExW(hKey, NULL, 0, REG_SZ, 
                          (const BYTE*)command.c_str(), 
                          static_cast<DWORD>((command.length() + 1) * sizeof(wchar_t)));
            RegCloseKey(hKey);
        }
    }
    
    return result == ERROR_SUCCESS;
}

// Function to unregister context menu
bool UnregisterContextMenu() {
    LONG result1 = RegDeleteTreeW(HKEY_CURRENT_USER, REGISTRY_KEY);
    LONG result2 = RegDeleteTreeW(HKEY_CURRENT_USER, REGISTRY_FOLDER_KEY);
    return (result1 == ERROR_SUCCESS || result1 == ERROR_FILE_NOT_FOUND) &&
           (result2 == ERROR_SUCCESS || result2 == ERROR_FILE_NOT_FOUND);
}

// Function to check if context menu is registered
bool IsContextMenuRegistered() {
    HKEY hKey;
    LONG result = RegOpenKeyExW(HKEY_CURRENT_USER, REGISTRY_KEY, 0, KEY_READ, &hKey);
    if (result == ERROR_SUCCESS) {
        RegCloseKey(hKey);
        return true;
    }
    return false;
}

// Export functions for use by Flutter
extern "C" {
    __declspec(dllexport) bool RegisterContextMenuHandler() {
        return RegisterContextMenu();
    }
    
    __declspec(dllexport) bool UnregisterContextMenuHandler() {
        return UnregisterContextMenu();
    }
    
    __declspec(dllexport) bool IsContextMenuHandlerRegistered() {
        return IsContextMenuRegistered();
    }
}
