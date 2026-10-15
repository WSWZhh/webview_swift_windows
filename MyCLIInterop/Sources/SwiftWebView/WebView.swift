import Foundation
import CxxStdlib
import WebViewBridge
import WinSDK

public enum WebViewError: Error, CustomStringConvertible {
    case invalidSize
    case executablePathUnavailable
    case unreadableFile(URL)
    case initialization(String)
    case operation(String)

    public var description: String {
        switch self {
        case .invalidSize: "Window dimensions must be positive Int32 values."
        case .executablePathUnavailable: "Could not locate the executable."
        case .unreadableFile(let url): "File not found or unreadable: \(url.path)"
        case .initialization(let message): "WebView initialization failed: \(message)"
        case .operation(let name): "WebView operation failed: \(name)"
        }
    }
}

public enum WebViewResources {
    public static func executableDirectory() throws -> URL {
        var path = [WCHAR](repeating: 0, count: 32768)
        let length = GetModuleFileNameW(nil, &path, DWORD(path.count))
        guard length > 0, Int(length) < path.count else {
            throw WebViewError.executablePathUnavailable
        }
        return URL(fileURLWithPath: String(decoding: path.prefix(Int(length)), as: UTF16.self))
            .deletingLastPathComponent()
    }

    /// Relative names resolve beside the executable, never against the working directory.
    public static func file(named name: String, relativeTo directory: URL? = nil) throws -> URL {
        let base = try directory ?? executableDirectory()
        return try readableFile(URL(fileURLWithPath: name, relativeTo: base).absoluteURL)
    }

    public static func readableFile(_ url: URL) throws -> URL {
        var isDirectory: ObjCBool = false
        guard url.isFileURL,
              FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              !isDirectory.boolValue,
              FileManager.default.isReadableFile(atPath: url.path) else {
            throw WebViewError.unreadableFile(url)
        }
        return url
    }
}

public enum WebViewContent {
    /// A path relative to the executable; absolute file paths also work.
    case localFile(String)
    case url(URL)
    case html(String)
}

public struct WebViewConfiguration {
    public var title: String
    public var width: Int
    public var height: Int
    public var resizable: Bool
    public var debug: Bool

    public init(title: String = "WebView", width: Int = 960, height: Int = 640,
                resizable: Bool = true, debug: Bool = false) {
        self.title = title
        self.width = width
        self.height = height
        self.resizable = resizable
        self.debug = debug
    }
}

/// Owns the C++ RAII value. All creation, use and release must occur on the UI thread.
@MainActor
public final class WebViewWindow {
    private let owner: swift_webview.WebViewOwner

    public init(configuration: WebViewConfiguration = .init()) throws {
        guard let width = Int32(exactly: configuration.width), width > 0,
              let height = Int32(exactly: configuration.height), height > 0 else {
            throw WebViewError.invalidSize
        }
        owner = swift_webview.WebViewOwner(configuration.debug)
        try withView { view in
            try Self.check(view.set_title(std.string(configuration.title)), "set_title")
            try Self.check(view.set_size(width, height,
                configuration.resizable ? WEBVIEW_HINT_NONE : WEBVIEW_HINT_FIXED), "set_size")
        }
    }

    public func load(_ content: WebViewContent) throws {
        switch content {
        case .localFile(let name):
            try navigate(WebViewResources.file(named: name))
        case .url(let url):
            try navigate(url.isFileURL ? WebViewResources.readableFile(url) : url)
        case .html(let html):
            try withView { try Self.check($0.set_html(std.string(html)), "set_html") }
        }
    }

    public func run() throws {
        try withView { try Self.check($0.run(), "run") }
    }

    public func terminate() throws {
        try withView { try Self.check($0.terminate(), "terminate") }
    }

    private func navigate(_ url: URL) throws {
        try withView { try Self.check($0.navigate(std.string(url.absoluteString)), "navigate") }
    }

    private func withView<Result>(_ body: (webview.webview) throws -> Result) throws -> Result {
        try withExtendedLifetime(self) {
            guard let view = owner.get() else {
                throw WebViewError.initialization(String(owner.last_error()))
            }
            return try body(view)
        }
    }

    private static func check(_ result: webview.noresult, _ operation: String) throws {
        guard result.ok() else { throw WebViewError.operation(operation) }
    }
}

@MainActor
public enum WebViewApplication {
    /// Returns after releasing the window, including when an operation fails.
    public static func run(configuration: WebViewConfiguration = .init(),
                           content: WebViewContent, smokeTest: Bool = false) -> Int32 {
        do {
            let window = try WebViewWindow(configuration: configuration)
            try window.load(content)
            if smokeTest { try window.terminate() }
            try window.run()
            return 0
        } catch {
            print(error)
            return 1
        }
    }

    /// Convenience entry point; cleanup completes before the process exits.
    public static func main(configuration: WebViewConfiguration = .init(),
                            content: WebViewContent,
                            arguments: [String] = CommandLine.arguments) -> Never {
        let result = run(configuration: configuration, content: content,
                         smokeTest: arguments.contains("--smoke-test"))
        ExitProcess(UInt32(result))
    }
}
