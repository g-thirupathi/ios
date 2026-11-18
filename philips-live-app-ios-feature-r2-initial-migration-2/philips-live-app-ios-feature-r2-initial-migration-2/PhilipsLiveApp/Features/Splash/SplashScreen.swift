import SwiftUI

/// The launch screen's image, shown for a fixed time so the hand-off from the system launch screen is seamless.
struct SplashScreen: View {
    private static let displayNanoseconds: UInt64 = 1_800_000_000

    let completed: Binding<Bool>

    var body: some View {
        GeometryReader { geometry in
            Image("LaunchScreen")
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
        }
        .background(Color("SplashBackground"))
        .ignoresSafeArea()
        .task {
            do {
                try await Task.sleep(nanoseconds: Self.displayNanoseconds)
            } catch {
                return
            }
            completed.wrappedValue = true
        }
    }
}
