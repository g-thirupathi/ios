import Foundation

/// Declared in the order the Language & Region picker lists the countries.
enum SupportCountry: String, CaseIterable {
    case india = "IN"
    case oman = "OM"
    case portugal = "PT"
    case puertoRico = "PR"
    case qatar = "QA"
    case spain = "ES"
    case unitedArabEmirates = "AE"

    static let `default`: SupportCountry = .india

    var defaultLanguage: AppLanguage {
        switch self {
            case .spain: .spanish
            case .portugal: .portuguese
            case .puertoRico: .spanishPuertoRico
            case .india, .unitedArabEmirates, .oman, .qatar: .english
        }
    }

    var phoneNumber: String? {
        switch self {
            case .india: "18004196788"
            case .spain: "34900180612"
            case .portugal: "800201766"
            case .puertoRico: "18552045629"
            case .unitedArabEmirates: "80004447017"
            case .oman: "80074304"
            case .qatar: "+97444367119"
        }
    }

    /// Fixed English names, so the picker reads and sorts the same in every language.
    var displayName: String {
        switch self {
            case .india: "India"
            case .oman: "Oman"
            case .portugal: "Portugal"
            case .puertoRico: "Puerto Rico"
            case .qatar: "Qatar"
            case .spain: "Spain"
            case .unitedArabEmirates: "United Arab Emirates"
        }
    }
}
