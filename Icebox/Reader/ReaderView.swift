//
//  ReaderView.swift
//  Icebox
//
//  Clean, readable, content-first (spec §7, §13). Shows the archived copy
//  when one exists — that's what makes airplane mode work — and live-extracts
//  otherwise. The real page is always one tap away.
//

import SwiftUI
import SwiftData
import WebKit

struct ReaderView: View {
    let item: SavedItem

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @AppStorage("readerFontSize") private var fontSize = 19
    @AppStorage("readerSerif") private var useSerif = false

    private enum Phase {
        case loading
        case ready(String)
        case notReadable
    }

    @State private var phase: Phase = .loading

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .loading:
                    ProgressView()
                case .ready(let html):
                    ReaderWebView(html: html,
                                  baseURL: item.url,
                                  initialProgress: item.readingProgress ?? 0) { progress in
                        item.readingProgress = progress
                    }
                case .notReadable:
                    ContentUnavailableView {
                        Label("Best read in the browser", systemImage: "safari")
                    } description: {
                        Text("This page doesn't reduce to an article.")
                    } actions: {
                        Button("Open in Browser") {
                            openInBrowser()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle(item.siteName)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem {
                    Menu {
                        Button("Larger Text", systemImage: "textformat.size.larger") {
                            fontSize = min(fontSize + 2, 31)
                        }
                        Button("Smaller Text", systemImage: "textformat.size.smaller") {
                            fontSize = max(fontSize - 2, 13)
                        }
                        Toggle("Serif", isOn: $useSerif)
                    } label: {
                        Label("Appearance", systemImage: "textformat.size")
                    }
                }
                ToolbarItem {
                    // The user can always jump to the real page (spec §7).
                    Button {
                        openInBrowser()
                    } label: {
                        Label("Open in Browser", systemImage: "safari")
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 600)
        #endif
        .task(id: "\(fontSize)-\(useSerif)") {
            await buildPage()
        }
    }

    private func buildPage() async {
        if let article = item.article, let data = article.contentHTML,
           let content = String(data: data, encoding: .utf8) {
            phase = .ready(ReaderHTML.page(contentHTML: content, title: item.title,
                                           byline: article.byline, fontSize: fontSize, useSerif: useSerif))
            return
        }
        guard let url = item.url else {
            phase = .notReadable
            return
        }
        // No archive: extract live, and keep the result so next time is
        // instant (it also becomes searchable text).
        do {
            let extractor = ArticleExtractor()
            let result = try await extractor.extract(from: url)
            phase = .ready(ReaderHTML.page(contentHTML: result.content, title: result.title.isEmpty ? item.title : result.title,
                                           byline: result.byline, fontSize: fontSize, useSerif: useSerif))
            cacheExtraction(result)
        } catch {
            phase = .notReadable
        }
    }

    /// A live extraction is a free head start on the archive — store the
    /// text so search works, but without images it is not marked offline.
    private func cacheExtraction(_ result: ArticleExtractor.Result) {
        guard item.article == nil else { return }
        let article = OfflineArticle()
        article.contentHTML = Data(result.content.utf8)
        article.plainText = result.textContent
        article.excerpt = result.excerpt
        article.byline = result.byline
        article.item = item
        context.insert(article)
        if item.author.isEmpty { item.author = result.byline }
        try? context.save()
    }

    private func openInBrowser() {
        ItemOpener.openInBrowser(item, openURL: openURL, context: context)
        dismiss()
    }
}

/// WKWebView wrapper that restores and reports reading position (spec §7).
private struct ReaderWebView {
    let html: String
    let baseURL: URL?
    let initialProgress: Double
    let onProgress: (Double) -> Void

    init(html: String, baseURL: URL?, initialProgress: Double, onProgress: @escaping (Double) -> Void) {
        self.html = html
        self.baseURL = baseURL
        self.initialProgress = initialProgress
        self.onProgress = onProgress
    }

    func makeWebView() -> WKWebView {
        let webView = WKWebView()
        #if os(iOS)
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        #endif
        webView.loadHTMLString(html, baseURL: baseURL)
        return webView
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: ReaderWebView
        var timer: Timer?
        var lastHTMLHash: Int = 0

        init(parent: ReaderWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let progress = parent.initialProgress
            if progress > 0.01 {
                webView.evaluateJavaScript(
                    "window.scrollTo(0, \(progress) * (document.body.scrollHeight - window.innerHeight));"
                )
            }
            startTracking(webView)
        }

        private func startTracking(_ webView: WKWebView) {
            timer?.invalidate()
            let timer = Timer(timeInterval: 2, repeats: true) { [weak self, weak webView] _ in
                Task { @MainActor in
                    guard let self, let webView else { return }
                    let js = "Math.max(0, Math.min(1, window.scrollY / Math.max(1, document.body.scrollHeight - window.innerHeight)))"
                    if let value = try? await webView.evaluateJavaScript(js), let progress = value as? Double {
                        self.parent.onProgress(progress)
                    }
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }

        deinit {
            timer?.invalidate()
        }
    }
}

#if os(iOS)
extension ReaderWebView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> WKWebView {
        let webView = makeWebView()
        webView.navigationDelegate = context.coordinator
        context.coordinator.lastHTMLHash = html.hashValue
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        if webView.url == nil || context.coordinator.lastHTMLHash != html.hashValue {
            context.coordinator.lastHTMLHash = html.hashValue
            webView.loadHTMLString(html, baseURL: baseURL)
        }
    }
}
#elseif os(macOS)
extension ReaderWebView: NSViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> WKWebView {
        let webView = makeWebView()
        webView.navigationDelegate = context.coordinator
        context.coordinator.lastHTMLHash = html.hashValue
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        if webView.url == nil || context.coordinator.lastHTMLHash != html.hashValue {
            context.coordinator.lastHTMLHash = html.hashValue
            webView.loadHTMLString(html, baseURL: baseURL)
        }
    }
}
#endif
