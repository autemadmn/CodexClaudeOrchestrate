import Foundation

public enum AccountingPeriodError: Error, Equatable { case invalidMonth, unavailableTimeZone(String) }
public enum AccountingPeriod {
    public static func bounds(forMonth month: String, in timeZone: TimeZone) throws -> (start: Date, end: Date) {
        let parts = month.split(separator: "-")
        guard parts.count == 2, parts[0].count == 4, parts[1].count == 2,
              let year = Int(parts[0]), let monthNumber = Int(parts[1]),
              monthNumber > 0, monthNumber < 13 else { throw AccountingPeriodError.invalidMonth }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        var c = DateComponents()
        c.year = year
        c.month = monthNumber
        c.day = 1
        guard let start = cal.date(from: c), let end = cal.date(byAdding: .month, value: 1, to: start) else { throw AccountingPeriodError.unavailableTimeZone("Cannot create date") }
        return (start, end)
    }
    public static func accountingMonth(of date: Date, in timeZone: TimeZone) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let c = cal.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", c.year!, c.month!)
    }
}
