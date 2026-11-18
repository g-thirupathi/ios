protocol CameraPermissionRepository {
    var isCameraAvailable: Bool { get }
    /// Asks for access the first time; afterwards returns the user's earlier answer.
    func requestAccess() async -> Bool
}

struct DefaultCameraPermissionRepository: CameraPermissionRepository {
    private let provider: CameraPermissionProvider

    init(provider: CameraPermissionProvider) {
        self.provider = provider
    }

    var isCameraAvailable: Bool {
        provider.isCameraAvailable
    }

    func requestAccess() async -> Bool {
        await provider.requestAccess()
    }
}
