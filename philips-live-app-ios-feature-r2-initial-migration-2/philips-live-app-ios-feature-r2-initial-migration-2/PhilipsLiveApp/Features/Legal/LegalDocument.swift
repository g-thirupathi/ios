import SwiftUI

enum LegalDocument: Identifiable {
    case privacyPolicy
    case termsAndConditions
    case licenses

    var id: Self {
        self
    }

    var backLabelKey: String {
        switch self {
            case .privacyPolicy: "PrivacyPolicyScreen.back"
            case .termsAndConditions: "TermsAndConditionsScreen.back"
            case .licenses: "AboutScreen.back"
        }
    }

    func content(fonts: DocumentFonts) -> DocumentContent {
        switch self {
            case .privacyPolicy: PrivacyPolicyContent.make(bold: fonts.bold)
            case .termsAndConditions: TermsAndConditionsContent.make(bold: fonts.bold)
            case .licenses: LicensesContent.make(fonts: fonts)
        }
    }
}
