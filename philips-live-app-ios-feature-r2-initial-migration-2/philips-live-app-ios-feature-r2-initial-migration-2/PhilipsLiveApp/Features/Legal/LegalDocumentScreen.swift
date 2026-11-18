import Filament
import SwiftUI

/// Pushed from Settings or About, or presented in a sheet (`isModal`) from the landing screen.
struct LegalDocumentScreen: View {
    @EnvironmentObject private var themeManager: DlsThemeManager

    let document: LegalDocument
    let isModal: Bool

    init(_ document: LegalDocument, isModal: Bool = false) {
        self.document = document
        self.isModal = isModal
    }

    private var fonts: DocumentFonts {
        let tokens = themeManager.current.fontTokens
        return DocumentFonts(bold: tokens.bodyM_Bold.font(), small: tokens.bodyS_Book.font())
    }

    var body: some View {
        DocumentScreen(
            backLabelKey: document.backLabelKey,
            isModal: isModal,
            content: document.content(fonts: fonts)
        )
    }
}
