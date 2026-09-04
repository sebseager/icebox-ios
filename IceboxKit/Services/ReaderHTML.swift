//
//  ReaderHTML.swift
//  Icebox
//

import Foundation

/// Pure HTML work for the reader: wrapping extracted article content in a
/// clean, themable page, and inlining images so archives are self-contained
/// (spec §7). No WebKit here — everything is testable strings.
nonisolated enum ReaderHTML {

    // MARK: - Template

    static func page(contentHTML: String, title: String, byline: String,
                     fontSize: Int = 19, useSerif: Bool = false) -> String {
        let fontStack = useSerif
            ? "'New York', 'Times New Roman', ui-serif, serif"
            : "-apple-system, ui-sans-serif, sans-serif"
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
        <title>\(escaped(title))</title>
        <style>
        :root {
            color-scheme: light dark;
            --text: #1d1d1f;
            --secondary: #6e6e73;
            --background: #ffffff;
            --link: #0066cc;
        }
        @media (prefers-color-scheme: dark) {
            :root {
                --text: #e8e8ed;
                --secondary: #98989d;
                --background: #1c1c1e;
                --link: #409cff;
            }
        }
        html { background: var(--background); }
        body {
            font-family: \(fontStack);
            font-size: \(fontSize)px;
            line-height: 1.55;
            color: var(--text);
            background: var(--background);
            margin: 0 auto;
            padding: 24px 20px 60px;
            max-width: 42em;
            -webkit-text-size-adjust: 100%;
            word-wrap: break-word;
        }
        h1.reader-title { font-size: 1.45em; line-height: 1.25; margin: 0 0 4px; }
        p.reader-byline { color: var(--secondary); font-size: 0.85em; margin: 0 0 28px; }
        img, video, figure { max-width: 100%; height: auto; }
        figure { margin: 1.2em 0; }
        figcaption { color: var(--secondary); font-size: 0.8em; }
        a { color: var(--link); }
        pre { overflow-x: auto; padding: 12px; background: rgba(128,128,128,0.12); border-radius: 8px; font-size: 0.85em; }
        code { font-family: ui-monospace, monospace; }
        blockquote { margin: 1em 0; padding-left: 1em; border-left: 3px solid var(--secondary); color: var(--secondary); }
        hr { border: none; border-top: 1px solid rgba(128,128,128,0.3); margin: 2em 0; }
        table { border-collapse: collapse; width: 100%; font-size: 0.9em; }
        td, th { border: 1px solid rgba(128,128,128,0.3); padding: 6px; }
        </style>
        </head>
        <body>
        <h1 class="reader-title">\(escaped(title))</h1>
        \(byline.isEmpty ? "" : "<p class=\"reader-byline\">\(escaped(byline))</p>")
        <div class="reader-content">
        \(contentHTML)
        </div>
        </body>
        </html>
        """
    }

    static func escaped(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    // MARK: - Image inlining

    /// Every image source referenced by `<img>` tags, resolved against the
    /// page URL. Duplicates removed, order preserved. The original attribute
    /// string is kept so replacements can match exactly.
    static func imageSources(in html: String, base: URL?) -> [(attribute: String, url: URL)] {
        var seen = Set<String>()
        var result: [(String, URL)] = []
        for match in html.matches(of: /<img\b[^>]*?\bsrc\s*=\s*(?:"([^"]+)"|'([^']+)')/.ignoresCase()) {
            let attribute = match.1.map(String.init) ?? match.2.map(String.init) ?? ""
            guard !attribute.isEmpty, !attribute.hasPrefix("data:"), !seen.contains(attribute) else { continue }
            guard let url = URL(string: attribute, relativeTo: base)?.absoluteURL,
                  url.scheme == "http" || url.scheme == "https" else { continue }
            seen.insert(attribute)
            result.append((attribute, url))
        }
        return result
    }

    /// Replaces `src` attribute values with the given data URIs (or any
    /// replacement string), matching the exact original attribute value.
    static func replacingImageSources(in html: String, with replacements: [String: String]) -> String {
        var result = html
        for (original, replacement) in replacements {
            result = result.replacingOccurrences(of: "src=\"\(original)\"", with: "src=\"\(replacement)\"")
            result = result.replacingOccurrences(of: "src='\(original)'", with: "src='\(replacement)'")
        }
        return result
    }

    static func dataURI(for data: Data, mimeType: String) -> String {
        "data:\(mimeType);base64,\(data.base64EncodedString())"
    }
}
