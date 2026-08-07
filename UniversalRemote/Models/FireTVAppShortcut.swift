import SwiftUI

/// A one-tap shortcut that launches a streaming app on the Fire TV. Package
/// names are the Fire OS application IDs the launcher intent targets.
struct FireTVAppShortcut: Identifiable, Hashable {
    var id: String { packageName }
    let name: String
    let packageName: String
    let symbol: String
    let tint: Color

    /// Curated defaults covering the common Fire TV streaming apps.
    static let defaults: [FireTVAppShortcut] = [
        FireTVAppShortcut(name: "Netflix",     packageName: "com.netflix.ninja",          symbol: "n.square.fill",      tint: .red),
        FireTVAppShortcut(name: "Prime Video", packageName: "com.amazon.avod",            symbol: "play.tv.fill",       tint: .blue),
        FireTVAppShortcut(name: "YouTube",     packageName: "com.amazon.firetv.youtube",  symbol: "play.rectangle.fill", tint: .red),
        FireTVAppShortcut(name: "Disney+",     packageName: "com.disney.disneyplus",      symbol: "sparkles.tv.fill",   tint: .indigo),
        FireTVAppShortcut(name: "Hulu",        packageName: "com.hulu.plus",              symbol: "tv.fill",            tint: .green),
        FireTVAppShortcut(name: "Spotify",     packageName: "com.spotify.tv.android",     symbol: "music.note",         tint: .green),
    ]
}
