import Filament
import SwiftUI

struct AboutScreen: View {
    @EnvironmentObject private var themeManager: DlsThemeManager
    @State private var webPage: WebPage?
    @State private var presentedDocument: LegalDocument?

    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    private let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""

    var body: some View {
        let theme = themeManager.current
        let primary = theme.colorTokens.foreground.color.primary
        TopBarContainer(titleKey: "AboutScreen.title", backLabelKey: "AboutScreen.back") {
            ScrollView {
                VStack(spacing: theme.dimensionTokens.size17) {
                    DlsIconFactory.shared.shield()
                        .resizable()
                        .scaledToFit()
                        .frame(height: theme.dimensionTokens.size28)
                        .foregroundStyle(theme.colorTokens.brand.color)
                        .padding(.top, theme.dimensionTokens.size17)
                        .padding(.bottom, theme.dimensionTokens.size09)
                        .accessibilityHidden(true)
                    appInfo
                    VStack(alignment: .leading, spacing: theme.dimensionTokens.size09) {
                        DlsText(
                            L10n.string("AboutScreen.copyright"),
                            token: theme.fontTokens.bodyS_Book,
                            foregroundStyle: primary
                        )
                        DlsText(
                            L10n.string("AboutScreen.about_string"),
                            token: theme.fontTokens.bodyS_Book,
                            foregroundStyle: primary
                        )
                        documentLink("AboutScreen.terms_and_conditions", .termsAndConditions)
                        documentLink("PrivacyPolicyScreen.title", .privacyPolicy)
                        documentLink("AboutScreen.links.0.label", .licenses)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    DlsLink(
                        L10n.key("AboutScreen.website"),
                        iconAsset: .operatorsManualISO,
                        token: theme.fontTokens.bodyS_Book,
                        destination: URL(string: L10n.string("AboutScreen.website_url")),
                        underline: false
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, theme.dimensionTokens.size11)
                .padding(.bottom, theme.dimensionTokens.size11)
            }
            .bouncesOnlyWhenScrollable()
        }
        .linksInSafariSheet(page: $webPage)
        .navigationDestination(isPresented: isDocumentPresented) {
            if let presentedDocument {
                LegalDocumentScreen(presentedDocument)
            }
        }
    }

    private var isDocumentPresented: Binding<Bool> {
        Binding(
            get: { presentedDocument != nil },
            set: { isPresented in
                if !isPresented {
                    presentedDocument = nil
                }
            }
        )
    }

    private func documentLink(_ labelKey: String, _ document: LegalDocument) -> some View {
        DlsLink(L10n.key(labelKey)) { presentedDocument = document }
    }

    private var appInfo: some View {
        let theme = themeManager.current
        let primary = theme.colorTokens.foreground.color.primary
        let buildLabel = L10n.string("AboutScreen.build_label")
        let versionLabel = L10n.string("AboutScreen.version_label")
        return VStack(spacing: theme.dimensionTokens.size05) {
            DlsText(
                L10n.string("AboutScreen.app_name"),
                token: theme.fontTokens.headingS_Bold,
                foregroundStyle: primary
            )
            .accessibilityAddTraits(.isHeader)
            VStack {
                DlsText("\(buildLabel): \(build)", token: theme.fontTokens.bodyS_Book, foregroundStyle: primary)
                DlsText("\(versionLabel): \(version)", token: theme.fontTokens.bodyS_Book, foregroundStyle: primary)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
}
