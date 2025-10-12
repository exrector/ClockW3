import SwiftUI

// MARK: - SwiftUI Clock App
@main
struct SwiftUIClockApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}



// MARK: - Settings View
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    // Выбор городов
    @AppStorage("selectedCityIdentifiers") private var selectedCityIdentifiers: String = ""
    @State private var selectedIds: Set<String> = []
    @State private var showTimeZonePicker = false

    // Цветовая схема
    @AppStorage("colorSchemePreference") private var colorSchemePreference: String = "system"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Appearance
                GroupBox("Appearance") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Color Scheme", selection: $colorSchemePreference) {
                            Text("System").tag("system")
                            Text("Light").tag("light")
                            Text("Dark").tag("dark")
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(8)
                }

                // Cities
                GroupBox("Cities") {
                    VStack(alignment: .leading, spacing: 12) {
                        if selectedIds.isEmpty {
                            Text("No cities selected")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(sortedSelectedEntries, id: \.id) { entry in
                                Text(entry.displayName)
                                    .font(.subheadline)
                            }
                        }

                        Button {
                            showTimeZonePicker = true
                        } label: {
                            Label("Choose Cities", systemImage: "globe")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { loadSelection() }
        .sheet(isPresented: $showTimeZonePicker) {
            NavigationStack {
                TimeZoneSelectionView(selection: $selectedIds) { newSelection in
                    selectedIds = newSelection
                    persistSelection()
                    showTimeZonePicker = false
                }
            }
#if os(iOS)
            .presentationDetents([.fraction(0.5)])
            .presentationDragIndicator(.visible)
#endif
        }
    }
}

// MARK: - Cities selection helpers
extension SettingsView {
    private func loadSelection() {
        let ids = selectedCityIdentifiers.split(separator: ",").map { String($0) }
        if ids.isEmpty {
            selectedIds = Set(WorldCity.recommendedTimeZoneIdentifiers)
            persistSelection()
        } else {
            selectedIds = Set(ids)
        }
    }

    private func persistSelection() {
        let sorted = selectedIds.sorted { lhs, rhs in
            TimeZoneDirectory.displayName(forIdentifier: lhs)
                .localizedCaseInsensitiveCompare(TimeZoneDirectory.displayName(forIdentifier: rhs)) == .orderedAscending
        }
        selectedCityIdentifiers = sorted.joined(separator: ",")
    }

    private var sortedSelectedEntries: [TimeZoneDirectory.Entry] {
        selectedIds.compactMap { id -> TimeZoneDirectory.Entry? in
            let name = TimeZoneDirectory.displayName(forIdentifier: id)
            let offset = TimeZoneDirectory.gmtOffsetString(for: id)
            return TimeZoneDirectory.Entry(id: id, name: name, gmtOffset: offset)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

// MARK: - Time Zone Picker
struct TimeZoneSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @Binding var selection: Set<String>
    let onConfirm: (Set<String>) -> Void

    private let entries = TimeZoneDirectory.allEntries()

    private var filteredEntries: [TimeZoneDirectory.Entry] {
        guard !searchText.isEmpty else { return entries }
        return entries.filter { entry in
            entry.name.localizedCaseInsensitiveContains(searchText) ||
            entry.gmtOffset.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List(filteredEntries) { entry in
            Button {
                toggle(entry.id)
            } label: {
                HStack {
                    VStack(alignment: .leading) {
                        Text(entry.name)
                        Text(entry.gmtOffset)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if selection.contains(entry.id) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .navigationTitle("Select Cities")
        .searchable(text: $searchText)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    onConfirm(selection)
                    dismiss()
                }
            }
#if os(iOS)
            ToolbarItem(placement: .bottomBar) {
                Button("Reset") {
                    selection = Set(WorldCity.recommendedTimeZoneIdentifiers)
                }
            }
#endif
        }
    }

    private func toggle(_ identifier: String) {
        if selection.contains(identifier) {
            selection.remove(identifier)
        } else {
            selection.insert(identifier)
        }
    }
}

// MARK: - Preview
#Preview {
    ContentView()
}
