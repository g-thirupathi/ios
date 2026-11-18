import Foundation

final class HomeViewModel: ObservableObject {
    enum Alert: Equatable {
        case callUnavailable(country: String)
        case callFailed

        var titleKey: String {
            switch self {
                case .callUnavailable: "HomeScreen.call_unavailable_title"
                case .callFailed: "HomeScreen.call_failed_title"
            }
        }

        var message: String {
            switch self {
                case let .callUnavailable(country):
                    "\(L10n.string("HomeScreen.call_unavailable_message")) \(country)."
                case .callFailed:
                    L10n.string("HomeScreen.call_failed_message")
            }
        }
    }

    @Published private(set) var unreadCount: Int
    @Published var alert: Alert?

    private let chatRepository: ChatRepository
    private let countryRepository: SupportCountryRepository

    init(chatRepository: ChatRepository, countryRepository: SupportCountryRepository) {
        self.chatRepository = chatRepository
        self.countryRepository = countryRepository
        unreadCount = Self.unreadCount(chatRepository.session)
    }

    func observe() async {
        for await session in chatRepository.sessions() {
            unreadCount = Self.unreadCount(session)
        }
    }

    func callURL() -> URL? {
        let country = countryRepository.selectedCountry()
        guard let number = country.phoneNumber else {
            alert = .callUnavailable(country: country.displayName)
            return nil
        }
        return URL(string: "tel:\(number)")
    }

    func callDidFail() {
        alert = .callFailed
    }

    private static func unreadCount(_ session: ChatSession) -> Int {
        session.conversation.phase == .active ? session.unreadCount : 0
    }
}
