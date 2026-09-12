import ActivityKit
import WidgetKit
import SwiftUI
import EuroGasShared

@main
struct EuroGasWidgets: WidgetBundle {
    var body: some Widget { TripLiveActivity() }
}

struct TripLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TripActivityAttributes.self) { context in
            HStack {
                VStack(alignment: .leading) {
                    Text(context.attributes.vehicleName).font(.headline)
                    Text(context.state.phase).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(money(context.state.costCents)).font(.title2.bold())
                    Text("\(context.state.distanceMeters / 1000, specifier: "%.1f") km")
                }
            }.padding().activityBackgroundTint(.black.opacity(0.85)).activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Label("EuroGas", systemImage: "car.fill") }
                DynamicIslandExpandedRegion(.trailing) { Text(money(context.state.costCents)).fontWeight(.semibold) }
                DynamicIslandExpandedRegion(.bottom) { Text("\(context.state.distanceMeters / 1000, specifier: "%.1f") km · desde \(money(context.state.indicativeShareCents))/persona") }
            } compactLeading: { Image(systemName: "car.fill") }
              compactTrailing: { Text(money(context.state.costCents)) }
              minimal: { Image(systemName: "car.fill") }
              .keylineTint(.green)
        }
    }

    private func money(_ cents: Int64) -> String { (Double(cents) / 100).formatted(.currency(code: "EUR").locale(Locale(identifier: "es_ES"))) }
}
