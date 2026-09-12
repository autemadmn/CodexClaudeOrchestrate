import Foundation

public enum AccountingPeriodError: Error, Equatable { case unavailableTimeZone(String) }
public enum AccountingPeriod {
    public static func bounds(forMonth month: String, in timeZone: TimeZone) throws -> (start: Date, end: Date) {
        let parts = month.split(separator: "-").compactMap { Int($0) }; guard parts.count == 2, parts[1] > 0, parts[1] < 13 else { throw AccountingPeriodError.unavailableTimeZone("Invalid month") }
        var cal = Calendar(identifier: .gregorian); cal.timeZone = timeZone
        var c = DateComponents(); c.year=parts[0]; c.month=parts[1]; c.day=1
        guard let start = cal.date(from: c), let end = cal.date(byAdding: .month, value: 1, to: start) else { throw AccountingPeriodError.unavailableTimeZone("Cannot create date") }; return (start,end)
    }
    public static func accountingMonth(of date: Date, in timeZone: TimeZone) -> String {
        var cal=Calendar(identifier:.gregorian); cal.timeZone=timeZone; let c=cal.dateComponents([.year,.month], from: date); return String(format:"%04d-%02d", c.year!, c.month!)
    }
}

