import Foundation

/// Everything the app needs from the companion backend, in one protocol so the
/// whole UI runs against `MockBackendService` today and `LiveBackendService`
/// once the API is deployed. Endpoint contract: docs/BACKEND_API.md.
protocol BackendService {
    // Auth — accounts are matched to Acuity client records by email.
    func requestSignInCode(email: String) async throws
    func verifySignInCode(email: String, code: String) async throws -> Client
    func restoreSession() async throws -> Client?
    func signOut() async

    // Booking (Acuity proxy)
    func appointmentTypes(for tier: MembershipTier) async throws -> [AppointmentType]
    func availability(for type: AppointmentType, on date: Date) async throws -> [TimeSlot]
    func book(_ slot: TimeSlot, type: AppointmentType) async throws -> Booking
    func upcomingBookings() async throws -> [Booking]
    func cancel(_ booking: Booking) async throws

    // Lessons (notes auto-uploaded from Plaud, videos from Swing Catalyst)
    func lessonHistory() async throws -> [Lesson]

    // Chat
    func messages(in channel: ChatChannel) async throws -> [ChatMessage]
    func send(_ text: String, in channel: ChatChannel) async throws -> [ChatMessage]

    // AI caddie memory
    func gameMemory() async throws -> [GameMemoryFact]

    // Drills
    func drills() async throws -> [Drill]

    // Game tracking
    func updateGHIN(number: String) async throws -> Client
    func handicapHistory() async throws -> [HandicapEntry]
    func recentRounds() async throws -> [RoundSummary]
    func integrations() async throws -> [IntegrationConnection]
    func setIntegration(_ provider: IntegrationProvider, connected: Bool) async throws -> [IntegrationConnection]

    // Referrals
    func referralStatus() async throws -> ReferralStatus
}

func makeBackendService() -> BackendService {
    AppConfig.useMockData ? MockBackendService() : LiveBackendService()
}

// MARK: - Live implementation

/// Thin JSON client for the companion backend. Auth is a bearer session token
/// issued by `POST /auth/verify` and kept in the keychain-backed defaults.
final class LiveBackendService: BackendService {
    private let session = URLSession.shared
    private var token: String? {
        get { UserDefaults.standard.string(forKey: "cw.sessionToken") }
        set { UserDefaults.standard.set(newValue, forKey: "cw.sessionToken") }
    }

    private struct Empty: Codable {}

    private func request<Response: Decodable>(
        _ path: String, method: String = "GET"
    ) async throws -> Response {
        try await request(path, method: method, body: Optional<Empty>.none)
    }

    private func request<Body: Encodable, Response: Decodable>(
        _ path: String, method: String, body: Body?
    ) async throws -> Response {
        // Resolved relative to the base so paths may carry query strings.
        guard let url = URL(string: path, relativeTo: AppConfig.apiBaseURL) else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body { req.httpBody = try JSONEncoder.cw.encode(body) }
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder.cw.decode(Response.self, from: data)
    }

    func requestSignInCode(email: String) async throws {
        let _: Empty = try await request("auth/request-code", method: "POST", body: ["email": email])
    }

    func verifySignInCode(email: String, code: String) async throws -> Client {
        struct VerifyResponse: Codable { let token: String; let client: Client }
        let res: VerifyResponse = try await request(
            "auth/verify", method: "POST", body: ["email": email, "code": code])
        token = res.token
        return res.client
    }

    func restoreSession() async throws -> Client? {
        guard token != nil else { return nil }
        return try await request("me")
    }

    func signOut() async { token = nil }

    func appointmentTypes(for tier: MembershipTier) async throws -> [AppointmentType] {
        try await request("booking/appointment-types?tier=\(tier.rawValue)")
    }

    func availability(for type: AppointmentType, on date: Date) async throws -> [TimeSlot] {
        let day = ISO8601DateFormatter.dayOnly.string(from: date)
        return try await request("booking/availability?typeID=\(type.id)&date=\(day)")
    }

    func book(_ slot: TimeSlot, type: AppointmentType) async throws -> Booking {
        try await request("booking/book", method: "POST",
                          body: ["appointmentTypeID": type.id,
                                 "start": ISO8601DateFormatter().string(from: slot.start)])
    }

    func upcomingBookings() async throws -> [Booking] { try await request("booking/upcoming") }

    func cancel(_ booking: Booking) async throws {
        let _: Empty = try await request("booking/\(booking.id)/cancel", method: "POST")
    }

    func lessonHistory() async throws -> [Lesson] { try await request("lessons") }

    func messages(in channel: ChatChannel) async throws -> [ChatMessage] {
        try await request("chat/\(channel.rawValue)/messages")
    }

    func send(_ text: String, in channel: ChatChannel) async throws -> [ChatMessage] {
        try await request("chat/\(channel.rawValue)/messages", method: "POST", body: ["text": text])
    }

    func gameMemory() async throws -> [GameMemoryFact] { try await request("ai/memory") }

    func drills() async throws -> [Drill] { try await request("drills") }

    func updateGHIN(number: String) async throws -> Client {
        try await request("game/ghin", method: "PUT", body: ["ghinNumber": number])
    }

    func handicapHistory() async throws -> [HandicapEntry] { try await request("game/handicap-history") }
    func recentRounds() async throws -> [RoundSummary] { try await request("game/rounds") }
    func integrations() async throws -> [IntegrationConnection] { try await request("game/integrations") }

    func setIntegration(_ provider: IntegrationProvider, connected: Bool) async throws -> [IntegrationConnection] {
        try await request("game/integrations/\(provider.rawValue.lowercased())",
                          method: "PUT", body: ["connected": connected])
    }

    func referralStatus() async throws -> ReferralStatus { try await request("referrals") }
}

extension JSONEncoder {
    static let cw: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}

extension JSONDecoder {
    static let cw: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}

extension ISO8601DateFormatter {
    static let dayOnly: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()
}
