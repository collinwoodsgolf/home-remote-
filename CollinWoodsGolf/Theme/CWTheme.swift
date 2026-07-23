import SwiftUI

/// Collin Woods Golf brand system.
/// Palette: deep pine green + warm cream + charcoal + muted gold,
/// matching the executive look of collinwoodsgolf.com.
enum CWTheme {
    // MARK: Colors
    static let pine = Color(red: 0.098, green: 0.325, blue: 0.196)       // primary brand green
    static let pineDark = Color(red: 0.055, green: 0.204, blue: 0.125)   // headers / dark surfaces
    static let cream = Color(red: 0.965, green: 0.945, blue: 0.898)      // background
    static let creamCard = Color(red: 0.988, green: 0.976, blue: 0.945)  // cards
    static let charcoal = Color(red: 0.122, green: 0.122, blue: 0.110)   // primary text
    static let stone = Color(red: 0.451, green: 0.443, blue: 0.400)      // secondary text
    static let gold = Color(red: 0.780, green: 0.659, blue: 0.404)       // accents / member tier
    static let fairway = Color(red: 0.290, green: 0.494, blue: 0.349)    // success / positive trend

    static let heroGradient = LinearGradient(
        colors: [pineDark, pine],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: Typography (serif display over clean body, executive feel)
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func body(_ size: CGFloat = 16, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static let cornerRadius: CGFloat = 14
}

// MARK: - Reusable components

/// Standard content card on the cream background.
struct CWCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CWTheme.creamCard)
            .clipShape(RoundedRectangle(cornerRadius: CWTheme.cornerRadius))
            .shadow(color: CWTheme.charcoal.opacity(0.06), radius: 8, y: 3)
    }
}

struct CWPrimaryButtonStyle: ButtonStyle {
    var prominent = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CWTheme.body(16, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(prominent ? CWTheme.pine : CWTheme.pine.opacity(0.12))
            .foregroundStyle(prominent ? CWTheme.cream : CWTheme.pine)
            .clipShape(RoundedRectangle(cornerRadius: CWTheme.cornerRadius))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct CWSectionHeader: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(CWTheme.display(20))
                .foregroundStyle(CWTheme.charcoal)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(CWTheme.body(14, weight: .medium))
                    .foregroundStyle(CWTheme.pine)
            }
        }
    }
}

struct MembershipBadge: View {
    let tier: MembershipTier

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: tier == .member ? "laurel.leading" : "person")
                .font(.system(size: 11, weight: .semibold))
            Text(tier.displayName.uppercased())
                .font(.system(size: 11, weight: .bold))
                .kerning(1.1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(tier == .member ? CWTheme.gold.opacity(0.22) : CWTheme.stone.opacity(0.15))
        .foregroundStyle(tier == .member ? CWTheme.gold : CWTheme.stone)
        .clipShape(Capsule())
    }
}

struct CWEmptyState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(CWTheme.stone.opacity(0.6))
            Text(title)
                .font(CWTheme.display(18))
                .foregroundStyle(CWTheme.charcoal)
            Text(message)
                .font(CWTheme.body(14))
                .foregroundStyle(CWTheme.stone)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
    }
}

/// "CW" monogram used on the sign-in screen and as an in-app logo.
struct CWMonogram: View {
    var size: CGFloat = 72

    var body: some View {
        ZStack {
            Circle()
                .fill(CWTheme.heroGradient)
            Text("CW")
                .font(.system(size: size * 0.38, weight: .semibold, design: .serif))
                .kerning(1)
                .foregroundStyle(CWTheme.cream)
        }
        .frame(width: size, height: size)
        .overlay(Circle().strokeBorder(CWTheme.gold.opacity(0.7), lineWidth: 1.5))
    }
}
