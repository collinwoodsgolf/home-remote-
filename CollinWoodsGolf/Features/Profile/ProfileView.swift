import SwiftUI

struct ProfileView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                CWTheme.cream.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        VStack(spacing: 10) {
                            CWMonogram(size: 72)
                            Text(session.client?.fullName ?? "")
                                .font(CWTheme.display(24))
                                .foregroundStyle(CWTheme.charcoal)
                            MembershipBadge(tier: session.membership)
                        }
                        .padding(.top, 12)

                        CWCard {
                            VStack(alignment: .leading, spacing: 12) {
                                infoRow("Email", session.client?.email ?? "—")
                                infoRow("Phone", session.client?.phone ?? "—")
                                infoRow("Acuity account", session.client?.acuityClientID != nil ? "Linked" : "Not linked")
                                infoRow("GHIN", session.client?.ghinNumber.map { "#\($0)" } ?? "Not set")
                                infoRow("Home club", session.client?.homeClub ?? "—")
                            }
                        }

                        NavigationLink {
                            ReferralView()
                        } label: {
                            ReferralPromoCard()
                        }
                        .buttonStyle(.plain)

                        CWCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Link(destination: AppConfig.websiteURL) {
                                    Label("collinwoodsgolf.com", systemImage: "globe")
                                }
                                Link(destination: URL(string: "mailto:\(AppConfig.supportEmail)")!) {
                                    Label(AppConfig.supportEmail, systemImage: "envelope")
                                }
                            }
                            .font(CWTheme.body(14, weight: .medium))
                            .foregroundStyle(CWTheme.pine)
                        }

                        Button("Sign Out", role: .destructive) {
                            Task {
                                await session.signOut()
                                dismiss()
                            }
                        }
                        .font(CWTheme.body(15, weight: .medium))
                        .padding(.top, 6)
                    }
                    .padding(18)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(CWTheme.body(14))
                .foregroundStyle(CWTheme.stone)
            Spacer()
            Text(value)
                .font(CWTheme.body(14, weight: .medium))
                .foregroundStyle(CWTheme.charcoal)
        }
    }
}

#Preview {
    ProfileView().environment(previewSession())
}
