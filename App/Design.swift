import SwiftUI

enum Theme {
    static let green = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.40, green: 0.82, blue: 0.64, alpha: 1) : UIColor(red: 0.08, green: 0.37, blue: 0.28, alpha: 1) })
    static let forest = Color(red: 0.055, green: 0.19, blue: 0.15)
    static let canvas = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.065, green: 0.085, blue: 0.075, alpha: 1) : UIColor(red: 0.97, green: 0.965, blue: 0.94, alpha: 1) })
    static let gold = Color(red: 0.83, green: 0.70, blue: 0.43)
}
extension Ball {
    var color: Color {
        switch self {
        case .red: Color(red: 0.79, green: 0.15, blue: 0.19)
        case .yellow: Color(red: 0.94, green: 0.74, blue: 0.13)
        case .green: Color(red: 0.06, green: 0.46, blue: 0.28)
        case .brown: Color(red: 0.48, green: 0.27, blue: 0.14)
        case .blue: Color(red: 0.12, green: 0.40, blue: 0.78)
        case .pink: Color(red: 0.87, green: 0.38, blue: 0.57)
        case .black: Color(red: 0.085, green: 0.10, blue: 0.12)
        }
    }
}
extension View {
    func panel() -> some View { padding(20).background(.background, in: RoundedRectangle(cornerRadius: 24)).overlay(RoundedRectangle(cornerRadius: 24).stroke(.primary.opacity(0.045))) }
    @ViewBuilder func glassBadge() -> some View {
        if #available(iOS 26.0, *) { glassEffect(.regular, in: Capsule()) }
        else { background(.thinMaterial, in: Capsule()) }
    }
}
struct PrimaryButton: View {
    var title: String
    var icon: String = "plus"
    var action: () -> Void
    var body: some View {
        Button(action: action) { Label(title, systemImage: icon).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 11) }
            .buttonStyle(.borderedProminent).buttonBorderShape(.capsule).controlSize(.large)
    }
}

private struct SheetContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// Measures the scroll content rather than reserving a fixed-height sheet.
/// Tall content still scrolls when the system caps the detent to the available screen.
struct ContentSizedSheet<Content: View>: View {
    @State private var height: CGFloat = 300
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { viewport in
            ScrollView {
                content()
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 8)
                    .background {
                        GeometryReader { geometry in
                            Color.clear.preference(key: SheetContentHeightKey.self,
                                                   value: geometry.size.height + viewport.safeAreaInsets.top)
                        }
                    }
            }.scrollBounceBehavior(.basedOnSize)
        }
        .onPreferenceChange(SheetContentHeightKey.self) { measured in
            if measured > 0 { height = ceil(measured) }
        }
        .background(Theme.canvas)
        .presentationDetents([.height(height)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
    }
}

struct ConfirmationSheet<Actions: View>: View {
    @Environment(\.dismiss) private var dismiss
    var title: String
    var message: String
    var icon: String
    @ViewBuilder var actions: () -> Actions
    var body: some View {
        ContentSizedSheet {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: icon).font(.system(size: 24, weight: .medium)).foregroundStyle(Theme.green)
                    .frame(width: 52, height: 52).background(Theme.green.opacity(0.10), in: RoundedRectangle(cornerRadius: 16)).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 9) {
                    Text(title).font(.title2.weight(.semibold)).accessibilityAddTraits(.isHeader)
                    Text(message).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                VStack(spacing: 10) { actions() }
                Button("Cancel") { dismiss() }.font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44).foregroundStyle(.secondary)
            }
        }
    }
}

