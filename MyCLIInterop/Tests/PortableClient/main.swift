import Foundation
import SwiftWebView

// These checks exercise the public library without creating a GUI window.
let file = try WebViewResources.file(named: "assets/中文 page.html")
precondition(file.isFileURL)
precondition(file.absoluteString.contains("%20"))
precondition(file.deletingLastPathComponent().lastPathComponent == "assets")
let contents = try String(contentsOf: file, encoding: .utf8)
precondition(contents.contains("portable client"))
let absoluteFile = try WebViewResources.file(named: file.path)
precondition(absoluteFile.standardizedFileURL == file.standardizedFileURL)
do {
    _ = try WebViewResources.file(named: "missing.html")
    fatalError("Expected missing-file error")
} catch WebViewError.unreadableFile { }
do {
    _ = try WebViewWindow(configuration: .init(width: 0))
    fatalError("Expected invalid-size error before GUI initialization")
} catch WebViewError.invalidSize { }
print("Portable library checks passed.")
