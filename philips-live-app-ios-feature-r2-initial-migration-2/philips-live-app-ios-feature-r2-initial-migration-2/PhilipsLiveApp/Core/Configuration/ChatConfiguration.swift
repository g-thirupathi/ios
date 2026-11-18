import Foundation

struct ChatConfiguration: Equatable {
    let deploymentId: String
    let domain: String
    /// The country the user chose, for deployments shared by several countries, so the flow can tell them apart.
    let userCountry: String?
}
