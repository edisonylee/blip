import Foundation

struct CountryCode: Identifiable, Hashable {
    let id: String       // ISO 3166-1 alpha-2
    let flag: String     // emoji flag
    let name: String
    let dialCode: String // e.g. "+1"
}

extension CountryCode {
    static let `default` = CountryCode(id: "US", flag: "🇺🇸", name: "United States", dialCode: "+1")

    // Common countries ordered by global user volume
    static let all: [CountryCode] = [
        .init(id: "US", flag: "🇺🇸", name: "United States",      dialCode: "+1"),
        .init(id: "GB", flag: "🇬🇧", name: "United Kingdom",      dialCode: "+44"),
        .init(id: "CA", flag: "🇨🇦", name: "Canada",              dialCode: "+1"),
        .init(id: "AU", flag: "🇦🇺", name: "Australia",           dialCode: "+61"),
        .init(id: "IN", flag: "🇮🇳", name: "India",               dialCode: "+91"),
        .init(id: "DE", flag: "🇩🇪", name: "Germany",             dialCode: "+49"),
        .init(id: "FR", flag: "🇫🇷", name: "France",              dialCode: "+33"),
        .init(id: "JP", flag: "🇯🇵", name: "Japan",               dialCode: "+81"),
        .init(id: "KR", flag: "🇰🇷", name: "South Korea",         dialCode: "+82"),
        .init(id: "BR", flag: "🇧🇷", name: "Brazil",              dialCode: "+55"),
        .init(id: "MX", flag: "🇲🇽", name: "Mexico",              dialCode: "+52"),
        .init(id: "NL", flag: "🇳🇱", name: "Netherlands",         dialCode: "+31"),
        .init(id: "SE", flag: "🇸🇪", name: "Sweden",              dialCode: "+46"),
        .init(id: "NO", flag: "🇳🇴", name: "Norway",              dialCode: "+47"),
        .init(id: "DK", flag: "🇩🇰", name: "Denmark",             dialCode: "+45"),
        .init(id: "FI", flag: "🇫🇮", name: "Finland",             dialCode: "+358"),
        .init(id: "CH", flag: "🇨🇭", name: "Switzerland",         dialCode: "+41"),
        .init(id: "ES", flag: "🇪🇸", name: "Spain",               dialCode: "+34"),
        .init(id: "IT", flag: "🇮🇹", name: "Italy",               dialCode: "+39"),
        .init(id: "PT", flag: "🇵🇹", name: "Portugal",            dialCode: "+351"),
        .init(id: "PL", flag: "🇵🇱", name: "Poland",              dialCode: "+48"),
        .init(id: "NZ", flag: "🇳🇿", name: "New Zealand",         dialCode: "+64"),
        .init(id: "SG", flag: "🇸🇬", name: "Singapore",           dialCode: "+65"),
        .init(id: "HK", flag: "🇭🇰", name: "Hong Kong",           dialCode: "+852"),
        .init(id: "PH", flag: "🇵🇭", name: "Philippines",         dialCode: "+63"),
        .init(id: "ID", flag: "🇮🇩", name: "Indonesia",           dialCode: "+62"),
        .init(id: "MY", flag: "🇲🇾", name: "Malaysia",            dialCode: "+60"),
        .init(id: "TH", flag: "🇹🇭", name: "Thailand",            dialCode: "+66"),
        .init(id: "VN", flag: "🇻🇳", name: "Vietnam",             dialCode: "+84"),
        .init(id: "ZA", flag: "🇿🇦", name: "South Africa",        dialCode: "+27"),
        .init(id: "NG", flag: "🇳🇬", name: "Nigeria",             dialCode: "+234"),
        .init(id: "EG", flag: "🇪🇬", name: "Egypt",               dialCode: "+20"),
        .init(id: "PK", flag: "🇵🇰", name: "Pakistan",            dialCode: "+92"),
        .init(id: "BD", flag: "🇧🇩", name: "Bangladesh",          dialCode: "+880"),
        .init(id: "AR", flag: "🇦🇷", name: "Argentina",           dialCode: "+54"),
        .init(id: "CL", flag: "🇨🇱", name: "Chile",               dialCode: "+56"),
        .init(id: "CO", flag: "🇨🇴", name: "Colombia",            dialCode: "+57"),
        .init(id: "TR", flag: "🇹🇷", name: "Turkey",              dialCode: "+90"),
        .init(id: "SA", flag: "🇸🇦", name: "Saudi Arabia",        dialCode: "+966"),
        .init(id: "AE", flag: "🇦🇪", name: "UAE",                 dialCode: "+971"),
    ]
}
