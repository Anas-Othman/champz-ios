import SwiftUI

/// A network image with a placeholder. `AsyncImage` for now (memory cache only);
/// swap the implementation for Nuke when lists need a disk cache.
public struct RemoteImage<Placeholder: View>: View {
    private let url: URL?
    private let cornerRadius: CGFloat
    private let placeholder: () -> Placeholder

    public init(url: String, cornerRadius: CGFloat = 0, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url.hasPrefix("http") ? URL(string: url) : nil
        self.cornerRadius = cornerRadius
        self.placeholder = placeholder
    }

    public var body: some View {
        GeometryReader { proxy in
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image):
                    image.resizable().scaledToFill()
                case .empty where url != nil:
                    Color.ds.skeleton.shimmering()
                default:
                    placeholder()
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

public extension RemoteImage where Placeholder == Color {
    /// Grey placeholder when there is nothing better to show.
    init(url: String, cornerRadius: CGFloat = 0) {
        self.init(url: url, cornerRadius: cornerRadius) { Color.ds.skeleton }
    }
}

/// Round avatar with an initial as fallback.
public struct AvatarView: View {
    private let url: String
    private let name: String
    private let size: CGFloat

    public init(url: String, name: String, size: CGFloat = 40) {
        self.url = url
        self.name = name
        self.size = size
    }

    public var body: some View {
        RemoteImage(url: url, cornerRadius: size / 2) {
            ZStack {
                Color.ds.brandAccentSoft
                Text(verbatim: String(name.prefix(1)).uppercased())
                    .font(AppFont.bodyEmphasis)
                    .foregroundStyle(.ds.brandPrimary)
            }
        }
        .frame(width: size, height: size)
    }
}
