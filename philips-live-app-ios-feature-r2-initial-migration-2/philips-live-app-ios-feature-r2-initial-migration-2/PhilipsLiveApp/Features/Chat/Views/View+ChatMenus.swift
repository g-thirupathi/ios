import Filament
import SwiftUI

extension View {
    /// The options and attachment menus, drawn above the whole screen so a tap anywhere outside a menu closes it.
    func chatMenus(
        viewModel: ChatViewModel,
        isOptionsMenuPresented: Binding<Bool>,
        inputTopInset: CGFloat
    ) -> some View {
        modifier(ChatMenusModifier(
            viewModel: viewModel,
            isOptionsMenuPresented: isOptionsMenuPresented,
            inputTopInset: inputTopInset
        ))
    }
}

private struct ChatMenusModifier: ViewModifier {
    @EnvironmentObject private var themeManager: DlsThemeManager
    @ObservedObject var viewModel: ChatViewModel
    @Binding var isOptionsMenuPresented: Bool
    /// Space between the top of the chat input block and its text field.
    let inputTopInset: CGFloat

    func body(content: Content) -> some View {
        content.overlayPreferenceValue(ChatMenuAnchorsKey.self) { anchors in
            if isOptionsMenuPresented || viewModel.isAttachmentMenuPresented {
                GeometryReader { proxy in
                    ZStack(alignment: .topLeading) {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture(perform: closeMenus)
                        if isOptionsMenuPresented, viewModel.showsOptionsMenu, let header = anchors.header {
                            let rect = proxy[header]
                            optionsMenu
                                .frame(width: rect.width, alignment: .topTrailing)
                                .offset(x: rect.minX, y: rect.maxY)
                        }
                        if viewModel.isAttachmentMenuPresented, let area = anchors.aboveInput {
                            let rect = proxy[area]
                            place(attachmentMenu(maxWidth: rect.width), in: rect, alignment: .bottomTrailing)
                        }
                    }
                }
            }
        }
    }

    private var dimensions: DlsDimensionTokens {
        themeManager.current.dimensionTokens
    }

    private var optionsMenu: some View {
        ChatOptionsMenu(
            isEndChatEnabled: viewModel.canEndChat,
            onSelect: { _ in
                isOptionsMenuPresented = false
                viewModel.requestEndChat()
            }
        )
        .padding(.horizontal, dimensions.size11)
    }

    /// The design lets the menu end a few points above the text field, overlapping the input's top padding.
    private func attachmentMenu(maxWidth: CGFloat) -> some View {
        AttachmentMenu(maxWidth: maxWidth - 2 * dimensions.size11, onSelect: viewModel.requestAttachment)
            .padding(.horizontal, dimensions.size11)
            .padding(.bottom, dimensions.size05 - inputTopInset)
    }

    private func place(_ menu: some View, in area: CGRect, alignment: Alignment) -> some View {
        menu
            .frame(width: area.width, height: area.height, alignment: alignment)
            .offset(x: area.minX, y: area.minY)
    }

    private func closeMenus() {
        isOptionsMenuPresented = false
        viewModel.isAttachmentMenuPresented = false
    }
}
