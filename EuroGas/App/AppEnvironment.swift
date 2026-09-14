import Foundation

enum AppEnvironment {
    static var appGroupID: String { Bundle.main.object(forInfoDictionaryKey: "EuroGasAppGroupIdentifier") as? String ?? "group.com.example.EuroGas" }
    static var proProductID: String { Bundle.main.object(forInfoDictionaryKey: "EuroGasProProductIdentifier") as? String ?? "com.example.EuroGas.pro" }
    static let accountingTimeZone = TimeZone(identifier: "Europe/Madrid")!
    static let databaseName = "EuroGas.sqlite"
}

protocol AppClock: Sendable {
    var now: Date { get }
}

struct SystemAppClock: AppClock { var now: Date { Date() } }
struct FixedAppClock: AppClock {
    let now: Date
    init(_ now: Date = Date(timeIntervalSince1970: 1_725_000_000)) { self.now = now }
}
