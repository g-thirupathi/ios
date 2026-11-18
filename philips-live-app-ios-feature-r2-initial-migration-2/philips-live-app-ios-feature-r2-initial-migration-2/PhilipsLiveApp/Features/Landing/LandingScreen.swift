import Filament
import SwiftUI

struct LandingScreen: View {
    private enum LinkTarget: String {
        case privacyPolicy
        case termsOfUse

        var url: URL? {
            URL(string: "philipslive-landing://\(rawValue)")
        }
    }

    let onGetStarted: () -> Void
    let onPrivacyPolicy: () -> Void
    let onTermsOfUse: () -> Void

    @EnvironmentObject private var themeManager: DlsThemeManager

    private var theme: DlsTheme {
        themeManager.current
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                content
                    .frame(minHeight: geometry.size.height, alignment: .bottom)
            }
            .bouncesOnlyWhenScrollable()
        }
        .background { background.ignoresSafeArea() }
    }

    private var background: some View {
        Color.black
            .overlay {
                Image("LandingBackground")
                    .resizable()
                    .scaledToFill()
            }
            .overlay {
                LinearGradient(colors: [.black.opacity(0), .black], startPoint: .top, endPoint: .bottom)
            }
            .clipped()
    }

    private var content: some View {
        VStack(spacing: theme.dimensionTokens.size13) {
            VStack(spacing: theme.dimensionTokens.size09) {
                DlsText(L10n.string("LandingScreen.title"), token: theme.fontTokens.headlineXL_Bold)
                DlsText(L10n.string("LandingScreen.subtitle"), token: theme.fontTokens.bodyM_Book)
            }
            DlsButton(L10n.string("LandingScreen.get_started"), fullWidth: true, action: onGetStarted)
            DlsText(
                privacyText,
                token: theme.fontTokens.referenceM_Book,
                foregroundStyle: theme.colorTokens.foreground.color.secondary
            )
            .environment(\.openURL, OpenURLAction(handler: openLink))
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, theme.dimensionTokens.size11)
        .padding(.bottom, theme.dimensionTokens.size13)
        .padding(.top, theme.dimensionTokens.size07)
        .frame(maxWidth: .infinity)
    }

    private var privacyText: AttributedString {
        var text = AttributedString("\(L10n.string("LandingScreen.privacy_prefix")) ")
        text += link("LandingScreen.privacy_policy", target: .privacyPolicy)
        text += AttributedString(" \(L10n.string("LandingScreen.terms_connector")) ")
        text += link("LandingScreen.terms_of_use", target: .termsOfUse)
        text += AttributedString(" \(L10n.string("LandingScreen.privacy_suffix"))")
        return text
    }

    private func link(_ key: String, target: LinkTarget) -> AttributedString {
        var text = AttributedString(L10n.string(key))
        text.link = target.url
        text.foregroundColor = theme.link.color.text.normal
        text.underlineStyle = .single
        return text
    }

    private func openLink(_ url: URL) -> OpenURLAction.Result {
        switch url.host.flatMap(LinkTarget.init) {
            case .privacyPolicy: onPrivacyPolicy()
            case .termsOfUse: onTermsOfUse()
            case nil: return .systemAction
        }
        return .handled
    }
}
