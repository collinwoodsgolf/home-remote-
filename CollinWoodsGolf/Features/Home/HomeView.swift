import SwiftUI

struct HomeView: View {
    @Environment(SessionStore.self) private var session

    @State private var appointmentTypes: [AppointmentType] = []
    @State private var upcoming: [Booking] = []
    @State private var isLoading = true
    @State private var showProfile = false

    var body: some View {
        NavigationStack {
            ZStack {
                CWTheme.cream.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        hero

                        if !upcoming.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                CWSectionHeader(title: "Upcoming")
                                ForEach(upcoming) { booking in
                                    UpcomingBookingCard(booking: booking) {
                                        Task { await cancel(booking) }
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            CWSectionHeader(title: "Book a Lesson")
                            if isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 30)
                            } else {
                                ForEach(appointmentTypes) { type in
                                    NavigationLink {
                                        BookingView(appointmentType: type) { booking in
                                            upcoming.append(booking)
                                            upcoming.sort { $0.start < $1.start }
                                        }
                                    } label: {
                                        AppointmentTypeCard(type: type)
                                    }
                                    .buttonStyle(.plain)
                                }
                                NavigationLink {
                                    AcuityWebView()
                                        .navigationTitle("Full Scheduler")
                                        .navigationBarTitleDisplayMode(.inline)
                                } label: {
                                    Text("Open full Acuity scheduler")
                                        .font(CWTheme.body(14, weight: .medium))
                                        .foregroundStyle(CWTheme.pine)
                                        .frame(maxWidth: .infinity)
                                        .padding(.top, 2)
                                }
                            }
                        }

                        NavigationLink {
                            ReferralView()
                        } label: {
                            ReferralPromoCard()
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showProfile = true } label: {
                        Text(session.client?.initials ?? "•")
                            .font(CWTheme.body(13, weight: .bold))
                            .foregroundStyle(CWTheme.cream)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(CWTheme.pine))
                    }
                }
            }
            .sheet(isPresented: $showProfile) { ProfileView() }
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greeting)
                        .font(CWTheme.body(14))
                        .foregroundStyle(CWTheme.cream.opacity(0.8))
                    Text(session.client?.firstName ?? "Welcome")
                        .font(CWTheme.display(30))
                        .foregroundStyle(CWTheme.cream)
                }
                Spacer()
                MembershipBadge(tier: session.membership)
            }
            Text(AppConfig.homeBase)
                .font(CWTheme.body(12))
                .foregroundStyle(CWTheme.cream.opacity(0.65))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CWTheme.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .padding(.top, 6)
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case ..<12: return "Good morning"
        case ..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private func load() async {
        do {
            async let types = session.backend.appointmentTypes(for: session.membership)
            async let bookings = session.backend.upcomingBookings()
            appointmentTypes = try await types
            upcoming = try await bookings
        } catch {
            appointmentTypes = []
        }
        isLoading = false
    }

    private func cancel(_ booking: Booking) async {
        try? await session.backend.cancel(booking)
        upcoming.removeAll { $0.id == booking.id }
    }
}

struct UpcomingBookingCard: View {
    let booking: Booking
    var onCancel: () -> Void

    var body: some View {
        CWCard {
            HStack(spacing: 14) {
                VStack(spacing: 2) {
                    Text(booking.start, format: .dateTime.day())
                        .font(CWTheme.display(24))
                        .foregroundStyle(CWTheme.pine)
                    Text(booking.start, format: .dateTime.month(.abbreviated))
                        .font(CWTheme.body(12, weight: .semibold))
                        .foregroundStyle(CWTheme.stone)
                }
                .frame(width: 52)

                VStack(alignment: .leading, spacing: 3) {
                    Text(booking.appointmentTypeName)
                        .font(CWTheme.body(16, weight: .semibold))
                        .foregroundStyle(CWTheme.charcoal)
                    Text("\(booking.start.formatted(date: .omitted, time: .shortened)) · \(booking.durationMinutes) min")
                        .font(CWTheme.body(13))
                        .foregroundStyle(CWTheme.stone)
                    Text(booking.location)
                        .font(CWTheme.body(12))
                        .foregroundStyle(CWTheme.stone)
                        .lineLimit(1)
                }
                Spacer()
                Menu {
                    Button("Cancel Lesson", role: .destructive, action: onCancel)
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(CWTheme.stone)
                        .padding(8)
                }
            }
        }
    }
}

struct AppointmentTypeCard: View {
    let type: AppointmentType

    var body: some View {
        CWCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(type.name)
                        .font(CWTheme.body(16, weight: .semibold))
                        .foregroundStyle(CWTheme.charcoal)
                    if type.memberOnly {
                        Text("MEMBER")
                            .font(.system(size: 9, weight: .bold))
                            .kerning(1)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(CWTheme.gold.opacity(0.2))
                            .foregroundStyle(CWTheme.gold)
                            .clipShape(Capsule())
                    }
                    Spacer()
                    Text(priceLabel)
                        .font(CWTheme.body(14, weight: .semibold))
                        .foregroundStyle(CWTheme.pine)
                }
                Text(type.details)
                    .font(CWTheme.body(13))
                    .foregroundStyle(CWTheme.stone)
                HStack(spacing: 12) {
                    Label("\(type.durationMinutes) min", systemImage: "clock")
                    Label(type.location, systemImage: "mappin.and.ellipse")
                        .lineLimit(1)
                }
                .font(CWTheme.body(12))
                .foregroundStyle(CWTheme.stone)
            }
        }
    }

    private var priceLabel: String {
        if let price = type.price {
            return price.formatted(.currency(code: "USD").precision(.fractionLength(0)))
        }
        return "Included"
    }
}

struct ReferralPromoCard: View {
    var body: some View {
        CWCard {
            HStack(spacing: 14) {
                Image(systemName: "gift")
                    .font(.system(size: 22))
                    .foregroundStyle(CWTheme.gold)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Refer a Friend")
                        .font(CWTheme.body(16, weight: .semibold))
                        .foregroundStyle(CWTheme.charcoal)
                    Text("Share your code — earn a complimentary session when they book.")
                        .font(CWTheme.body(13))
                        .foregroundStyle(CWTheme.stone)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CWTheme.stone)
            }
        }
    }
}

#Preview {
    HomeView().environment(previewSession())
}
