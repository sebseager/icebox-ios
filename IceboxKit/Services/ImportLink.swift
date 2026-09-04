//
//  ImportLink.swift
//  Icebox
//

import Foundation

/// Icebox-to-Icebox sharing (spec §15): a collection travels as a plain
/// `icebox://` URL carrying the name and the ordered video IDs. The
/// recipient's app shows an import popover. No server involved.
nonisolated enum ImportLink {

    static let scheme = "icebox"

    static func encode(collectionName: String, videoIDs: [String]) -> URL? {
        guard !videoIDs.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = scheme
        components.host = "import"
        components.queryItems = [
            URLQueryItem(name: "name", value: collectionName),
            URLQueryItem(name: "ids", value: videoIDs.joined(separator: ",")),
        ]
        return components.url
    }

    static func decode(_ url: URL) -> (name: String, videoIDs: [String])? {
        guard url.scheme?.lowercased() == scheme,
              url.host()?.lowercased() == "import",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let idsValue = components.queryItems?.first(where: { $0.name == "ids" })?.value
        else { return nil }

        let ids = idsValue.split(separator: ",").map(String.init).filter { id in
            id.count == 11 && id.allSatisfy { $0.isLetter && $0.isASCII || $0.isNumber || $0 == "-" || $0 == "_" }
        }
        guard !ids.isEmpty else { return nil }
        let name = components.queryItems?.first(where: { $0.name == "name" })?.value ?? ""
        return (name.isEmpty ? String(localized: "Shared Playlist") : name, ids)
    }
}
