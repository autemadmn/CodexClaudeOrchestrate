import Foundation
public enum FreeWindowError: Error, Equatable { case unavailableTimeZone(String) }
/// Detail window only; Free never deletes retained data and monthly statistics use the full month.
public enum FreeWindow {
    public static func visibleRange(now: Date, in timeZone: TimeZone) throws -> (start: Date, end: Date) {
        var cal=Calendar(identifier:.gregorian); cal.timeZone=timeZone; let day=cal.date(byAdding:.day, value:-29, to: now)!; guard let start=cal.date(from: cal.dateComponents([.year,.month,.day], from: day)) else { throw FreeWindowError.unavailableTimeZone("Cannot create local midnight") }; return (start,now)
    }
}

