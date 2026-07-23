//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <flutter_thermal_printer/flutter_thermal_printer_plugin_c_api.h>
#include <flutter_thermal_printer_windows/flutter_thermal_printer_windows_plugin_c_api.h>
#include <permission_handler_windows/permission_handler_windows_plugin.h>
#include <printing/printing_plugin.h>
#include <system_tray/system_tray_plugin.h>
#include <thermal_printer_plus/thermal_printer_plugin.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  FlutterThermalPrinterPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterThermalPrinterPluginCApi"));
  FlutterThermalPrinterWindowsPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterThermalPrinterWindowsPluginCApi"));
  PermissionHandlerWindowsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("PermissionHandlerWindowsPlugin"));
  PrintingPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("PrintingPlugin"));
  SystemTrayPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("SystemTrayPlugin"));
  ThermalPrinterPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("ThermalPrinterPlugin"));
}
