// #include <flutter/dart_project.h>
// #include <flutter/flutter_view_controller.h>
// #include <windows.h>

// #include "flutter_window.h"
// #include "utils.h"

// int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
//                       _In_ wchar_t *command_line, _In_ int show_command) {
//   // Attach to console when present (e.g., 'flutter run') or create a
//   // new console when running with a debugger.
//   if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
//     CreateAndAttachConsole();
//   }

//   // Initialize COM, so that it is available for use in the library and/or
//   // plugins.
//   ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

//   flutter::DartProject project(L"data");

//   std::vector<std::string> command_line_arguments =
//       GetCommandLineArguments();

//   project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

//   FlutterWindow window(project);
//   Win32Window::Point origin(10, 10);
//   Win32Window::Size size(1280, 720);
//   if (!window.Create(L"printer_agent", origin, size)) {
//     return EXIT_FAILURE;
//   }
//   window.SetQuitOnClose(true);

//   ::MSG msg;
//   while (::GetMessage(&msg, nullptr, 0, 0)) {
//     ::TranslateMessage(&msg);
//     ::DispatchMessage(&msg);
//   }

//   ::CoUninitialize();
//   return EXIT_SUCCESS;
// }

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

// ============================================================
// Single Instance Protection
// ============================================================

HANDLE g_single_instance_mutex = nullptr;

bool IsAnotherInstanceRunning() {
  const wchar_t* mutex_name =
      L"Local\\MyGenie_PrinterAgent_SingleInstance";

  g_single_instance_mutex = CreateMutexW(
      nullptr,
      TRUE,
      mutex_name);

  // If mutex creation failed, fail safely and don't start
  // another Printer Agent instance.
  if (g_single_instance_mutex == nullptr) {
    return true;
  }

  // Another Printer Agent instance already owns the mutex.
  if (GetLastError() == ERROR_ALREADY_EXISTS) {
    CloseHandle(g_single_instance_mutex);
    g_single_instance_mutex = nullptr;
    return true;
  }

  // This is the first Printer Agent instance.
  // Keep the mutex handle open for the lifetime of the process.
  return false;
}

// ============================================================
// Application Entry Point
// ============================================================

int APIENTRY wWinMain(_In_ HINSTANCE instance,
                      _In_opt_ HINSTANCE prev,
                      _In_ wchar_t* command_line,
                      _In_ int show_command) {

  // ----------------------------------------------------------
  // Prevent multiple Printer Agent instances
  // ----------------------------------------------------------

  if (IsAnotherInstanceRunning()) {
    return 0;
  }

  // ----------------------------------------------------------
  // Existing Flutter console handling
  // ----------------------------------------------------------

  // Attach to console when present (e.g., 'flutter run') or
  // create a new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) &&
      ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // ----------------------------------------------------------
  // Initialize COM
  // ----------------------------------------------------------

  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  // ----------------------------------------------------------
  // Flutter project
  // ----------------------------------------------------------

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(
      std::move(command_line_arguments));

  // ----------------------------------------------------------
  // Create Flutter window
  // ----------------------------------------------------------

  FlutterWindow window(project);

  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);

  if (!window.Create(L"printer_agent", origin, size)) {
    ::CoUninitialize();
    return EXIT_FAILURE;
  }

  window.SetQuitOnClose(true);

  // ----------------------------------------------------------
  // Windows message loop
  // ----------------------------------------------------------

  ::MSG msg;

  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  // ----------------------------------------------------------
  // Cleanup
  // ----------------------------------------------------------

  ::CoUninitialize();

  return EXIT_SUCCESS;
}