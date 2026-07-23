import Foundation

/// Central configuration. Flip `useMockData` off once the companion backend
/// (see docs/BACKEND_API.md) is deployed.
enum AppConfig {
    /// When true, every service is backed by in-memory sample data so the app
    /// is fully navigable in the simulator with no backend.
    static let useMockData = true

    /// Companion backend base URL (proxies Acuity, stores lessons/notes/videos,
    /// runs the AI caddie, relays chat, syncs GHIN/Arccos/UpGame/TheGrint).
    static let apiBaseURL = URL(string: "https://api.collinwoodsgolf.com/v1/")!

    /// Acuity Scheduling owner ID — used for the embedded scheduler fallback
    /// (https://app.acuityscheduling.com/schedule.php?owner=...).
    /// Replace with the real owner ID from the Acuity account.
    static let acuityOwnerID = "REPLACE_WITH_ACUITY_OWNER_ID"

    static var acuitySchedulingURL: URL {
        URL(string: "https://app.acuityscheduling.com/schedule.php?owner=\(acuityOwnerID)")!
    }

    static let coachName = "Collin Woods"
    static let supportEmail = "info@collinwoodsgolf.com"
    static let websiteURL = URL(string: "https://www.collinwoodsgolf.com")!
    static let homeBase = "NEXUS Golf Club · 100 Church St, New York"
}