struct WinnerChoice: View {
    var name: String
    var score: Int
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Avatar(name: name, size: 40)
                Text(name).font(.headline).lineLimit(2)
                Spacer(minLength: 8)
                Text("\(score)").font(.system(.title3, design: .rounded, weight: .semibold)).monospacedDigit().foregroundStyle(.secondary)
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Theme.green)
            }.padding(14).frame(maxWidth: .infinity, minHeight: 64)
                .background(.background, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.green.opacity(0.12)))
        }.buttonStyle(.plain).foregroundStyle(.primary).accessibilityLabel("\(name) wins the frame")
    }
}
struct SectionTitle: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    var title: String
    var detail: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title3.weight(.bold))
            Spacer()
            if let detail, !typeSize.isAccessibilitySize { Text(detail).font(.caption).foregroundStyle(.secondary) }
        }
    }
}
struct StatTile: View {
    var value: String
    var label: String
    var icon: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon).foregroundStyle(Theme.green)
            Text(value).font(.system(.largeTitle, design: .rounded, weight: .semibold)).minimumScaleFactor(0.6).lineLimit(1)
            Text(label).font(.subheadline).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).panel().accessibilityElement(children: .combine)
    }
}
struct BallButton: View {
    @ScaledMetric(relativeTo: .title2) private var ballSize: CGFloat = 62
    var ball: Ball
    var available = true
    var count: Int? = nil
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle().fill(ball.color.gradient).shadow(color: ball.color.opacity(0.28), radius: 8, y: 4)
                    Circle().fill(.white.opacity(0.25)).frame(width: 17, height: 11).blur(radius: 2).offset(x: -12, y: -15)
                    Text("\(count ?? ball.rawValue)").font(.system(.title2, design: .rounded, weight: .bold)).foregroundStyle(ball == .yellow ? Color.black : .white).lineLimit(1).minimumScaleFactor(0.6).padding(.horizontal, 4)
                }.frame(width: min(100, ballSize), height: min(100, ballSize))
                Text(ball.name).font(.caption.weight(.medium)).foregroundStyle(.primary)
            }.frame(maxWidth: .infinity).padding(.vertical, 4).opacity(available ? 1 : 0.30)
        }.buttonStyle(.plain).disabled(!available)
            .accessibilityLabel("Pot \(ball.name.lowercased())\(count.map { ", \($0) remaining" } ?? "")")
            .accessibilityIdentifier("ball-\(ball.rawValue)")
    }
}
struct Avatar: View {
    var name: String
    var size: CGFloat = 46
    var body: some View {
        Text(name.prefix(1).uppercased()).font(.system(size: size * 0.4, weight: .semibold, design: .rounded)).foregroundStyle(Theme.green)
            .frame(width: size, height: size).background(Theme.green.opacity(0.10), in: Circle()).accessibilityHidden(true)
    }
}
struct MatchRow: View {
    @Environment(AppStore.self) private var store
    var match: Match
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: match.isComplete ? "checkmark.circle.fill" : "play.circle.fill").font(.title2).foregroundStyle(Theme.green)
            VStack(alignment: .leading, spacing: 5) {
                Text(store.names(match).joined(separator: " vs ")).font(.headline)
                Text("\(match.createdAt.formatted(date: .abbreviated, time: .omitted)) · \(match.reds) reds").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(match.wins[0])–\(match.wins[1])").font(.system(.title2, design: .rounded, weight: .semibold)).monospacedDigit()
        }.foregroundStyle(.primary).padding(.vertical, 7).accessibilityElement(children: .combine)
    }
}

struct BallGlyph: View {
    var ball: Ball
    var value: Int? = nil
    var size: CGFloat = 34
    var body: some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [ball.color.opacity(0.8),ball.color,ball == .black ? .black : ball.color.opacity(0.7)], center: .topLeading, startRadius: 0, endRadius: size)).shadow(color: .black.opacity(0.2), radius: 3, y: 3)
            Circle().stroke(.white.opacity(0.18), lineWidth: 0.7)
            Ellipse().fill(.white.opacity(0.28)).frame(width: size*0.3, height: size*0.17).blur(radius: 1).offset(x: -size*0.17,y: -size*0.22)
            if let value { Text("\(value)").font(.system(size: size*0.32, weight: .bold, design: .rounded)).foregroundStyle(ball == .yellow ? .black : .white) }
        }.frame(width: size,height: size).accessibilityHidden(true)
    }
}

extension View {
    func selectScoreOnFocus() -> some View {
        onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { notification in
            guard let field = notification.object as? UITextField, field.keyboardType == .numberPad else { return }
            DispatchQueue.main.async { field.selectAll(nil) }
        }
    }
}
