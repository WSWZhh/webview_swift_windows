#pragma once
#if defined(__clang__) && __has_feature(modules)
#pragma clang module import WinSDK
#endif
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <objbase.h>
#include <combaseapi.h>
#include <windef.h>
#include <rpc.h>
#include <rpcndr.h>

// Equivalent to Swift's SWIFT_UNSAFE_REFERENCE annotation. Lifetime is managed
// by WebViewOwner; no toolchain-specific include path is needed.
#if defined(__clang__) && __has_attribute(swift_attr)
#define WEBVIEW_SWIFT_REFERENCE \
  __attribute__((swift_attr("import_reference"))) \
  __attribute__((swift_attr("retain:immortal"))) \
  __attribute__((swift_attr("release:immortal"))) \
  __attribute__((swift_attr("unsafe")))
#else
#define WEBVIEW_SWIFT_REFERENCE
#endif

#include "../../../Vendor/webview/core/include/webview/types.h"
#include "../../../Vendor/webview/core/include/webview/backends.hh"
#include <memory>

namespace swift_webview {
// A move-only RAII owner; Swift still calls the upstream window methods.
#if defined(__clang__) && __has_attribute(swift_attr)
class __attribute__((swift_attr("~Copyable"))) WebViewOwner {
#else
class WebViewOwner {
#endif
public:
  explicit WebViewOwner(bool debug) noexcept;
  ~WebViewOwner() noexcept;
  WebViewOwner(const WebViewOwner &) = delete;
  WebViewOwner &operator=(const WebViewOwner &) = delete;
  WebViewOwner(WebViewOwner &&) noexcept;
  WebViewOwner &operator=(WebViewOwner &&) noexcept;

  // Borrow only: the returned view must not outlive this owner.
  webview::webview *get() const noexcept;
  std::string last_error() const;

private:
  std::unique_ptr<webview::webview> view_;
  char error_message_[1024]{};
};
}
