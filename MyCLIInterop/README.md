# SwiftWebView

[中文](README.md) | [English](README.en.md)

Windows x64 的 Swift WebView 库。底层通过 Swift/C++ interoperability 调用
`webview::webview`，C++ RAII 对象负责资源释放。应用代码只使用 Swift 接口。

从 Git 克隆后的安装与运行步骤见 [仓库首页](../README.md)。以下脚本路径均相对于本目录。

```swift
import SwiftWebView

WebViewApplication.main(
    configuration: .init(title: "My App", width: 960, height: 640),
    content: .localFile("canvas.html")
)
```

## 环境与构建

需要 Swift 6.4（`swiftc.exe` 在 PATH 中）、Visual Studio C++ x64 工具、Windows SDK，
运行时需要 WebView2 Runtime、Swift 运行库和 MSVC 运行库。当前支持 Windows x64，
路径无关不代表跨平台，也不代表单个 exe 包含所有系统运行库。

可以在任意工作目录调用脚本：

```powershell
& '<库目录>\build.ps1' -Run
& '<库目录>\build.ps1' -LibraryOnly
& '<库目录>\build.ps1' -OutputDirectory '.\out'
```

默认输出到库目录的 `.build-library`。显式传入的相对输入、输出路径均相对于
调用时的当前目录。脚本用自身位置定位库源码，自动通过 `VSINSTALLDIR` 或
`vswhere` 查找 Visual Studio，并使用 Swift 工具链同目录的 `clang++`。
特殊安装可传 `-VisualStudioPath '<VS目录>'`，无固定盘符或用户名。

## 在其他项目中使用

最直接的方式是保留本库源码，编译自己的 Swift 目录和资源目录：

```powershell
& '<库目录>\build.ps1' `
    -SourceDirectory '.\MyApp\Sources' `
    -ResourceDirectory '.\MyApp\Resources' `
    -ApplicationName MyApp -OutputDirectory '.\out' -Run
```

`Sources` 内放上面的 `main.swift`，`Resources` 内放 `canvas.html`。资源目录会
按原结构复制到 exe 旁边，包括 CSS、JS、图片及子目录。不要把输出目录放进资源目录。

构建逻辑也可直接作为 PowerShell 模块复用：

```powershell
Import-Module '<库目录>\Tools\WebViewBuild.psm1'
Initialize-WebViewToolchain
New-WebViewLibrary -OutputDirectory "$PWD\sdk"
New-WebViewApplication -LibraryDirectory "$PWD\sdk" `
    -SourceDirectory '.\MyApp\Sources' -ResourceDirectory '.\MyApp\Resources' `
    -OutputDirectory "$PWD\out" -ApplicationName MyApp
```

`sdk` 含静态库 `SwiftWebView.lib`、Swift 模块、C++ 头文件、依赖许可证和构建模块。
可复制到其他位置后，直接导入 `sdk\Tools\WebViewBuild.psm1`，调用
`Initialize-WebViewToolchain` 和 `New-WebViewApplication`，无需原库源码。
编译缓存位于 SDK 外，无需分发。
编译后的 Swift 模块要求匹配的 Swift 工具链；跨工具链版本请从源码重新生成库。

## 接口

- `WebViewConfiguration`：标题、尺寸、是否可调整大小、调试模式。
- `WebViewContent.localFile("assets/index.html")`：按 exe 位置查找，支持绝对路径。
- `WebViewContent.url(URL(...))`：网络或本地 URL。
- `WebViewContent.html("<h1>Hello</h1>")`：内存 HTML。
- `WebViewApplication.main(...)`：统一错误输出、退出码和窗口运行。
- `WebViewWindow`：需要自行组织流程时使用 `load`、`run`、`terminate`，失败会抛出
  `WebViewError`。这些接口隔离在 `MainActor`，窗口应在主线程内创建、使用并释放。
- `WebViewResources.file(named:relativeTo:)`：独立的资源定位工具，允许指定基准目录。

库内部封装了结果检查、`std.string` 转换、文件 URL 编码、C++ 初始化错误和生命周期。
`WebViewOwner` 仍为不可复制的 C++ RAII 值，Swift 类私有持有它；借用的 C++ 指针不暴露
给应用。窗口循环结束或 Swift 抛错时自动释放。`WebViewApplication.run` 只返回退出码，
适合宿主应用；`main` 在清理完成后退出进程。

`.localFile` 的相对路径基于 exe，终端当前目录不影响加载。浏览器对 `file://` 的
fetch、模块脚本等仍有浏览器限制；需要服务端行为时使用本地 HTTP 服务。

## Swift Package Manager

`Package.swift` 导出 `SwiftWebView` library product，可以按本地包依赖接入：

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

包目标未使用 `unsafeFlags`。当前本机 SwiftPM manifest 编译报 `SwiftShims` 模块错误，
因此 SwiftPM 全流程尚未验证；上述直接构建脚本是已验证入口。SwiftPM 使用者可自行通过
`Bundle.module` 定位自己目标的资源，然后用 `.url(...)` 传给库。

## 验证

库与示例已完成编译、链接。独立客户端已使用迁移到另一目录的 SDK 编译，且从其他工作
目录运行通过；检查包括中文和空格文件名、相对与绝对路径、缺失文件、非法窗口尺寸。
可运行 `test.ps1` 重现无需 GUI 的测试；测试产物保留在系统临时目录以便检查。
`build.ps1 -SmokeTest` 会创建窗口并自动退出，它只检查初始化和调用成功，不确认页面渲染。
无 GUI 测试不覆盖实际窗口显示与页面渲染。

## 第三方依赖

- `Vendor/webview`：webview/webview，提交 `cbbdee44afff22867de9fd88a9fc8350d9bdd399`，
  MIT License。仅给两个类定义增加可选的 `WEBVIEW_SWIFT_REFERENCE` 注解。
- `Vendor/webview2`：Microsoft.Web.WebView2 `1.0.3240.44` 的头文件，保留 LICENSE 和 NOTICE。

底层仍为 C++ 互操作，没有新增 C ABI 包装层。Windows SDK 用 Clang 模块导入，
两种语言统一使用 C++17 与动态 MSVC 运行库。
