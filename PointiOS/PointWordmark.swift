import SwiftUI

struct PointWordmark: View {
    @Environment(\.adaptiveColors) private var colors
    let size: CGFloat
    let weight: Font.Weight
    let textColor: Color?
    let dotColor: Color

    init(
        size: CGFloat = 26,
        weight: Font.Weight = .bold,
        textColor: Color? = nil,
        dotColor: Color = SwissColors.green
    ) {
        self.size = size
        self.weight = weight
        self.textColor = textColor
        self.dotColor = dotColor
    }

    var body: some View {
        let color = textColor ?? colors.textPrimary
        let dotSize = size * 0.42
        let spacing = size * 0.06

        HStack(alignment: .firstTextBaseline, spacing: spacing) {
            Text("P")
                .font(.system(size: size, weight: weight))
                .tracking(-1)
                .foregroundColor(color)

            Circle()
                .fill(dotColor)
                .frame(width: dotSize, height: dotSize)
                .alignmentGuide(.firstTextBaseline) { dims in
                    dims[.bottom] - size * 0.2
                }

            Text("int")
                .font(.system(size: size, weight: weight))
                .tracking(-1)
                .foregroundColor(color)
        }
    }
}
