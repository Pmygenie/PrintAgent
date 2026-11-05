#include "utils.h"

#include <flutter_windows.h>
#include <io.h>
#include <stdio.h>
#include <windows.h>

#include <iostream>
#include <string>

namespace {

constexpr DWORD kMaxStartupLogBytes = 512 * 1024;

std::wstring StartupLogPath() {
  wchar_t local_app_data[MAX_PATH] = {};
  const DWORD n = GetEnvironmentVariableW(L"LOCALAPPDATA", local_app_data,
                                          MAX_PATH);
  if (n == 0 || n >= MAX_PATH) {
    return std::wstring();
  }
  return std::wstring(local_app_data) + L"\\PrinterAgent\\startup.log";
}

void EnsureStartupLogDir(const std::wstring& log_path) {
  const auto slash = log_path.find_last_of(L"\\/");
  if (slash == std::wstring::npos) {
    return;
  }
  const std::wstring dir = log_path.substr(0, slash);
  CreateDirectoryW(dir.c_str(), nullptr);
}

}  // namespace

void StartupLog(const std::string& message) {
  const std::wstring path = StartupLogPath();
  if (path.empty()) {
    return;
  }
  EnsureStartupLogDir(path);

  WIN32_FILE_ATTRIBUTE_DATA info{};
  if (GetFileAttributesExW(path.c_str(), GetFileExInfoStandard, &info)) {
    ULARGE_INTEGER size;
    size.LowPart = info.nFileSizeLow;
    size.HighPart = info.nFileSizeHigh;
    if (size.QuadPart > kMaxStartupLogBytes) {
      DeleteFileW(path.c_str());
    }
  }

  HANDLE file = CreateFileW(path.c_str(), FILE_APPEND_DATA,
                            FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr,
                            OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (file == INVALID_HANDLE_VALUE) {
    return;
  }

  SYSTEMTIME st{};
  GetLocalTime(&st);
  char line[1024];
  const int n = snprintf(
      line, sizeof(line),
      "%04d-%02d-%02d %02d:%02d:%02d.%03d pid=%lu %s\n",
      st.wYear, st.wMonth, st.wDay, st.wHour, st.wMinute, st.wSecond,
      st.wMilliseconds, GetCurrentProcessId(), message.c_str());
  if (n > 0) {
    DWORD written = 0;
    WriteFile(file, line, static_cast<DWORD>(n), &written, nullptr);
  }
  CloseHandle(file);
}

void CreateAndAttachConsole() {
  if (::AllocConsole()) {
    FILE *unused;
    if (freopen_s(&unused, "CONOUT$", "w", stdout)) {
      _dup2(_fileno(stdout), 1);
    }
    if (freopen_s(&unused, "CONOUT$", "w", stderr)) {
      _dup2(_fileno(stdout), 2);
    }
    std::ios::sync_with_stdio();
    FlutterDesktopResyncOutputStreams();
  }
}

std::vector<std::string> GetCommandLineArguments() {
  // Convert the UTF-16 command line arguments to UTF-8 for the Engine to use.
  int argc;
  wchar_t** argv = ::CommandLineToArgvW(::GetCommandLineW(), &argc);
  if (argv == nullptr) {
    return std::vector<std::string>();
  }

  std::vector<std::string> command_line_arguments;

  // Skip the first argument as it's the binary name.
  for (int i = 1; i < argc; i++) {
    command_line_arguments.push_back(Utf8FromUtf16(argv[i]));
  }

  ::LocalFree(argv);

  return command_line_arguments;
}

std::string Utf8FromUtf16(const wchar_t* utf16_string) {
  if (utf16_string == nullptr) {
    return std::string();
  }
  unsigned int target_length = ::WideCharToMultiByte(
      CP_UTF8, WC_ERR_INVALID_CHARS, utf16_string,
      -1, nullptr, 0, nullptr, nullptr)
    -1; // remove the trailing null character
  int input_length = (int)wcslen(utf16_string);
  std::string utf8_string;
  if (target_length == 0 || target_length > utf8_string.max_size()) {
    return utf8_string;
  }
  utf8_string.resize(target_length);
  int converted_length = ::WideCharToMultiByte(
      CP_UTF8, WC_ERR_INVALID_CHARS, utf16_string,
      input_length, utf8_string.data(), target_length, nullptr, nullptr);
  if (converted_length == 0) {
    return std::string();
  }
  return utf8_string;
}
