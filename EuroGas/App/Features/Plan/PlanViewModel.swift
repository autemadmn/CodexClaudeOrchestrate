import Foundation

@MainActor
final class PlanViewModel: ObservableObject {
    @Published private(set) var route: RouteSummary?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    private let routing: RoutingService
    init(routing: RoutingService) { self.routing = routing }
    func plan(origin: String, destination: String) async {
        isLoading = true; defer { isLoading = false }
        do { route = try await routing.route(.init(origin: origin, destination: destination)).first; errorMessage = nil }
        catch { route = nil; errorMessage = error.localizedDescription }
    }
}
