import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif
import UserNotifications
#if os(macOS)
import AppKit
#endif

// MARK: - Async compatibility helpers for UNUserNotificationCenter
private extension UNUserNotificationCenter {
    func notificationSettingsCompat() async -> UNNotificationSettings {
        #if os(macOS)
        if #available(macOS 12.0, *) {
            return await self.notificationSettings()
        } else {
            return await withCheckedContinuation { continuation in
                self.getNotificationSettings { settings in
                    continuation.resume(returning: settings)
                }
            }
        }
        #else
        if #available(iOS 15.0, *) {
            return await self.notificationSettings()
        } else {
            return await withCheckedContinuation { continuation in
                self.getNotificationSettings { settings in
                    continuation.resume(returning: settings)
                }
            }
        }
        #endif
    }

    func pendingNotificationRequestsCompat() async -> [UNNotificationRequest] {
        #if os(macOS)
        if #available(macOS 12.0, *) {
            return await self.pendingNotificationRequests()
        } else {
            return await withCheckedContinuation { continuation in
                self.getPendingNotificationRequests { requests in
                    continuation.resume(returning: requests)
                }
            }
        }
        #else
        if #available(iOS 15.0, *) {
            return await self.pendingNotificationRequests()
        } else {
            return await withCheckedContinuation { continuation in
                self.getPendingNotificationRequests { requests in
                    continuation.resume(returning: requests)
                }
            }
        }
        #endif
    }
}

// MARK: - AppDelegate with Notifications setup
#if os(macOS)
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupNotifications()
    }

    private func setupNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        Task { @MainActor in
            _ = await ReminderManager.shared.requestPermission()

            // Если пользователь только что дал разрешение и у нас уже есть сохранённое напоминание — пересоздадим расписание
            if let reminder = ReminderManager.shared.currentReminder, reminder.isEnabled {
                await ReminderManager.shared.setReminder(reminder)
            }
        }
    }

    // Показывать баннер/звук, даже если приложение активно
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if #available(macOS 11.0, *) {
            completionHandler([.banner, .list, .sound])
        } else {
            completionHandler([.alert, .sound])
        }
    }
}
#else
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        setupNotifications()
        return true
    }

    private func setupNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        Task { @MainActor in
            _ = await ReminderManager.shared.requestPermission()
            if let reminder = ReminderManager.shared.currentReminder, reminder.isEnabled {
                await ReminderManager.shared.setReminder(reminder)
            }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .list, .sound])
        } else {
            completionHandler([.alert, .sound])
        }
    }
}
#endif

// MARK: - SwiftUI Clock App
@main
struct SwiftUIClockApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #else
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

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
    @State private var selectedEntries: [TimeZoneDirectory.Entry] = []
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
    
    @Environment(\.colorScheme) private var colorScheme

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
                
                // Кнопка тестирования уведомления
                #if DEBUG
                Button {
                    Task {
                        await testNotification()
                    }
                } label: {
                    Label("Test Notification", systemImage: "bell.badge")
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: 360)
                .padding(.top, 8)
                #endif
                
                // Три пузыря для выбора темы внизу
                HStack(spacing: 16) {
                    ColorSchemeButton(
                        title: "System",
                        systemImage: "circle.lefthalf.filled",
                        isSelected: colorSchemePreference == "system",
                        colorScheme: colorScheme
                    ) {
                        colorSchemePreference = "system"
                    }
                    
                    ColorSchemeButton(
                        title: "Light",
                        systemImage: "sun.max.fill",
                        isSelected: colorSchemePreference == "light",
                        colorScheme: colorScheme
                    ) {
                        colorSchemePreference = "light"
                    }
                    
                    ColorSchemeButton(
                        title: "Dark",
                        systemImage: "moon.fill",
                        isSelected: colorSchemePreference == "dark",
                        colorScheme: colorScheme
                    ) {
                        colorSchemePreference = "dark"
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 16)
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
        
        // Обновляем список городов
        updateSelectedEntries()
    }
    
    private func updateSelectedEntries() {
        selectedEntries = selectedIds.compactMap { id -> TimeZoneDirectory.Entry? in
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
        updateSelectedEntries()
        reloadWidgets()
    }

    private func removeCity(_ identifier: String) {
        guard identifier != localCityIdentifier else { return }
        selectedIds.remove(identifier)
        updateSelectedEntries()
    }
    
    private func testNotification() async {
        let content = UNMutableNotificationContent()
        content.title = "Напоминание"
        content.body = "Время \(Date().formatted(date: .omitted, time: .shortened))"
        content.sound = UNNotificationSound.default
        
        // Триггер через 5 секунд
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: "test_notification", content: content, trigger: trigger)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            // Error handling for notification
        }
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
            // Фоновая кнопка для редактирования (занимает все пространство)
            Button {
                onEdit?()
            } label: {
                Color.clear
            }
            .buttonStyle(.plain)
            
            // Содержимое
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
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle()
                                    .stroke(borderColor, lineWidth: 1.5)
                            )
                            .shadow(color: isDailyMode ? borderColor.opacity(0.25) : .clear, radius: 3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Toggle reminder repeat mode")
                }
                
                Spacer()
                
                // Центральный текст (не кликабельный, клики проходят через него к фоновой кнопке)
                VStack(alignment: .center, spacing: 4) {
                    Text(reminder.formattedTime)
                        .font(.headline)
                        .foregroundColor(isPreview ? .primary : .red)
                    if let subtitle = subtitleText {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .allowsHitTesting(false)
                
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
        // Проверяем что значение действительно записалось в SharedUserDefaults
        if SharedUserDefaults.shared.string(forKey: SharedUserDefaults.colorSchemeKey) != nil {
        } else {
        }
        
        // Принудительно синхронизируем
        SharedUserDefaults.shared.synchronize()
        
        // Перезагружаем виджеты
        WidgetCenter.shared.reloadAllTimelines()
        
        // Также попробуем перезагрузить конкретный kind
        WidgetCenter.shared.reloadTimelines(ofKind: "MOWWidget")
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

// MARK: - Color Scheme Button
private struct ColorSchemeButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let colorScheme: ColorScheme
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? (colorScheme == .light ? Color.black : Color.white) : Color.clear)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(colorScheme == .light ? Color.black : Color.white, lineWidth: 2)
                        )
                        .shadow(color: isSelected ? (colorScheme == .light ? Color.black.opacity(0.25) : Color.white.opacity(0.25)) : .clear, radius: 4)
                    
                    Image(systemName: systemImage)
                        .font(.title2)
                        .foregroundColor(isSelected ? (colorScheme == .light ? .white : .black) : (colorScheme == .light ? .black : .white))
                }
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(colorScheme == .light ? .black : .white)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) color scheme")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Preview
#Preview {
    ContentView()
}
