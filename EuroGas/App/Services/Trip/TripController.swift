import Foundation
import CostCore
import Persistence

struct TripConfiguration: Equatable, Sendable {
    let vehicleID: String
    let vehicleName: String
    let consumptionPer100: Decimal
    let realWorldFactor: Decimal
    let unitPrice: UnitPriceMilliEUR
    let people: Int
    let splitRule: SplitRule
    let groupID: String
    let participantIDs: [String]
    let origin: String?
    let destination: String?
}

@MainActor
protocol TripControlling: AnyObject {
    var phase: TripPhase { get }
    var distanceMeters: Double { get }
    var currentCost: MoneyCents { get }
    var lastError: String? { get }
    func start(_ configuration: TripConfiguration) async
    func pause() async
    func resume() async
    func finish(expenses: [ExpenseInput], participantIDs: [String]) async
    func recoverIfNeeded() async
    func discardRecovered() async
}

@MainActor
final class TripController: ObservableObject, TripControlling {
    @Published private(set) var phase: TripPhase = .idle
    @Published private(set) var distanceMeters: Double = 0
    @Published private(set) var currentCost: MoneyCents = .zero
    @Published private(set) var lastError: String?

    private let repository: AppRepository
    private let location: LocationProvider
    private let liveActivity: LiveActivityService
    private let clock: any AppClock
    private var machine = TripStateMachine()
    private var filter = GPSFilter()
    private var stationaryDetector = StationaryDetector()
    private var updateTask: Task<Void, Never>?
    private var configuration: TripConfiguration?
    private var tripID: String?
    private var tripStartedAt: Date?
    private var activityID: String?
    private var checkpointSequence = 0
    private var lastCheckpointDate: Date?
    private var lastCheckpointDistance: Double = 0
    private var monotonicStart: ContinuousClock.Instant?
    private var pausedAt: ContinuousClock.Instant?
    private var pausedSeconds: TimeInterval = 0
    private var baseMovingSeconds: TimeInterval = 0
    private var basePausedSeconds: TimeInterval = 0
    private let monotonicClock = ContinuousClock()

    init(repository: AppRepository, location: LocationProvider, liveActivity: LiveActivityService, clock: any AppClock) {
        self.repository = repository; self.location = location; self.liveActivity = liveActivity; self.clock = clock
    }

    func start(_ configuration: TripConfiguration) async {
        guard phase == .idle else { lastError = "Ya hay un viaje en curso."; return }
        if location.authorizationState == .notDetermined { await location.requestAuthorization() }
        guard location.authorizationState == .allowed || location.authorizationState == .reducedAccuracy else {
            lastError = "Necesitamos permiso de ubicación para registrar kilómetros. Puedes seguir planificando sin activarlo."
            return
        }
        do {
            try machine.apply(.start); phase = machine.phase
            let request = TripStartRequest(vehicleID: configuration.vehicleID, consumptionPer100: configuration.consumptionPer100, realWorldFactor: configuration.realWorldFactor, unitPrice: configuration.unitPrice, totalPeople: configuration.people, splitRule: configuration.splitRule, groupID: configuration.groupID, participantIDs: configuration.participantIDs, origin: configuration.origin, destination: configuration.destination, startedAt: clock.now)
            tripID = try repository.startTrip(request); tripStartedAt = clock.now
            self.configuration = configuration
            monotonicStart = monotonicClock.now
            let presentation = livePresentation()
            activityID = try await liveActivity.start(presentation)
            let stream = location.startUpdates()
            updateTask = Task { [weak self] in
                for await fix in stream {
                    guard !Task.isCancelled else { return }
                    await self?.handle(fix)
                }
            }
        } catch { fail(error) }
    }

    func pause() async {
        guard phase == .tracking else { return }
        do {
            try machine.apply(.pause(.user)); phase = machine.phase; pausedAt = monotonicClock.now
            try saveCheckpoint(force: true)
            await liveActivity.update(livePresentation())
        } catch { fail(error) }
    }

