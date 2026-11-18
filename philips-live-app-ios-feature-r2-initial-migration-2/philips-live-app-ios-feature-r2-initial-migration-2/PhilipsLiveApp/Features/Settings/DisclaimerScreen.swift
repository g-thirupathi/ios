import Filament
import SwiftUI

struct DisclaimerScreen: View {
    @EnvironmentObject private var themeManager: DlsThemeManager

    var body: some View {
        let dimensions = themeManager.current.dimensionTokens
        TopBarContainer(titleKey: "DisclaimerScreen.title", backLabelKey: "DisclaimerScreen.back") {
            ScrollView {
                VStack(alignment: .leading, spacing: dimensions.size17) {
                    DisclaimerSection(titleKey: "DisclaimerScreen.chat_title", bodyKey: "DisclaimerScreen.chat_body")
                    DisclaimerSection(
                        titleKey: "DisclaimerScreen.attachment_title",
                        bodyKey: "DisclaimerScreen.attachment_body"
                    )
                }
                .padding(.horizontal, dimensions.size11)
                .padding(.vertical, dimensions.size11)
            }
            .bouncesOnlyWhenScrollable()
        }
    }
}
