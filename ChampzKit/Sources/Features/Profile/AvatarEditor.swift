import PhotosUI
import SwiftUI

/// The 116pt profile photo with a camera badge. Tapping it offers Camera or Gallery
/// ("Upload Image from"), and hands back the picked photo as a resized JPEG.
struct AvatarEditor: View {
    let currentURL: String
    let name: String
    /// A photo picked but not saved yet; shown instead of the current one.
    let photo: Data?
    let onPick: (Data) -> Void

    @State private var isChoosingSource = false
    @State private var isShowingCamera = false
    @State private var isShowingGallery = false
    @State private var galleryItem: PhotosPickerItem?
    @Environment(ToastCenter.self) private var toasts

    private static let size: CGFloat = 116

    var body: some View {
        Button { isChoosingSource = true } label: {
            image
                .frame(width: Self.size, height: Self.size)
                .clipShape(Circle())
                .overlay(alignment: .bottom) {
                    Image(.camera)
                        .font(.footnote)
                        .foregroundStyle(.ds.brandPrimary)
                        .frame(width: 32, height: 32)
                        .background(Color.ds.surface, in: Circle())
                        .offset(y: 12)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(L10n.EditProfile.changePhoto))
        .confirmationDialog(Text(L10n.EditProfile.uploadImageFrom), isPresented: $isChoosingSource) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button { isShowingCamera = true } label: { Text(L10n.EditProfile.camera) }
            }
            Button { isShowingGallery = true } label: { Text(L10n.EditProfile.gallery) }
        }
        .photosPicker(isPresented: $isShowingGallery, selection: $galleryItem, matching: .images)
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraPicker { use($0) }.ignoresSafeArea()
        }
        .onChange(of: galleryItem) {
            guard let item = galleryItem else { return }
            galleryItem = nil
            Task {
                let data = try? await item.loadTransferable(type: Data.self)
                use(data.flatMap(UIImage.init(data:)))
            }
        }
    }

    @ViewBuilder
    private var image: some View {
        if let photo, let picked = UIImage(data: photo) {
            Image(uiImage: picked).resizable().scaledToFill()
        } else {
            AvatarView(url: currentURL, name: name, size: Self.size)
        }
    }

    private func use(_ image: UIImage?) {
        guard let data = image?.profileJPEG() else {
            toasts.show(Toast(.error, L10n.EditProfile.photoUnreadable))
            return
        }
        onPick(data)
    }
}

extension UIImage {
    /// At most 1024pt on the long side, JPEG at 80%: a sharp avatar without uploading a 10 MB photo.
    func profileJPEG(maxSide: CGFloat = 1024) -> Data? {
        let scale = min(1, maxSide / max(size.width, size.height))
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }
}

/// The system camera. SwiftUI has no camera view, so this wraps UIKit's.
private struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage?) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraDevice = .front
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_: UIImagePickerController, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            parent.onImage(info[.originalImage] as? UIImage)
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
