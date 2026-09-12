import SwiftUI
import Persistence

struct PeopleView: View {
    @ObservedObject var model: AppModel
    @State private var name = ""
    @State private var groupName = ""
    @State private var selection: Set<String> = [SystemIDs.owner]

    var body: some View {
        List {
            Section("Personas") {
                ForEach(model.people) { person in Label(person.name, systemImage: person.isOwner ? "person.crop.circle.fill" : "person.crop.circle") }
                HStack { TextField("Nueva persona", text: $name); Button("Añadir") { addPerson() }.disabled(!model.isPro || name.isEmpty) }
            }
            Section("Grupos") {
                ForEach(model.groups.filter { !$0.isUngrouped }) { Text($0.name) }
                TextField("Nombre del grupo", text: $groupName)
                ForEach(model.people) { person in Toggle(person.name, isOn: Binding(get: { selection.contains(person.id) }, set: { $0 ? selection.insert(person.id) : selection.remove(person.id) })).disabled(person.isOwner) }
                Button("Crear grupo") { addGroup() }.disabled(!model.isPro || groupName.isEmpty)
            }
            if !model.isPro { Section { Text("Crear personas, grupos y nuevos cargos requiere Pro. Tus datos existentes siguen visibles y exportables.").foregroundStyle(.secondary) } }
        }.navigationTitle("Personas y grupos")
    }

    private func addPerson() {
        do { let id = try model.container.repository.createPerson(name: name, emoji: nil, now: model.container.clock.now); selection.insert(id); name = ""; model.refresh() }
        catch { model.errorMessage = error.localizedDescription }
    }
    private func addGroup() {
        do { _ = try model.container.repository.createGroup(name: groupName, memberIDs: Array(selection), now: model.container.clock.now); groupName = ""; model.refresh() }
        catch { model.errorMessage = error.localizedDescription }
    }
}
