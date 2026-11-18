import Filament
import PhotosUI
import SwiftUI

/// Photo library, file and camera pickers plus the attachment disclaimer and alert dialogs.
private struct ChatAttachmentPresentationModifier: ViewModifier {
    @EnvironmentObject private var themeManager: DlsThemeManager
    @ObservedObject var viewModel: ChatViewModel
    @State private var selectedPhotos: [PhotosPickerItem] = []

    func body(content: Content) -> some View {
        dialogs(pickers(content))
    }

    private func pickers(_ content: Content) -> some View {
        content
            .photosPicker(
                isPresented: pickerBinding(.gallery),
                selection: $selectedPhotos,
                maxSelectionCount: max(viewModel.remainingAttachmentSlots, 1),
                matching: .images,
                preferredItemEncoding: .compatible
            )
            .onChange(of: selectedPhotos) { items in
                guard !items.isEmpty else { return }
                selectedPhotos = []
                Task {
                    let picked = await Self.sources(from: items)
                    if let failure = picked.failure {
                        viewModel.attachmentPickerFailed(.gallery, error: failure)
                    }
                    viewModel.addAttachments(picked.sources)
                }
            }
            .fileImporter(
                isPresented: pickerBinding(.document),
                allowedContentTypes: ChatAttachment.pickerContentTypes,
                allowsMultipleSelection: true
            ) { result in
                switch result {
                    case let .success(urls): viewModel.addAttachments(urls.map(AttachmentSource.file))
                    case let .failure(error): viewModel.attachmentPickerFailed(.document, error: error)
                }
            }
            .fullScreenCover(isPresented: pickerBinding(.camera)) {
                CameraPicker(
                    onCapture: { data in
                        viewModel.activePicker = nil
                        let photo = AttachmentSource.data(
                            data,
                            fileName: ChatAttachment.cameraPhotoFileName(at: Date()),
                            mimeType: ChatAttachment.jpegMimeType
                        )
                        viewModel.addAttachments([photo])
                    },
                    onFailure: {
                        viewModel.activePicker = nil
                        viewModel.attachmentPickerFailed(.camera)
                    },
                    onCancel: { viewModel.activePicker = nil }
                )
                .ignoresSafeArea()
            }
    }

    private func dialogs(_ content: some View) -> some View {
        content
            .dlsAlertDialog(
                isPresented: Binding(
                    get: { viewModel.pendingDisclaimerAction != nil },
                    set: {
                        if !$0 {
                            viewModel.pendingDisclaimerAction = nil
                        }
                    }
                ),
                title: L10n.key("DisclaimerScreen.title")
            ) {
                dialogText(DlsText(
                    L10n.string("DisclaimerScreen.attachment_body"),
                    token: themeManager.current.fontTokens.bodyM_Book
                ))
                DlsButton(
                    L10n.string("DisclaimerScreen.got_it"),
                    fullWidth: true,
                    action: viewModel.confirmAttachmentDisclaimer
                )
            }
            .dlsAlertDialog(
                isPresented: Binding(
                    get: { viewModel.attachmentAlert != nil },
                    set: {
                        if !$0 {
                            viewModel.dismissAttachmentAlert()
                        }
                    }
                ),
                title: L10n.key(viewModel.attachmentAlert?.titleKey ?? "")
            ) {
                dialogText(DlsText(
                    viewModel.attachmentAlert?.message ?? "",
                    token: themeManager.current.fontTokens.bodyM_Book
                ))
                DlsButton(
                    L10n.string("ChatScreen.ok"),
                    fullWidth: true,
                    action: viewModel.dismissAttachmentAlert
                )
            }
    }

    private func pickerBinding(_ action: ChatViewModel.AttachmentAction) -> Binding<Bool> {
        Binding(
            get: { viewModel.activePicker == action },
            set: { isPresented in
                if !isPresented, viewModel.activePicker == action {
                    viewModel.activePicker = nil
                }
            }
        )
    }

    private func dialogText(_ text: DlsText) -> some View {
        text
            .multilineTextAlignment(.center)
            .foregroundStyle(themeManager.current.colorTokens.foreground.color.primary)
    }

    /// Photos that fail to load are left out and reported, instead of being sent as empty files.
    private static func sources(
        from items: [PhotosPickerItem]
    ) async -> (sources: [AttachmentSource], failure: Error?) {
        let pickedAt = Date()
        var sources: [AttachmentSource] = []
        var failure: Error?
        for (index, item) in items.enumerated() {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw CocoaError(.fileReadNoSuchFile)
                }
                let baseName = ChatAttachment.pickedPhotoBaseName(at: pickedAt, index: index)
                sources.append(.photo(data, baseName: baseName))
            } catch {
                failure = error
            }
        }
        return (sources, failure)
    }
}

extension View {
    func chatAttachmentPresentation(viewModel: ChatViewModel) -> some View {
        modifier(ChatAttachmentPresentationModifier(viewModel: viewModel))
    }
}
