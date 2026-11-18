import Filament
import SwiftUI

/// Filament has no typing indicator; Filament's page indicator animates inside a chat bubble that is as tall and
/// wide as the Figma one (three 8pt dots with a 2pt gap, in a one-line text bubble).
struct TypingIndicatorRow: View {
    @EnvironmentObject private var themeManager: DlsThemeManager
    @State private var selectedDot = 1

    private let dotCount = 3
    private let step: Duration = .milliseconds(400)

    var body: some View {
        HStack {
            DlsChatBubble(tailPosition: .leading, isLatest: false) {
                DlsPageIndicator(selected: $selectedDot, itemCount: UInt(dotCount))
                    .fixedSize()
                    .frame(height: themeManager.current.fontTokens.bodyM_Book.lineHeight)
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, themeManager.current.chatAvatarInset)
        .accessibilityHidden(true)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: step)
                selectedDot = selectedDot % dotCount + 1
            }
        }
    }
}
