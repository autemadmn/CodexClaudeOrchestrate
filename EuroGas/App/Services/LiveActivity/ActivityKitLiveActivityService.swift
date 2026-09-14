@preconcurrency import ActivityKit
import Foundation
import EuroGasShared

@MainActor
final class ActivityKitLiveActivityService: LiveActivityService {
    private var activity: Activity<TripActivityAttributes>?

    func start(_ presentation: LiveTripPresentation) async throws -> String? {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return nil }
        let attributes = TripActivityAttributes(tripID: presentation.tripID, vehicleName: presentation.vehicleName, startedAt: presentation.startedAt)
        activity = try Activity.request(attributes: attributes, content: .init(state: state(presentation), staleDate: Date().addingTimeInterval(30)), pushType: nil)
        return activity?.id
    }

    func update(_ presentation: LiveTripPresentation) async {
        await activity?.update(using: state(presentation))
    }

    func end(_ presentation: LiveTripPresentation) async {
        await activity?.end(using: state(presentation), dismissalPolicy: .after(Date().addingTimeInterval(60)))
        activity = nil
    }

    func recover(id: String?, presentation: LiveTripPresentation) async -> String? {
        if let id, let existing = Activity<TripActivityAttributes>.activities.first(where: { $0.id == id }) {
            activity = existing
            await update(presentation)
            return id
        }
        return try? await start(presentation)
    }

    private func state(_ value: LiveTripPresentation) -> TripActivityAttributes.ContentState {
        .init(costCents: value.costCents, distanceMeters: value.distanceMeters, totalPeople: value.totalPeople, indicativeShareCents: value.totalPeople > 0 ? value.costCents / Int64(value.totalPeople) : 0, phase: value.phase, lastUpdatedAt: Date())
    }
}
