# SwiftWebView

[中文](README.md) | [English](README.en.md)

A Swift WebView library for Windows x64, using Swift/C++ interoperability and C++ RAII
to manage window lifetimes. Applications use a Swift API without writing C wrappers,
managing pointers manually, or configuring machine-specific absolute paths.

```swift
import SwiftWebView

WebViewApplication.main(
    configuration: .init(title: "My App", width: 960, height: 640),
    content: .localFile("canvas.html")
)
```

## Build and run after cloning

Install these prerequisites:

- Windows x64 and the Swift 6.4 toolchain, with `swiftc.exe` on PATH.
- Visual Studio 2022/2026 or Build Tools with the **Desktop development with C++**
  workload, including MSVC x64 tools and the Windows SDK.
- Microsoft Edge WebView2 Runtime. The Swift and MSVC runtimes are also required to run applications.

Use a regular PowerShell terminal. The build script finds Visual Studio and initializes
its development environment automatically.

```powershell
git clone <repository-url> SwiftWebView
cd SwiftWebView
.\MyCLIInterop\build.ps1 -Run
```

If PowerShell execution policy blocks the script, you can override it for this process only:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\MyCLIInterop\build.ps1 -Run
```

The default output directory is `MyCLIInterop/.build-library`. Third-party headers and
licenses are included in the repository; no Git submodules, NuGet restore, or additional
source downloads are needed. Allow disk space for the compiler's module cache on the
first build. The scripts do not install the system prerequisites.

## Use the library in your application

Create `MyApp/Sources/main.swift` with the example above. Put `canvas.html` and any CSS,
JavaScript, or images in `MyApp/Resources`. Run from the repository root:

```powershell
.\MyCLIInterop\build.ps1 `
    -SourceDirectory .\MyApp\Sources `
    -ResourceDirectory .\MyApp\Resources `
    -ApplicationName MyApp -OutputDirectory .\out -Run
```

You can also invoke the script by its full path from any working directory. Default paths
are relative to the script; explicitly supplied relative paths are resolved against the
caller's working directory. Resources are copied beside the executable, preserving their
directory structure. `.localFile(...)` resolves paths relative to the executable, so the
working directory at launch does not affect resource loading.

## Project layout and verification

- `MyCLIInterop/Sources/SwiftWebView`: public Swift API.
- `MyCLIInterop/Sources/WebViewBridge`: C++ RAII owner and interoperability declarations.
- `MyCLIInterop/Sources/MyCLIInterop` and `MyCLIInterop/Sources/canvas.html`: minimal example and local page.
- `MyCLIInterop/Tools`: reusable build module.
- `MyCLIInterop/Tests`: independent client and resource tests.
- `MyCLIInterop/Vendor`: upstream headers, licenses, and notices.

```powershell
.\MyCLIInterop\build.ps1 -LibraryOnly  # Build a relocatable SDK only
.\MyCLIInterop\test.ps1               # Build, relocate the SDK, and run an independent client without a GUI
.\MyCLIInterop\build.ps1 -SmokeTest   # Create a window and exit automatically; does not verify rendering
```

The binary SDK requires a matching Swift toolchain. Rebuild from source when changing
toolchains. `Package.swift` also exports a library product, but the Windows SwiftPM
workflow has not been verified; use the build scripts above as the primary entry point.

See the [library documentation](MyCLIInterop/README.en.md) for the API, SDK distribution,
SwiftPM integration, and third-party dependencies.
