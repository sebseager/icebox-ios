//
//  PlaylistBuilder.swift
//  Icebox
//

import Foundation

/// Builds account-free YouTube playlists as `watch_videos` URLs (spec §6).
/// YouTube caps how many IDs one URL can carry, so long collections window:
/// tapping item N sends a playlist from N forward to the cap.
nonisolated enum PlaylistBuilder {

    static let maxVideosPerPlaylist = 50

    struct Window: Equatable, Sendable {
        let url: URL
        /// Which slice of the collection this URL carries.
        let range: Range<Int>
        /// True when the collection is longer than one playlist URL can hold.
        let isWindowed: Bool
    }

    static func playlist(videoIDs: [String], startingAt index: Int = 0) -> Window? {
        guard !videoIDs.isEmpty, videoIDs.indices.contains(index) else { return nil }
        let end = min(index + maxVideosPerPlaylist, videoIDs.count)
        let slice = Array(videoIDs[index..<end])

        let url: URL
        if slice.count == 1 {
            url = YouTubeURLParser.watchURL(videoID: slice[0])
        } else {
            url = URL(string: "https://www.youtube.com/watch_videos?video_ids=" + slice.joined(separator: ","))!
        }
        return Window(url: url, range: index..<end, isWindowed: videoIDs.count > maxVideosPerPlaylist)
    }
}
