import Foundation

// MARK: - Client & membership

enum MembershipTier: String, Codable, CaseIterable {
    case member
    case nonMember = "non_member"

    var displayName: String {
        switch self {
        case .member: return "Member"
        case .nonMember: return "Guest"
        }
    }
}

/// A student, matched 1:1 with an Acuity Scheduling client record.
struct Client: Codable, Identifiable, Equatable {
    let id: String
    var firstName: String
    var lastName: String
    var email: String
    var phone: String?
    var membership: MembershipTier
    /// Acuity client ID the account is linked to (set by the backend at sign-in).
    var acuityClientID: String?
    var ghinNumber: String?
    var homeClub: String?
    var referralCode: String

    var fullName: String { "\(firstName) \(lastName)" }
    var initials: String {
        [firstName.first, lastName.first].compactMap { $0.map(String.init) }.joined()
    }
}

// MARK: - Booking (Acuity)

/// Mirrors an Acuity appointment type. `memberOnly` types are hidden from guests;
/// pricing can differ per tier via Acuity's separate appointment types.
struct AppointmentType: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var details: String
    var durationMinutes: Int
    var price: Double?
    var location: String
    var memberOnly: Bool
    var acuityAppointmentTypeID: Int

    func isVisible(to tier: MembershipTier) -> Bool {
        tier == .member || !memberOnly
    }
}

struct TimeSlot: Codable, Identifiable, Equatable {
    var id: String { "\(appointmentTypeID)-\(start.timeIntervalSince1970)" }
    let appointmentTypeID: String
    let start: Date
}

struct Booking: Codable, Identifiable, Equatable {
    let id: String
    var appointmentTypeName: String
    var start: Date
    var durationMinutes: Int
    var location: String
    var acuityAppointmentID: Int?
}

// MARK: - Lessons, notes & video

/// One coaching session. Notes arrive automatically from Plaud recordings and
/// videos from Swing Catalyst via backend agents (see docs/AGENTS.md).
struct Lesson: Codable, Identifiable, Equatable {
    let id: String
    var date: Date
    var title: String
    var location: String
    var focusAreas: [String]
    var note: LessonNote?
    var videos: [SwingVideo]
}

/// AI-summarized note generated from the coach's Plaud voice recording.
struct LessonNote: Codable, Equatable {
    var summary: String
    var keyTakeaways: [String]
    var homework: [String]
    var source: String        // e.g. "Plaud AI"
    var transcriptURL: URL?
}

/// A swing video captured in Swing Catalyst and synced to the student's account.
struct SwingVideo: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    var angle: String         // "Face On", "Down the Line", ...
    var url: URL
    var thumbnailURL: URL?
    var capturedAt: Date
    var source: String        // "Swing Catalyst"
}

// MARK: - Chat

enum ChatChannel: String, Codable {
    case coach    // direct messages with Collin
    case caddie   // AI assistant with game memory
}

struct ChatMessage: Codable, Identifiable, Equatable {
    let id: String
    var channel: ChatChannel
    var isFromClient: Bool
    var text: String
    var sentAt: Date
}

/// A fact the AI caddie has learned and retained about the student's game.
struct GameMemoryFact: Codable, Identifiable, Equatable {
    let id: String
    var fact: String
    var learnedAt: Date
    var category: String      // "Swing", "Equipment", "Tendencies", "Goals", ...
}

// MARK: - Drills

struct Drill: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    var category: String      // "Driver", "Irons", "Short Game", "Putting", "Fitness"
    var details: String
    var durationMinutes: Int
    var videoURL: URL?
    var thumbnailURL: URL?
}

// MARK: - Game tracking

struct HandicapEntry: Codable, Identifiable, Equatable {
    var id: String { "\(date.timeIntervalSince1970)" }
    let date: Date
    let index: Double
    let source: String        // "GHIN", "Manual"
}

struct RoundSummary: Codable, Identifiable, Equatable {
    let id: String
    var date: Date
    var course: String
    var score: Int
    var toPar: Int
    var source: String        // "GHIN", "Arccos", "UpGame", "TheGrint", "Manual"
}

/// Third-party game data providers the student can connect.
enum IntegrationProvider: String, Codable, CaseIterable, Identifiable {
    case ghin = "GHIN"
    case arccos = "Arccos"
    case upgame = "UpGame"
    case theGrint = "TheGrint"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .ghin: return "Official handicap index & score history"
        case .arccos: return "Shot tracking & strokes gained"
        case .upgame: return "Practice & performance stats"
        case .theGrint: return "Rounds, stats & handicap tracking"
        }
    }

    var icon: String {
        switch self {
        case .ghin: return "number.circle"
        case .arccos: return "dot.radiowaves.left.and.right"
        case .upgame: return "chart.line.uptrend.xyaxis"
        case .theGrint: return "flag.circle"
        }
    }
}

struct IntegrationConnection: Codable, Identifiable, Equatable {
    var id: String { provider.rawValue }
    let provider: IntegrationProvider
    var isConnected: Bool
    var accountLabel: String?
    var lastSyncedAt: Date?
}

// MARK: - Referrals

struct ReferralStatus: Codable, Equatable {
    var code: String
    var invitesSent: Int
    var lessonsBooked: Int
    var rewardsEarned: String   // e.g. "1 complimentary lesson"
    var pending: [ReferralInvite]
}

struct ReferralInvite: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var status: String          // "Invited", "Booked first lesson", "Became member"
    var date: Date
}
