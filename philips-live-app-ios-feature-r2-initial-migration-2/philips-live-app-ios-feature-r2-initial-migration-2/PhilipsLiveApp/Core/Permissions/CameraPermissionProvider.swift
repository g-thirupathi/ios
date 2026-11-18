import AVFoundation
import UIKit

protocol CameraPermissionProvider {
    var isCameraAvailable: Bool { get }
    func requestAccess() async -> Bool
}

struct AVCameraPermissionProvider: CameraPermissionProvider {
    var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: true
            case .notDetermined: await AVCaptureDevice.requestAccess(for: .video)
            default: false
        }
    }
}
