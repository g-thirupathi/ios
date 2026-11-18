import SwiftUI

struct RootContainer: View {
    private enum Route {
        case splash
        case landing
        case main
    }

    let dependencies: AppDependencies
    @ObservedObject var viewModel: RootViewModel

    @State private var route = Route.splash
    @State private var presentedDocument: LegalDocument?
    @State private var isLanguageRegionPushed = false
    @State private var isChatPresented = false

    var body: some View {
        switch route {
            case .splash:
                SplashScreen(completed: splashCompleted)
                    .darkTheme()
            case .landing:
                NavigationStack {
                    LandingScreen(
                        onGetStarted: { isLanguageRegionPushed = true },
                        onPrivacyPolicy: { presentedDocument = .privacyPolicy },
                        onTermsOfUse: { presentedDocument = .termsAndConditions }
                    )
                    .darkTheme(forcesDarkAppearance: false)
                    .sheet(item: $presentedDocument) { document in
                        LegalDocumentScreen(document, isModal: true)
                    }
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationDestination(isPresented: $isLanguageRegionPushed) {
                        LanguageRegionScreen(
                            viewModel: dependencies.makeLanguageRegionViewModel(),
                            onContinue: { route = .main }
                        )
                    }
                }
            case .main:
                NavigationStack {
                    MainTabContainer(
                        makeHomeViewModel: dependencies.makeHomeViewModel,
                        onOpenChat: { isChatPresented = true }
                    )
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationDestination(isPresented: $isChatPresented) {
                        ChatScreen(viewModel: dependencies.makeChatViewModel())
                    }
                }
        }
    }

    private var splashCompleted: Binding<Bool> {
        Binding(
            get: { route != .splash },
            set: {
                if $0 {
                    route = viewModel.hasCompletedOnboarding ? .main : .landing
                }
            }
        )
    }
}
