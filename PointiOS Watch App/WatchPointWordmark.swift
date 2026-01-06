import SwiftUI

struct WatchPointWordmark: View {
    let size: CGFloat
    let textColor: Color
    let dotColor: Color

    init(
        size: CGFloat = 32,
        textColor: Color = WatchColors.textPrimary,
        dotColor: Color = WatchColors.green
    ) {
        self.size = size
        self.textColor = textColor
        self.dotColor = dotColor
    }

    var body: some View {
        let dotSize = size * 0.42
        let spacing = size * 0.06

        HStack(alignment: .firstTextBaseline, spacing: spacing) {
            Text("P")
                .font(.system(size: size, weight: .bold))
                .tracking(-1)
                .foregroundColor(textColor)

            Circle()
                .fill(dotColor)
                .frame(width: dotSize, height: dotSize)
                .alignmentGuide(.firstTextBaseline) { dims in
                    dims[.bottom] - size * 0.2
                }

            Text("int")
                .font(.system(size: size, weight: .bold))
                .tracking(-1)
                .foregroundColor(textColor)
        }
    }
}
