import SwiftUI

/// Referral portal: personal code, share sheet, and reward tracking.
struct ReferralView: View {
    @Environment(SessionStore.self) private var session

    @State private var status: ReferralStatus?
    @State private var copied = false

    var body: some View {
        ZStack {
            CWTheme.cream.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Share the game")
                            .font(CWTheme.display(26))
                            .foregroundStyle(CWTheme.charcoal)
                        Text("Coaching at Collin Woods Golf is referral-driven. Introduce a friend or colleague — when they book their first session, you earn a complimentary one.")
                            .font(CWTheme.body(14))
                            .foregroundStyle(CWTheme.stone)
                    }

                    if let status {
                        codeCard(status)
                        statsRow(status)

                        if !status.pending.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                CWSectionHeader(title: "Your Referrals")
                                ForEach(status.pending) { invite in
                                    CWCard(padding: 12) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(invite.name)
                                                    .font(CWTheme.body(15, weight: .semibold))
                                                    .foregroundStyle(CWTheme.charcoal)
                                                Text(invite.date, format: .dateTime.month().day().year())
                                                    .font(CWTheme.body(12))
                                                    .foregroundStyle(CWTheme.stone)
                                            }
                                            Spacer()
                                            Text(invite.status)
                                                .font(CWTheme.body(12, weight: .semibold))
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 5)
                                                .background(badgeColor(invite.status).opacity(0.15))
                                                .foregroundStyle(badgeColor(invite.status))
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, 30)
                    }
                }
                .padding(18)
            }
        }
        .navigationTitle("Referrals")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            status = try? await session.backend.referralStatus()
        }
    }

    private func codeCard(_ status: ReferralStatus) -> some View {
        CWCard {
            VStack(spacing: 12) {
                Text("YOUR CODE")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(1.5)
                    .foregroundStyle(CWTheme.stone)
                Text(status.code)
                    .font(CWTheme.display(30))
                    .kerning(2)
                    .foregroundStyle(CWTheme.pine)

                HStack(spacing: 10) {
                    Button {
                        UIPasteboard.general.string = status.code
                        copied = true
                    } label: {
                        Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(CWPrimaryButtonStyle(prominent: false))

                    ShareLink(item: shareMessage(status)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(CWPrimaryButtonStyle())
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func statsRow(_ status: ReferralStatus) -> some View {
        HStack(spacing: 12) {
            statTile("\(status.invitesSent)", label: "Invited")
            statTile("\(status.lessonsBooked)", label: "Booked")
            statTile(status.rewardsEarned, label: "Earned", small: true)
        }
    }

    private func statTile(_ value: String, label: String, small: Bool = false) -> some View {
        CWCard(padding: 12) {
            VStack(spacing: 4) {
                Text(value)
                    .font(small ? CWTheme.body(13, weight: .semibold) : CWTheme.display(24))
                    .foregroundStyle(CWTheme.pine)
                    .multilineTextAlignment(.center)
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .kerning(1)
                    .foregroundStyle(CWTheme.stone)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func badgeColor(_ status: String) -> Color {
        status == "Invited" ? CWTheme.stone : CWTheme.fairway
    }

    private func shareMessage(_ status: ReferralStatus) -> String {
        "I've been working with Collin Woods Golf — executive golf coaching in NYC. Mention my code \(status.code) when you book your first session: \(AppConfig.websiteURL.absoluteString)"
    }
}

#Preview {
    NavigationStack { ReferralView() }.environment(previewSession())
}
