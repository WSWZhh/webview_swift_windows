# SwiftWebView

[中文](README.md) | [English](README.en.md)

Windows x64 的 Swift WebView 库，使用 Swift/C++ 互操作和 C++ RAII 管理窗口。
应用只需 Swift 接口，无需编写 C 包装、手动管理指针或配置本机绝对路径。

```swift
import SwiftWebView

WebViewApplication.main(
    configuration: .init(title: "My App", width: 960, height: 640),
    content: .localFile("canvas.html")
)
```

## 克隆后运行

先安装以下依赖：

- Windows x64、Swift 6.4 工具链，确保 `swiftc.exe` 在 PATH 中。
- Visual Studio 2022/2026 或 Build Tools，勾选“使用 C++ 的桌面开发”，包含 MSVC x64 工具与 Windows SDK。
- Microsoft Edge WebView2 Runtime；运行时还需要 Swift 与 MSVC 运行库。

使用普通 PowerShell 即可；脚本自动发现 Visual Studio 并初始化开发环境。

```powershell
git clone <仓库地址> SwiftWebView
cd SwiftWebView
.\MyCLIInterop\build.ps1 -Run
```

若系统的 PowerShell 执行策略阻止脚本，可仅对本次进程使用：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\MyCLIInterop\build.ps1 -Run
```

默认输出为 `MyCLIInterop/.build-library`。第三方头文件与许可证已随源码提供，
无需 Git 子模块、NuGet 还原或额外下载源码。首次编译需要生成模块缓存，请预留磁盘空间。
本项目不自动安装上述系统依赖。

## 接入自己的应用

创建 `MyApp/Sources/main.swift`，填入上方示例；把 `canvas.html` 及 CSS、JS、图片放进
`MyApp/Resources`。从仓库根目录运行：

```powershell
.\MyCLIInterop\build.ps1 `
    -SourceDirectory .\MyApp\Sources `
    -ResourceDirectory .\MyApp\Resources `
    -ApplicationName MyApp -OutputDirectory .\out -Run
```

也可以从任何工作目录用脚本的完整路径调用。脚本默认路径基于脚本位置，显式传入的
相对路径基于调用者的当前目录。资源会保留目录结构复制到 exe 旁，`.localFile(...)`
始终相对于 exe 查找，启动时的工作目录不影响加载。

## 目录与验证

- `MyCLIInterop/Sources/SwiftWebView`：公共 Swift API。
- `MyCLIInterop/Sources/WebViewBridge`：C++ RAII 与互操作声明。
- `MyCLIInterop/Sources/MyCLIInterop`、`Sources/canvas.html`：最小示例与本地页面。
- `MyCLIInterop/Tools`：可复用的构建模块。
- `MyCLIInterop/Tests`：独立客户端与资源测试。
- `MyCLIInterop/Vendor`：上游头文件、许可证及声明。

```powershell
.\MyCLIInterop\build.ps1 -LibraryOnly  # 仅生成可迁移的 SDK
.\MyCLIInterop\test.ps1               # 构建、迁移 SDK、编译并运行独立客户端，无需 GUI
.\MyCLIInterop\build.ps1 -SmokeTest   # 创建窗口并自动退出，不验证页面渲染
```

SDK 二进制要求相同 Swift 工具链；更换工具链后从源码重建。
`Package.swift` 也提供库产品，但当前 Windows SwiftPM 流程尚未验证，优先使用上述脚本。
接口、SDK 分发与 SwiftPM 接入详见 [库文档](MyCLIInterop/README.md)。

