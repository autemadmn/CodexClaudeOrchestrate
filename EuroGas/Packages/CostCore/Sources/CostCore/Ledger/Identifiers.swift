import Foundation

public struct PersonID: Hashable, Codable, Sendable, Comparable { public let rawValue: String; public init(_ rawValue: String) { self.rawValue = rawValue }; public static func < (l: Self, r: Self) -> Bool { l.rawValue < r.rawValue } }
public struct GroupID: Hashable, Codable, Sendable, Comparable { public let rawValue: String; public init(_ rawValue: String) { self.rawValue = rawValue }; public static func < (l: Self, r: Self) -> Bool { l.rawValue < r.rawValue } }
public struct TripID: Hashable, Codable, Sendable { public let rawValue: String; public init(_ rawValue: String) { self.rawValue = rawValue } }
public struct PaymentBatchID: Hashable, Codable, Sendable { public let rawValue: String; public init(_ rawValue: String) { self.rawValue = rawValue } }

