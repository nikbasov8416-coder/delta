#include "flutter_window.h"

#include <optional>
#include <shobjidl.h>
#include <wrl/client.h>

#include "flutter/standard_method_codec.h"
#include "utils.h"

#include "flutter/generated_plugin_registrant.h"

namespace {
using flutter::EncodableMap;
using flutter::EncodableValue;
using Microsoft::WRL::ComPtr;

std::string StringField(const EncodableMap& args, const char* key) {
  const auto value = args.find(EncodableValue(key));
  if (value == args.end()) {
    return {};
  }
  const auto* text = std::get_if<std::string>(&value->second);
  return text == nullptr ? std::string() : *text;
}

void SelectFile(HWND owner, const flutter::MethodCall<EncodableValue>& call,
                flutter::MethodResult<EncodableValue>& result) {
  const bool save = call.method_name() == "save";
  const auto* args = call.arguments() == nullptr
                         ? nullptr
                         : std::get_if<EncodableMap>(call.arguments());
  const auto name = args == nullptr ? std::string() : StringField(*args, "name");
  const auto extension = save && args != nullptr
                             ? StringField(*args, "extension")
                             : "delta";
  if (save && (name.empty() || (extension != "delta" && extension != "xlsx"))) {
    result.Error("arguments");
    return;
  }
  ComPtr<IFileDialog> dialog;
  HRESULT status = CoCreateInstance(save ? CLSID_FileSaveDialog : CLSID_FileOpenDialog,
                                    nullptr, CLSCTX_INPROC_SERVER,
                                    IID_PPV_ARGS(dialog.GetAddressOf()));
  if (SUCCEEDED(status)) {
    DWORD flags = 0;
    dialog->GetOptions(&flags);
    dialog->SetOptions(flags | FOS_FORCEFILESYSTEM |
                       (save ? FOS_OVERWRITEPROMPT : FOS_FILEMUSTEXIST));
    const bool excel = extension == "xlsx";
    const COMDLG_FILTERSPEC filter = {
        excel ? L"Excel (*.xlsx)" : L"Delta (*.delta)",
        excel ? L"*.xlsx" : L"*.delta"};
    dialog->SetFileTypes(1, &filter);
    if (save) {
      dialog->SetDefaultExtension(excel ? L"xlsx" : L"delta");
      const std::wstring wide_name(name.begin(), name.end());
      dialog->SetFileName(wide_name.c_str());
    }
    status = dialog->Show(owner);
  }
  if (status == HRESULT_FROM_WIN32(ERROR_CANCELLED)) {
    result.Success();
    return;
  }
  if (SUCCEEDED(status)) {
    ComPtr<IShellItem> selected;
    status = dialog->GetResult(selected.GetAddressOf());
    if (SUCCEEDED(status)) {
      PWSTR path = nullptr;
      status = selected->GetDisplayName(SIGDN_FILESYSPATH, &path);
      if (SUCCEEDED(status)) {
        const auto utf8 = Utf8FromUtf16(path);
        CoTaskMemFree(path);
        if (!utf8.empty()) {
          result.Success(EncodableValue(utf8));
          return;
        }
      }
    }
  }
  result.Error("document");
}
}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  file_channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      flutter_controller_->engine()->messenger(), "delta/files",
      &flutter::StandardMethodCodec::GetInstance());
  file_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        if (call.method_name() == "version") {
          const std::string version = FLUTTER_VERSION;
          result->Success(EncodableValue(EncodableMap{
              {EncodableValue("version"), EncodableValue(version.substr(0, version.find('+')))},
              {EncodableValue("build"), EncodableValue(std::to_string(FLUTTER_VERSION_BUILD))},
          }));
        } else if (call.method_name() == "save" || call.method_name() == "open") {
          SelectFile(GetHandle(), call, *result);
        } else {
          result->NotImplemented();
        }
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  file_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
