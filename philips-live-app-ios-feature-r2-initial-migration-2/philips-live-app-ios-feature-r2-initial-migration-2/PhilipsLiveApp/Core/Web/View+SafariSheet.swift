import SwiftUI

extension View {
    /// Opens every http(s) link tapped inside this view in the in-app Safari sheet instead of the Safari app.
    func linksInSafariSheet(page: Binding<WebPage?>) -> some View {
        environment(\.openURL, OpenURLAction { url in
            guard let linkedPage = WebPage(url: url) else { return .systemAction }
            page.wrappedValue = linkedPage
            return .handled
        })
        .safariSheet(page: page)
    }

    func safariSheet(page: Binding<WebPage?>) -> some View {
        sheet(item: page) { item in
            SafariView(url: item.url)
                .ignoresSafeArea()
        }
    }
}
