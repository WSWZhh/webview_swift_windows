#include "WebViewBridge.hpp"
#include <cstdio>

namespace swift_webview {
WebViewOwner::WebViewOwner(bool debug) noexcept {
  try {
    view_ = std::make_unique<webview::webview>(debug, nullptr);
  } catch (const std::exception &error) {
    std::snprintf(error_message_, sizeof(error_message_), "%s", error.what());
  } catch (...) {
    std::snprintf(error_message_, sizeof(error_message_), "%s", "Unknown C++ exception");
  }
}

WebViewOwner::~WebViewOwner() noexcept = default;
WebViewOwner::WebViewOwner(WebViewOwner &&) noexcept = default;
WebViewOwner &WebViewOwner::operator=(WebViewOwner &&) noexcept = default;

webview::webview *WebViewOwner::get() const noexcept { return view_.get(); }
std::string WebViewOwner::last_error() const { return error_message_; }
}
