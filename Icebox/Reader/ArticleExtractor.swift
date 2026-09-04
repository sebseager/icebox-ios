//
//  ArticleExtractor.swift
//  Icebox
//
//  Runs Mozilla's Readability (vendored, Apache-2.0) in an offscreen
//  WKWebView to turn a web page into clean article content (spec §7).
//

import Foundation
import WebKit

@MainActor
final class ArticleExtractor: NSObject, WKNavigationDelegate {

    struct Result: Codable {
        var title: String
        var byline: String
        var excerpt: String
        var content: String
        var textContent: String
    }

    enum ExtractionError: Error {
        case loadFailed
        case notReadable
        case scriptMissing
    }

    private var webView: WKWebView?
    private var loadContinuation: CheckedContinuation<Void, Error>?

    func extract(from url: URL) async throws -> Result {
        guard let scriptURL = Bundle.main.url(forResource: "Readability", withExtension: "js"),
              let readabilitySource = try? String(contentsOf: scriptURL, encoding: .utf8) else {
            throw ExtractionError.scriptMissing
        }

        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1024, height: 768), configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView
        defer {
            self.webView = nil
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    self.loadContinuation = continuation
                    webView.load(URLRequest(url: url, timeoutInterval: 25))
                }
            }
            group.addTask {
                try await Task.sleep(for: .seconds(30))
                throw ExtractionError.loadFailed
            }
            try await group.next()
            group.cancelAll()
        }

        // Give client-side rendering a moment to settle.
        try? await Task.sleep(for: .seconds(1))

        let script = readabilitySource + """


        (function() {
            try {
                var article = new Readability(document.cloneNode(true)).parse();
                if (!article || !article.content) { return null; }
                return JSON.stringify({
                    title: article.title || "",
                    byline: article.byline || "",
                    excerpt: article.excerpt || "",
                    content: article.content || "",
                    textContent: article.textContent || ""
                });
            } catch (error) {
                return null;
            }
        })();
        """

        let value = try? await webView.evaluateJavaScript(script)
        guard let json = value as? String, let data = json.data(using: .utf8),
              let result = try? JSONDecoder().decode(Result.self, from: data),
              !result.content.isEmpty else {
            throw ExtractionError.notReadable
        }
        return result
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadContinuation?.resume()
        loadContinuation = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        loadContinuation?.resume(throwing: ExtractionError.loadFailed)
        loadContinuation = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        loadContinuation?.resume(throwing: ExtractionError.loadFailed)
        loadContinuation = nil
    }
}
