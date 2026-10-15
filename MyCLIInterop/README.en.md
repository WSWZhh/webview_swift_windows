# SwiftWebView

[中文](README.md) | [English](README.en.md)

A Swift WebView library for Windows x64. It calls `webview::webview` through Swift/C++
interoperability, with a C++ RAII owner managing resource cleanup. Application code uses
only the Swift API.

See the [repository README](../README.en.md) for setup and running after cloning.
Script paths below are relative to this directory.

```swift
import SwiftWebView

WebViewApplication.main(
    configuration: .init(title: "My App", width: 960, height: 640),
    content: .localFile("canvas.html")
)
```

## Requirements and building

Building requires Swift 6.4 (`swiftc.exe` on PATH), Visual Studio C++ x64 tools, and the
Windows SDK. Running requires WebView2 Runtime, the Swift runtime, and the MSVC runtime.
Currently, only Windows x64 is supported. Applications still depend on these system
runtimes; the executable does not bundle them all.

Invoke the script from any working directory:

```powershell
& '<library-directory>\build.ps1' -Run
& '<library-directory>\build.ps1' -LibraryOnly
& '<library-directory>\build.ps1' -OutputDirectory '.\out'
```

The default output directory is `.build-library` inside the library directory. Explicit
relative input and output paths are resolved against the caller's working directory.
The script locates the source relative to itself, discovers Visual Studio using
`VSINSTALLDIR` or `vswhere`, and uses `clang++` from the same directory as `swiftc`.
For a custom installation, pass `-VisualStudioPath '<VS-directory>'`. No drive letters
or user paths are hardcoded.

## Use in another project

Keep the library source and build your own Swift source and resource directories:

```powershell
& '<library-directory>\build.ps1' `
    -SourceDirectory '.\MyApp\Sources' `
    -ResourceDirectory '.\MyApp\Resources' `
    -ApplicationName MyApp -OutputDirectory '.\out' -Run
```

Put the example `main.swift` above in `Sources`, and `canvas.html` in `Resources`.
Resources, including CSS, JavaScript, images, and subdirectories, are copied beside the
executable with their directory structure preserved. Keep the output directory outside
the resource directory.

You can also reuse the build logic as a PowerShell module:

```powershell
Import-Module '<library-directory>\Tools\WebViewBuild.psm1'
Initialize-WebViewToolchain
New-WebViewLibrary -OutputDirectory "$PWD\sdk"
New-WebViewApplication -LibraryDirectory "$PWD\sdk" `
    -SourceDirectory '.\MyApp\Sources' -ResourceDirectory '.\MyApp\Resources' `
    -OutputDirectory "$PWD\out" -ApplicationName MyApp
```

The `sdk` directory contains `SwiftWebView.lib`, the Swift module, C++ headers, dependency
licenses, and the build module. After copying it to another location, import
`sdk\Tools\WebViewBuild.psm1`, then call `Initialize-WebViewToolchain` and
`New-WebViewApplication`. The original library source is no longer needed to build a client.
Compiler caches are outside the SDK and do not need to be distributed.
Compiled Swift modules require a matching Swift toolchain; rebuild the library from
source when switching toolchain versions.

## API

- `WebViewConfiguration`: title, dimensions, resizing, and debug mode.
- `WebViewContent.localFile("assets/index.html")`: resolves relative to the executable; absolute paths also work.
- `WebViewContent.url(URL(...))`: a remote or local URL.
- `WebViewContent.html("<h1>Hello</h1>")`: an HTML string.
- `WebViewApplication.main(...)`: handles window execution, error output, and process exit codes.
- `WebViewWindow`: use `load`, `run`, and `terminate` to manage the flow yourself. Failures
  throw `WebViewError`. These APIs are isolated to `MainActor`; create, use, and release
  windows on the main thread.
- `WebViewResources.file(named:relativeTo:)`: a standalone resource locator with an optional base directory.

The library handles result checking, `std.string` conversion, file URL encoding,
C++ initialization errors, and lifetimes. The Swift class privately holds the noncopyable
C++ RAII `WebViewOwner`; borrowed C++ pointers are not exposed to application code.
Cleanup happens automatically when the window loop ends or Swift throws an error.
`WebViewApplication.run` returns an exit code for use in a host application;
`main` exits the process after cleanup.

Relative `.localFile` paths are based on the executable, regardless of the terminal's
working directory. Browser restrictions on `file://` still apply to fetch requests,
module scripts, and similar features. Use a local HTTP server when your page requires
server behavior.

## Swift Package Manager

`Package.swift` exports the `SwiftWebView` library product. To declare a local package dependency:

```swift
dependencies: [.package(path: "../MyCLIInterop")],
targets: [
    .executableTarget(
        name: "MyApp",
        dependencies: [.product(name: "SwiftWebView", package: "MyCLIInterop")],
        swiftSettings: [.interoperabilityMode(.Cxx)]
    )
]
```

Package targets do not use `unsafeFlags`. On the current development machine, SwiftPM
manifest compilation reports a `SwiftShims` module error, so the complete SwiftPM workflow
has not been verified. The direct build scripts above are the verified entry point.
SwiftPM clients can locate their own target resources with `Bundle.module` and pass
the resulting URL using `.url(...)`.

## Verification

The library and example have been compiled and linked. An independent client has been
built against an SDK relocated to a different directory and run from another working
directory. Checks cover Chinese characters and spaces in filenames, relative and absolute
paths, missing files, and invalid window dimensions.

Run `test.ps1` to reproduce the tests without a GUI. Test artifacts remain in the system
temporary directory for inspection. `build.ps1 -SmokeTest` creates a window and exits
automatically; it checks initialization and API calls, not page rendering. Tests without
a GUI do not verify actual window display or page rendering.

## Third-party dependencies

- `Vendor/webview`: webview/webview, commit `cbbdee44afff22867de9fd88a9fc8350d9bdd399`,
  under the MIT License. Two class definitions have optional `WEBVIEW_SWIFT_REFERENCE` annotations added.
- `Vendor/webview2`: headers from Microsoft.Web.WebView2 `1.0.3240.44`, with LICENSE and NOTICE retained.

The implementation uses C++ interoperability without adding a C ABI wrapper layer.
The Windows SDK is imported through Clang modules. Both languages use C++17 for
interoperability and the dynamic MSVC runtime.
