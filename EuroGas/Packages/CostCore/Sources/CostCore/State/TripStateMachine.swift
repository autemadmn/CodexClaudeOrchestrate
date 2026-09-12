import Foundation

public enum TripPauseReason: String, Codable, Equatable, Sendable { case user, stationary, signalLost }

public enum TripPhase: Codable, Equatable, Sendable {
    case idle
    case planning
    case ready
    case starting
    case tracking
    case paused(TripPauseReason)
    case finishing
    case completed
    case interrupted
}

public enum TripCommand: Equatable, Sendable {
    case beginPlanning
    case ready
    case start
    case firstFix
    case pause(TripPauseReason)
    case resume
    case finish
    case finishCommitted
    case reset
    case recoverInterrupted
    case discard
}

public enum TripStateError: Error, Equatable, LocalizedError {
    case invalidTransition(from: TripPhase, command: TripCommand)

    public var errorDescription: String? { "La acción no está disponible en el estado actual del viaje." }
}

public struct TripStateMachine: Equatable, Sendable {
    public private(set) var phase: TripPhase
    public init(phase: TripPhase = .idle) { self.phase = phase }

    @discardableResult
    public mutating func apply(_ command: TripCommand) throws -> TripPhase {
        let next: TripPhase?
        switch (phase, command) {
        case (.idle, .beginPlanning): next = .planning
        case (.planning, .ready): next = .ready
        case (.idle, .start), (.ready, .start): next = .starting
        case (.starting, .firstFix), (.paused, .resume): next = .tracking
        case (.tracking, let .pause(reason)): next = .paused(reason)
        case (.tracking, .finish), (.paused, .finish), (.interrupted, .finish): next = .finishing
        case (.finishing, .finishCommitted): next = .completed
        case (.completed, .reset): next = .idle
        case (.interrupted, .recoverInterrupted): next = .starting
        case (.interrupted, .discard): next = .idle
        default: next = nil
        }
        guard let next else { throw TripStateError.invalidTransition(from: phase, command: command) }
        phase = next
        return next
    }
}

public struct ActiveTripState: Codable, Equatable, Sendable {
    public let tripID: TripID
    public let schemaVersion: Int
    public let sequence: Int
    public let savedAt: Date
    public let phase: TripPhase
    public let lastAcceptedFix: LocationFix?
    public let accumulator: GPSAccumulatorSnapshot
    public let lastMovementAt: Date?
    public let unmeasuredIntervalFlag: Bool
    public let liveActivityID: String?

    public init(tripID: TripID, schemaVersion: Int = 1, sequence: Int, savedAt: Date, phase: TripPhase, lastAcceptedFix: LocationFix?, accumulator: GPSAccumulatorSnapshot, lastMovementAt: Date?, unmeasuredIntervalFlag: Bool, liveActivityID: String?) {
        self.tripID = tripID
        self.schemaVersion = schemaVersion
        self.sequence = sequence
        self.savedAt = savedAt
        self.phase = phase
        self.lastAcceptedFix = lastAcceptedFix
        self.accumulator = accumulator
        self.lastMovementAt = lastMovementAt
        self.unmeasuredIntervalFlag = unmeasuredIntervalFlag
        self.liveActivityID = liveActivityID
    }
}
