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

    // Напоминание
    @StateObject private var reminderManager = ReminderManager.shared
    @State private var editContext: ReminderEditContext?

    private struct ReminderEditContext: Identifiable {
        enum Kind {
            case current
            case preview
        }

        let kind: Kind
        let reminder: ClockReminder

        var id: UUID { reminder.id }
    }

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
                    // Слот напоминания (реальное или preview)
                    if let reminder = reminderManager.currentReminder {
                        // Показываем реальное напоминание
                        ReminderRow(
                            reminder: reminder,
                            isPreview: false,
                            onModeChange: { isDaily in
                                Task {
                                    await reminderManager.updateReminderRepeat(isDaily: isDaily)
                                }
                            },
                            onEdit: {
                                editContext = ReminderEditContext(kind: .current, reminder: reminder)
                            },
                            onRemove: {
                                reminderManager.deleteReminder()
                            },
                            onConfirm: nil
                        )
                        .frame(maxWidth: .infinity, alignment: .center)
                    } else if let preview = reminderManager.previewReminder {
                        // Показываем preview напоминание
                        ReminderRow(
                            reminder: preview,
                            isPreview: true,
                            onModeChange: nil,
                            onEdit: {
                                editContext = ReminderEditContext(kind: .preview, reminder: preview)
                            },
                            onRemove: {
                                reminderManager.clearPreviewReminder()
                            },
                            onConfirm: {
                                Task {
                                    await reminderManager.confirmPreview()
                                }
                            }
                        )
                        .frame(maxWidth: .infinity, alignment: .center)
                    }

                    if selectedEntries.isEmpty {
                        Text("No cities selected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(selectedEntries, id: \.id) { entry in
                                CityRow(
                                    entry: entry,
                                    isRemovable: entry.id != localCityIdentifier
                                ) {
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
        .sheet(item: $editContext) { context in
            EditReminderView(reminder: context.reminder) { hour, minute in
                Task { @MainActor in
                    switch context.kind {
                    case .current:
                        await reminderManager.updateReminderTime(hour: hour, minute: minute)
                    case .preview:
                        let updatedReminder = ClockReminder(
                            id: context.reminder.id,
                            hour: hour,
                            minute: minute,
                            date: context.reminder.date,
                            isEnabled: context.reminder.isEnabled
                        )
                        reminderManager.setPreviewReminder(updatedReminder)
                    }
                    editContext = nil
                }
            }
        }
    }
}

// MARK: - Cities selection helpers
extension SettingsView {
    private var localCityIdentifier: String {
        TimeZone.current.identifier
    }

    private func loadSelection() {
        var identifiers = selectedCityIdentifiers
            .split(separator: ",")
            .map { String($0) }

        if identifiers.isEmpty && !hasSeededDefaults {
            let defaults = WorldCity.initialSelectionIdentifiers()
            identifiers = defaults
            selectedCityIdentifiers = defaults.joined(separator: ",")
            hasSeededDefaults = true
        } else {
            let ensured = WorldCity.ensureLocalIdentifier(in: identifiers)
            if ensured != identifiers {
                identifiers = ensured
                selectedCityIdentifiers = ensured.joined(separator: ",")
            }
            if !identifiers.isEmpty {
                hasSeededDefaults = true
            }
        }

        let newSet = Set(identifiers)
        if newSet != selectedIds {
            selectedIds = newSet
        }
    }

    private func persistSelection() {
        if !selectedIds.contains(localCityIdentifier) {
            selectedIds.insert(localCityIdentifier)
        }

        let validIds = selectedIds.filter { TimeZone(identifier: $0) != nil }
        let others = validIds
            .filter { $0 != localCityIdentifier }
            .sorted {
                TimeZoneDirectory.displayName(forIdentifier: $0)
                    .localizedCaseInsensitiveCompare(TimeZoneDirectory.displayName(forIdentifier: $1)) == .orderedAscending
            }

        var ordered: [String] = []
        if TimeZone(identifier: localCityIdentifier) != nil {
            ordered.append(localCityIdentifier)
        }
        ordered.append(contentsOf: others)

        let sanitized = Set(ordered)
        if sanitized != selectedIds {
            selectedIds = sanitized
            return
        }

        selectedCityIdentifiers = ordered.joined(separator: ",")
        if !ordered.isEmpty {
            hasSeededDefaults = true
        }
        reloadWidgets()
    }

    private var selectedEntries: [TimeZoneDirectory.Entry] {
        return selectedIds.compactMap { id -> TimeZoneDirectory.Entry? in
            let name = TimeZoneDirectory.displayName(forIdentifier: id)
            let offset = TimeZoneDirectory.gmtOffsetString(for: id)
            return TimeZoneDirectory.Entry(id: id, name: name, gmtOffset: offset)
        }
        .sorted { lhs, rhs in
            if lhs.id == localCityIdentifier { return true }
            if rhs.id == localCityIdentifier { return false }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private func removeCity(_ identifier: String) {
        guard identifier != localCityIdentifier else { return }
        selectedIds.remove(identifier)
    }
}

private struct ReminderRow: View {
    let reminder: ClockReminder
    let isPreview: Bool
    let onModeChange: ((Bool) -> Void)?
    let onEdit: (() -> Void)?
    let onRemove: () -> Void
    let onConfirm: (() -> Void)?

    @State private var isDailyMode: Bool
    @Environment(\.colorScheme) private var colorScheme

    init(
        reminder: ClockReminder,
        isPreview: Bool,
        onModeChange: ((Bool) -> Void)?,
        onEdit: (() -> Void)?,
        onRemove: @escaping () -> Void,
        onConfirm: (() -> Void)?
    ) {
        self.reminder = reminder
        self.isPreview = isPreview
        self.onModeChange = onModeChange
        self.onEdit = onEdit
        self.onRemove = onRemove
        self.onConfirm = onConfirm
        _isDailyMode = State(initialValue: reminder.isDaily)
    }

    var body: some View {
        ZStack {
            // Центральный текст - строго по центру
            VStack(alignment: .center, spacing: 4) {
                Text(reminder.formattedTime)
                    .font(.headline)
                if let subtitle = subtitleText {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Кнопки поверх
            HStack(spacing: 0) {
                // Левая кнопка
                if let onModeChange = onModeChange {
                    Button {
                        isDailyMode.toggle()
                        onModeChange(isDailyMode)
                    } label: {
                        let borderColor: Color = colorScheme == .light ? .black : .white
                        let fillColor: Color = isDailyMode
                            ? (colorScheme == .light ? .black : .white)
                            : .clear
                        Circle()
                            .fill(fillColor)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .stroke(borderColor, lineWidth: 2)
                            )
                            .shadow(color: isDailyMode ? borderColor.opacity(0.25) : .clear, radius: 4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Toggle reminder repeat mode")
                }
                
                Spacer()
                
                // Правые кнопки
                HStack(spacing: 8) {
                    if isPreview, let onConfirm = onConfirm {
                        Button(action: onConfirm) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.green)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Confirm reminder")
                    }
                    
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isPreview ? "Cancel reminder" : "Remove reminder")
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.primary, lineWidth: 1)
        )
        .frame(maxWidth: 360)
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit?()
        }
        .onChange(of: reminder.isDaily) { _, newValue in
            if newValue != isDailyMode {
                isDailyMode = newValue
            }
        }
    }

    private var subtitleText: String? {
        if isPreview {
            return "Preview"
        }
        return isDailyMode ? "Every day" : "One time"
    }
}

private struct CityRow: View {
    let entry: TimeZoneDirectory.Entry
    let isRemovable: Bool
    let onRemove: () -> Void

    var body: some View {
        ZStack {
            // Центральный текст - строго по центру
            VStack(alignment: .center, spacing: 4) {
                Text(entry.name)
                    .font(.headline)
                Text(entry.gmtOffset)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            
            // Кнопка справа поверх
            HStack {
                Spacer()
                
                if isRemovable {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(entry.name)")
                } else {
                    Image(systemName: "location.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("\(entry.name) pinned")
                }
            }
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
                    selection.insert(localCityIdentifier)
                    onConfirm(selection)
                    dismiss()
                }
            }
#if os(iOS)
            ToolbarItem(placement: .bottomBar) {
                Button("Reset") {
                    selection = Set(WorldCity.initialSelectionIdentifiers())
                    selection.insert(localCityIdentifier)
                }
            }
#endif
        }
    }

    private func toggle(_ identifier: String) {
        if selection.contains(identifier) {
            if identifier == localCityIdentifier { return }
            selection.remove(identifier)
        } else {
            selection.insert(identifier)
        }
    }

    private var localCityIdentifier: String {
        TimeZone.current.identifier
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
            if identifier == localCityIdentifier { return }
            selection.remove(identifier)
        } else {
            selection.insert(identifier)
        }
        onChanged()
    }

    private var localCityIdentifier: String {
        TimeZone.current.identifier
    }
}

// MARK: - Edit Reminder View
private struct EditReminderView: View {
    let reminder: ClockReminder
    let onSave: (Int, Int) -> Void
    
    @State private var selectedHour: Int
    @State private var selectedMinute: Int
    @Environment(\.dismiss) private var dismiss
    
    init(reminder: ClockReminder, onSave: @escaping (Int, Int) -> Void) {
        self.reminder = reminder
        self.onSave = onSave
        self._selectedHour = State(initialValue: reminder.hour)
        self._selectedMinute = State(initialValue: reminder.minute)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Редактировать напоминание")
                    .font(.title2)
                    .padding(.top)
                
                HStack {
                    Picker("Час", selection: $selectedHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(String(format: "%02d", hour)).tag(hour)
                        }
                    }
                    #if os(iOS)
                    .pickerStyle(.wheel)
                    #endif
                    .frame(width: 80)
                    
                    Text(":")
                        .font(.title)
                    
                    Picker("Минута", selection: $selectedMinute) {
                        ForEach([0, 15, 30, 45], id: \.self) { minute in
                            Text(String(format: "%02d", minute)).tag(minute)
                        }
                    }
                    #if os(iOS)
                    .pickerStyle(.wheel)
                    #endif
                    .frame(width: 80)
                }
                .padding()
                
                Spacer()
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Сохранить") {
                        onSave(selectedHour, selectedMinute)
                    }
                    .fontWeight(.semibold)
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        onSave(selectedHour, selectedMinute)
                    }
                    .fontWeight(.semibold)
                }
                #endif
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ContentView()
}
