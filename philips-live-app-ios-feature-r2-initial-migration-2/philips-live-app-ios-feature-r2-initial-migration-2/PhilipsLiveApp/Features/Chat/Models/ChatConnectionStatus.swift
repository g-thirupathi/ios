import Foundation

enum ChatConnectionStatus: Equatable {
    case connecting
    case connected
    case reconnecting
    case offline
    case error
}
