import SwiftUI

/// A slider with two thumbs for picking a whole-number range (ages, prices…).
/// SwiftUI only ships a single-thumb `Slider`, so this draws its own track and thumbs.
public struct RangeSlider: View {
    @Binding private var range: ClosedRange<Int>
    private let bounds: ClosedRange<Int>

    private let thumb: CGFloat = 28

    public init(range: Binding<ClosedRange<Int>>, in bounds: ClosedRange<Int>) {
        _range = range
        self.bounds = bounds
    }

    public var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width - thumb
            ZStack(alignment: .leading) {
                Capsule().fill(Color.ds.separator).frame(height: 4)
                Capsule()
                    .fill(Color.ds.brandPrimary)
                    .frame(width: x(range.upperBound, width) - x(range.lowerBound, width), height: 4)
                    .offset(x: x(range.lowerBound, width) + thumb / 2)
                handle(at: x(range.lowerBound, width), width: width, isLower: true)
                handle(at: x(range.upperBound, width), width: width, isLower: false)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: thumb + 8)
    }

    private func handle(at position: CGFloat, width: CGFloat, isLower: Bool) -> some View {
        Circle()
            .fill(Color.ds.surface)
            .overlay(Circle().strokeBorder(Color.ds.brandPrimary, lineWidth: 2))
            .shadow(color: .ds.shadow, radius: 2, y: 1)
            .frame(width: thumb, height: thumb)
            .offset(x: position)
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { drag in
                    let value = value(at: drag.location.x - thumb / 2, width)
                    if isLower {
                        range = min(value, range.upperBound) ... range.upperBound
                    } else {
                        range = range.lowerBound ... max(value, range.lowerBound)
                    }
                }
            )
            .accessibilityElement()
            .accessibilityValue(Text(verbatim: "\(isLower ? range.lowerBound : range.upperBound)"))
            .accessibilityAdjustableAction { direction in
                let step = direction == .increment ? 1 : -1
                if isLower {
                    let new = (range.lowerBound + step).clamped(to: bounds.lowerBound ... range.upperBound)
                    range = new ... range.upperBound
                } else {
                    let new = (range.upperBound + step).clamped(to: range.lowerBound ... bounds.upperBound)
                    range = range.lowerBound ... new
                }
            }
    }

    private var span: CGFloat {
        CGFloat(max(1, bounds.upperBound - bounds.lowerBound))
    }

    private func x(_ value: Int, _ width: CGFloat) -> CGFloat {
        CGFloat(value - bounds.lowerBound) / span * width
    }

    private func value(at position: CGFloat, _ width: CGFloat) -> Int {
        let fraction = min(max(position / max(width, 1), 0), 1)
        return bounds.lowerBound + Int((fraction * span).rounded())
    }
}

private extension Int {
    func clamped(to limits: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, limits.lowerBound), limits.upperBound)
    }
}

#Preview("Range slider") {
    @Previewable @State var ages = 18 ... 30
    VStack {
        Text(verbatim: "\(ages.lowerBound) – \(ages.upperBound)")
        RangeSlider(range: $ages, in: 0 ... 100)
    }
    .padding()
}