    func resume() async {
        if phase == .interrupted {
            do {
                try machine.apply(.recoverInterrupted); phase = machine.phase; filter.requireFreshAnchor()
                monotonicStart = monotonicClock.now
                let stream = location.startUpdates()
                updateTask = Task { [weak self] in for await fix in stream { guard !Task.isCancelled else { return }; await self?.handle(fix) } }
                return
            } catch { fail(error); return }
        }
        guard case .paused = phase else { return }
        if let pausedAt { pausedSeconds += Self.seconds(pausedAt.duration(to: monotonicClock.now)) }
        pausedAt = nil; filter.requireFreshAnchor(); stationaryDetector.reset()
        do { try machine.apply(.resume); phase = machine.phase; try saveCheckpoint(force: true); await liveActivity.update(livePresentation()) }
        catch { fail(error) }
    }

    func finish(expenses: [ExpenseInput], participantIDs: [String]) async {
        guard phase == .tracking || Self.isPaused(phase) || phase == .interrupted else { return }
        do {
            try machine.apply(.finish); phase = machine.phase
            updateTask?.cancel(); location.stopUpdates()
            try saveCheckpoint(force: true)
            guard let tripID else { throw PersistenceError.activeTripMissing }
            let resolvedParticipants = participantIDs.isEmpty ? (configuration?.participantIDs ?? []) : participantIDs
            try repository.completeTrip(.init(tripID: tripID, endedAt: clock.now, expenses: expenses, participantIDs: resolvedParticipants))
            try machine.apply(.finishCommitted); phase = machine.phase
            await liveActivity.end(livePresentation())
        } catch { fail(error); return }
        resetAfterCompletion()
    }

    func recoverIfNeeded() async {
        do {
            guard let state = try repository.activeTripState(), let storedTrip = try repository.activeTrip() else { return }
            tripID = state.tripID.rawValue; filter = GPSFilter(snapshot: state.accumulator, lastAcceptedFix: nil, requiresFreshAnchor: true)
            tripStartedAt = try ISO8601DateFormatter().date(from: storedTrip.startedAt).unwrap(or: PersistenceError.invalidState("Fecha inicial inválida."))
            let vehicleName = try repository.vehicles().first(where: { $0.id == storedTrip.vehicleID })?.displayName ?? "EuroGas"
            let storedParticipants = try repository.participantIDs(tripID: storedTrip.id)
            configuration = TripConfiguration(vehicleID: storedTrip.vehicleID, vehicleName: vehicleName, consumptionPer100: Decimal(string: storedTrip.profileConsumptionPer100) ?? 1, realWorldFactor: Decimal(string: storedTrip.profileRealWorldFactor) ?? 1, unitPrice: .init(milliEUR: storedTrip.fuelPriceMilliEUR), people: storedTrip.totalPeople, splitRule: storedTrip.splitRule == "everyone" ? .everyone : .passengersOnly, groupID: storedTrip.groupID, participantIDs: storedParticipants, origin: storedTrip.origin, destination: storedTrip.destination)
            distanceMeters = state.accumulator.acceptedDistanceMeters
            machine = TripStateMachine(phase: .interrupted); phase = .interrupted
            currentCost = MoneyCents(cents: storedTrip.energyCostCents)
            baseMovingSeconds = storedTrip.movingSeconds; pausedSeconds = storedTrip.pausedSeconds; basePausedSeconds = storedTrip.pausedSeconds
            activityID = await liveActivity.recover(id: state.liveActivityID, presentation: livePresentation())
            lastError = "Se recuperó lo guardado. El intervalo desde la última medición no se suma. Continúa o termina el viaje."
        } catch { fail(error) }
    }

    func discardRecovered() async {
        guard phase == .interrupted, let tripID else { return }
        do {
            try repository.deleteTrip(id: tripID)
            location.stopUpdates()
            await liveActivity.end(livePresentation())
            resetAfterCompletion()
        } catch { fail(error) }
    }

