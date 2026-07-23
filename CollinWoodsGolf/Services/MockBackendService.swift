import Foundation

/// In-memory backend so the whole app is navigable with no server.
/// Sample data mirrors exactly what the real backend will return.
final class MockBackendService: BackendService {
    private var client = MockData.client
    private var coachThread = MockData.coachThread
    private var caddieThread = MockData.caddieThread
    private var bookings = MockData.upcomingBookings
    private var connections = MockData.integrations

    private func delay() async {
        try? await Task.sleep(for: .milliseconds(350))
    }

    // MARK: Auth

    func requestSignInCode(email: String) async throws { await delay() }

    func verifySignInCode(email: String, code: String) async throws -> Client {
        await delay()
        client.email = email
        return client
    }

    func restoreSession() async throws -> Client? { nil }

    func signOut() async {}

    // MARK: Booking

    func appointmentTypes(for tier: MembershipTier) async throws -> [AppointmentType] {
        await delay()
        return MockData.appointmentTypes.filter { $0.isVisible(to: tier) }
    }

    func availability(for type: AppointmentType, on date: Date) async throws -> [TimeSlot] {
        await delay()
        let cal = Calendar.current
        guard !cal.isDateInWeekend(date) else { return [] }
        return [9, 11, 14, 16].compactMap { hour in
            guard let start = cal.date(bySettingHour: hour, minute: 0, second: 0, of: date),
                  start > .now else { return nil }
            return TimeSlot(appointmentTypeID: type.id, start: start)
        }
    }

    func book(_ slot: TimeSlot, type: AppointmentType) async throws -> Booking {
        await delay()
        let booking = Booking(
            id: UUID().uuidString,
            appointmentTypeName: type.name,
            start: slot.start,
            durationMinutes: type.durationMinutes,
            location: type.location,
            acuityAppointmentID: nil
        )
        bookings.append(booking)
        bookings.sort { $0.start < $1.start }
        return booking
    }

    func upcomingBookings() async throws -> [Booking] {
        await delay()
        return bookings
    }

    func cancel(_ booking: Booking) async throws {
        await delay()
        bookings.removeAll { $0.id == booking.id }
    }

    // MARK: Lessons

    func lessonHistory() async throws -> [Lesson] {
        await delay()
        return MockData.lessons
    }

    // MARK: Chat

    func messages(in channel: ChatChannel) async throws -> [ChatMessage] {
        await delay()
        return channel == .coach ? coachThread : caddieThread
    }

    func send(_ text: String, in channel: ChatChannel) async throws -> [ChatMessage] {
        let outgoing = ChatMessage(
            id: UUID().uuidString, channel: channel, isFromClient: true, text: text, sentAt: .now)
        if channel == .coach {
            coachThread.append(outgoing)
            return coachThread
        }
        caddieThread.append(outgoing)
        await delay()
        let reply = ChatMessage(
            id: UUID().uuidString,
            channel: .caddie,
            isFromClient: false,
            text: MockData.caddieReply(to: text),
            sentAt: .now
        )
        caddieThread.append(reply)
        return caddieThread
    }

    func gameMemory() async throws -> [GameMemoryFact] {
        await delay()
        return MockData.memoryFacts
    }

    // MARK: Drills

    func drills() async throws -> [Drill] {
        await delay()
        return MockData.drills
    }

    // MARK: Game

    func updateGHIN(number: String) async throws -> Client {
        await delay()
        client.ghinNumber = number
        return client
    }

    func handicapHistory() async throws -> [HandicapEntry] {
        await delay()
        return MockData.handicapHistory
    }

    func recentRounds() async throws -> [RoundSummary] {
        await delay()
        return MockData.rounds
    }

    func integrations() async throws -> [IntegrationConnection] {
        await delay()
        return connections
    }

    func setIntegration(_ provider: IntegrationProvider, connected: Bool) async throws -> [IntegrationConnection] {
        await delay()
        if let i = connections.firstIndex(where: { $0.provider == provider }) {
            connections[i].isConnected = connected
            connections[i].lastSyncedAt = connected ? .now : nil
            connections[i].accountLabel = connected ? client.email : nil
        }
        return connections
    }

    // MARK: Referrals

    func referralStatus() async throws -> ReferralStatus {
        await delay()
        return MockData.referralStatus(code: client.referralCode)
    }
}
