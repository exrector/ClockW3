import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif

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
    // Выбор городов (используем SharedUserDefaults для синхронизации с виджетом)
    @AppStorage(
        SharedUserDefaults.selectedCitiesKey,
        store: SharedUserDefaults.shared
    ) private var selectedCityIdentifiers: String = ""
    @State private var selectedIds: Set<String> = []
    @State private var showTimeZonePicker = false
    @AppStorage(
        SharedUserDefaults.seededDefaultsKey,
        store: SharedUserDefaults.shared
    ) private var hasSeededDefaults: Bool = false

    // Цветовая схема (используем SharedUserDefaults для синхронизации с виджетом)
    @AppStorage(
        SharedUserDefaults.colorSchemeKey,
        store: SharedUserDefaults.shared
    ) private var colorSchemePreference: String = "system"

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 12) {
                    Picker("", selection: $colorSchemePreference) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 260)
                    .accessibilityLabel("Color scheme")
                }
                .frame(maxWidth: .infinity, alignment: .center)

                VStack(spacing: 16) {
                    if selectedEntries.isEmpty {
                        Text("No cities selected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(selectedEntries, id: \.id) { entry in
                                CityRow(entry: entry) {
                                    removeCity(entry.id)
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                    }

#if os(iOS)
                    Button {
                        showTimeZonePicker = true
                    } label: {
                        Label("Choose Cities", systemImage: "globe")
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: 360)
#elseif os(macOS)
                    // В macOS показываем выбор городов инлайн с ограниченной высотой
                    VStack(spacing: 0) {
                        DisclosureGroup {
                            TimeZoneSelectionInlineView(selection: $selectedIds, onChanged: persistSelection)
                                .frame(maxHeight: 300)
                        } label: {
                            Text("Choose Cities")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .frame(maxWidth: 360)
                    .padding(.top, 8)
#endif
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 36)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { loadSelection() }
        .onChange(of: selectedIds) { _, _ in
            persistSelection()
        }
        .onChange(of: colorSchemePreference) { _, _ in
            reloadWidgets()
        }
        .sheet(isPresented: $showTimeZonePicker) {
            NavigationStack {
                TimeZoneSelectionView(selection: $selectedIds) { newSelection in
                    selectedIds = newSelection
                }
            }
#if os(iOS)
            .presentationDetents([.fraction(0.5)])
            .presentationDragIndicator(.hidden)
            .interactiveDismissDisabled(false)
#elseif os(macOS)
            .presentationDetents([.fraction(0.55)])
#endif
        }
    }
}

// MARK: - Cities selection helpers
extension SettingsView {
    private func loadSelection() {
        let ids = selectedCityIdentifiers.split(separator: ",").map { String($0) }
        if ids.isEmpty && !hasSeededDefaults {
            let defaults = WorldCity.recommendedTimeZoneIdentifiers
            selectedIds = Set(defaults)
            hasSeededDefaults = true
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
        if !sorted.isEmpty {
            hasSeededDefaults = true
        }
        reloadWidgets()
    }

    private var selectedEntries: [TimeZoneDirectory.Entry] {
        selectedIds.compactMap { id -> TimeZoneDirectory.Entry? in
            let name = TimeZoneDirectory.displayName(forIdentifier: id)
            let offset = TimeZoneDirectory.gmtOffsetString(for: id)
            return TimeZoneDirectory.Entry(id: id, name: name, gmtOffset: offset)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func removeCity(_ identifier: String) {
        selectedIds.remove(identifier)
        persistSelection()
    }
}

private struct CityRow: View {
    let entry: TimeZoneDirectory.Entry
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .center, spacing: 4) {
                Text(entry.name)
                    .font(.headline)
                Text(entry.gmtOffset)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(entry.name)")
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.primary, lineWidth: 1)
        )
        .frame(maxWidth: 360)
    }
}

#if canImport(WidgetKit)
private extension SettingsView {
    func reloadWidgets() {
        WidgetCenter.shared.reloadTimelines(ofKind: "ClockW3Widget")
    }
}
#else
private extension SettingsView {
    func reloadWidgets() {}
}
#endif

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

// MARK: - Time Zone Selection Inline View (for macOS)
struct TimeZoneSelectionInlineView: View {
    @Binding var selection: Set<String>
    let onChanged: () -> Void
    @State private var searchText = ""

    private let entries = TimeZoneDirectory.allEntries()

    private var filteredEntries: [TimeZoneDirectory.Entry] {
        guard !searchText.isEmpty else { return entries }
        return entries.filter { entry in
            entry.name.localizedCaseInsensitiveContains(searchText) ||
            entry.gmtOffset.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            TextField("Search cities...", text: $searchText)
                .textFieldStyle(.roundedBorder)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredEntries) { entry in
                        Button {
                            toggle(entry.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.name)
                                        .font(.body)
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
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 4)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    private func toggle(_ identifier: String) {
        if selection.contains(identifier) {
            selection.remove(identifier)
        } else {
            selection.insert(identifier)
        }
        onChanged()
    }
}

// MARK: - Preview
#Preview {
    ContentView()
}