    private func handle(_ fix: LocationFix) async {
        guard phase == .starting || phase == .tracking else { return }
        if phase == .starting {
            do { try machine.apply(.firstFix); phase = machine.phase } catch { fail(error); return }
        }
        if stationaryDetector.observe(fix), phase == .tracking {
            do { try machine.apply(.pause(.stationary)); phase = machine.phase; pausedAt = monotonicClock.now; try saveCheckpoint(force: true); await liveActivity.update(livePresentation()) }
            catch { fail(error) }
            return
        }
        let result = filter.process(fix)
        if case .normal = result { recalculate() }
        if case .estimatedGap = result { recalculate() }
        distanceMeters = filter.snapshot.acceptedDistanceMeters
        do { try saveCheckpoint(force: false) } catch { fail(error) }
        await liveActivity.update(livePresentation())
    }

    private func recalculate() {
        guard let configuration else { return }
        do {
            currentCost = try CostEngine.calculate(.init(distanceMeters: filter.snapshot.acceptedDistanceMeters, consumptionPer100: configuration.consumptionPer100, realWorldFactor: configuration.realWorldFactor, unitPriceMilliEUR: configuration.unitPrice)).energyCostCents
        } catch { fail(error) }
    }

    private func saveCheckpoint(force: Bool) throws {
        guard let tripID else { return }
        let now = clock.now
        let dueByTime = lastCheckpointDate.map { now.timeIntervalSince($0) >= 10 } ?? true
        let dueByDistance = distanceMeters - lastCheckpointDistance >= 100
        guard force || dueByTime || dueByDistance else { return }
        checkpointSequence += 1
        let accumulator = filter.snapshot
        let active = ActiveTripState(tripID: TripID(tripID), sequence: checkpointSequence, savedAt: now, phase: phase, lastAcceptedFix: filter.lastAcceptedFix, accumulator: accumulator, lastMovementAt: filter.lastAcceptedFix?.timestamp, unmeasuredIntervalFlag: accumulator.unmeasuredIntervalCount > 0, liveActivityID: activityID)
        let energy = configuration.flatMap { try? CostEngine.calculate(.init(distanceMeters: distanceMeters, consumptionPer100: $0.consumptionPer100, realWorldFactor: $0.realWorldFactor, unitPriceMilliEUR: $0.unitPrice)).energyUnits } ?? 0
        try repository.checkpoint(.init(tripID: tripID, state: active, energyCost: currentCost, estimatedEnergy: energy, movingSeconds: movingDuration(), pausedSeconds: pausedSeconds))
        lastCheckpointDate = now; lastCheckpointDistance = distanceMeters
    }

    private func movingDuration() -> TimeInterval {
        guard let start = monotonicStart else { return 0 }
        return baseMovingSeconds + max(0, Self.seconds(start.duration(to: monotonicClock.now)) - (pausedSeconds - basePausedSeconds))
    }

    private func livePresentation() -> LiveTripPresentation {
        .init(tripID: tripID ?? "pending", vehicleName: configuration?.vehicleName ?? "EuroGas", startedAt: tripStartedAt ?? clock.now, costCents: currentCost.cents, distanceMeters: distanceMeters, totalPeople: configuration?.people ?? 1, phase: String(describing: phase))
    }

    private func fail(_ error: Error) { lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription }
    private func resetAfterCompletion() { phase = .idle; machine = TripStateMachine(); tripID = nil; tripStartedAt = nil; configuration = nil; filter = GPSFilter(); stationaryDetector = StationaryDetector(); distanceMeters = 0; currentCost = .zero; monotonicStart = nil; pausedAt = nil; pausedSeconds = 0; baseMovingSeconds = 0; basePausedSeconds = 0; activityID = nil }
    private static func isPaused(_ phase: TripPhase) -> Bool { if case .paused = phase { true } else { false } }
    private static func seconds(_ duration: Duration) -> TimeInterval { let parts = duration.components; return Double(parts.seconds) + Double(parts.attoseconds) / 1e18 }
}

private extension Optional {
    func unwrap(or error: @autoclosure () -> Error) throws -> Wrapped { guard let value = self else { throw error() }; return value }
}
