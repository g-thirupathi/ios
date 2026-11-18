import Filament
import SwiftUI

/// Renders already styled text: bold runs and links are attributes of the `AttributedString` paragraphs.
struct DocumentScreen: View {
    @EnvironmentObject private var themeManager: DlsThemeManager
    @State private var webPage: WebPage?

    let backLabelKey: String
    var isModal = false
    let content: DocumentContent

    var body: some View {
        let theme = themeManager.current
        let dimensions = theme.dimensionTokens
        let primary = theme.colorTokens.foreground.color.primary
        TopBarContainer(titleKey: nil, isModal: isModal, backLabelKey: backLabelKey) {
            ScrollView {
                VStack(alignment: .leading, spacing: dimensions.size11) {
                    if let title = content.title {
                        DocumentHeader(titleKey: title)
                    }
                    if content.heading != nil || content.subheading != nil {
                        VStack(alignment: .leading, spacing: dimensions.size03) {
                            if let heading = content.heading {
                                DlsText(
                                    L10n.string(heading),
                                    token: theme.fontTokens.bodyM_Bold,
                                    foregroundStyle: primary
                                )
                            }
                            if let subheading = content.subheading {
                                DlsText(
                                    L10n.string(subheading),
                                    token: theme.fontTokens.bodyS_Book,
                                    foregroundStyle: theme.colorTokens.foreground.color.secondary
                                )
                            }
                        }
                    }
                    ForEach(content.sections) { section in
                        VStack(alignment: .leading, spacing: dimensions.size09) {
                            if let title = section.title {
                                DlsText(title, token: theme.fontTokens.bodyM_Bold, foregroundStyle: primary)
                                    .accessibilityAddTraits(.isHeader)
                            }
                            ForEach(section.paragraphs) { paragraph in
                                Text(paragraph.text)
                                    .dlsFontToken(theme.fontTokens.bodyM_Book)
                                    .foregroundStyle(primary)
                            }
                        }
                    }
                }
                .tint(theme.link.color.text.normal)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, dimensions.size09)
                .padding(.top, dimensions.size05)
                .padding(.bottom, dimensions.size11)
            }
            .bouncesOnlyWhenScrollable()
        }
        .linksInSafariSheet(page: $webPage)
    }
}
