import SwiftUI
import UIKit

/// System camera (`UIImagePickerController`) returning a single JPEG photo.
struct CameraPicker: UIViewControllerRepresentable {
    let onCapture: (Data) -> Void
    let onFailure: () -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_: UIImagePickerController, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onFailure: onFailure, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onCapture: (Data) -> Void
        private let onFailure: () -> Void
        private let onCancel: () -> Void

        init(
            onCapture: @escaping (Data) -> Void,
            onFailure: @escaping () -> Void,
            onCancel: @escaping () -> Void
        ) {
            self.onCapture = onCapture
            self.onFailure = onFailure
            self.onCancel = onCancel
        }

        func imagePickerController(
            _: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let photo = info[.originalImage] as? UIImage
            guard let data = photo?.jpegData(compressionQuality: ImageCompression.jpegQuality) else {
                onFailure()
                return
            }
            onCapture(data)
        }

        func imagePickerControllerDidCancel(_: UIImagePickerController) {
            onCancel()
        }
    }
}
