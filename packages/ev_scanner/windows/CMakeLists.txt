cmake_minimum_required(VERSION 3.14)
set(PROJECT_NAME "ev_scanner")
project(${PROJECT_NAME} LANGUAGES CXX)

set(PLUGIN_NAME "ev_scanner_plugin")

add_library(${PLUGIN_NAME} SHARED
  "ev_scanner_plugin_c_api.cpp"
  "ev_scanner_plugin.cpp"
  "scan_common.cpp"
  "twain_scan.cpp"
  "wia_scan.cpp"
)

apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_include_directories(${PLUGIN_NAME} PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin
  ole32 oleaut32 windowscodecs shlwapi wiaguid uuid)

# The free, royalty-free TWAIN Data Source Manager, installed beside the app.
# Only the 64-bit x64 build exists; ARM64 builds fall back to WIA.
if(NOT CMAKE_GENERATOR_PLATFORM STREQUAL "ARM64")
  set(ev_scanner_bundled_libraries
    "${CMAKE_CURRENT_SOURCE_DIR}/third_party/x64/TWAINDSM.dll"
    PARENT_SCOPE)
endif()
