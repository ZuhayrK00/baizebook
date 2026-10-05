import SwiftUI

struct AdaptiveStack<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    var spacing: CGFloat
    var verticalSpacing: CGFloat
    var content: Content
    init(spacing: CGFloat, verticalSpacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.spacing = spacing; self.verticalSpacing = verticalSpacing ?? spacing; self.content = content()
    }
    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: verticalSpacing)) : AnyLayout(HStackLayout(spacing: spacing))
        layout { content }
    }
}
