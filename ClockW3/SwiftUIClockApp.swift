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
#if os(macOS)
        .defaultSize(width: 893, height: 500)
        .windowResizability(.contentSize)
#endif
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
    @State private var showMacOSCityPicker = false
    @AppStorage(
        SharedUserDefaults.seededDefaultsKey,
        store: SharedUserDefaults.shared
    ) private var hasSeededDefaults: Bool = false

    // Цветовая схема (используем SharedUserDefaults для синхронизации с виджетом)
    @AppStorage(
        SharedUserDefaults.colorSchemeKey,
        store: SharedUserDefaults.shared
    ) private var colorSchemePreference: String = "system"

#if os(macOS)
    // Ориентация окна для macOS
    @AppStorage(
        SharedUserDefaults.windowOrientationKey,
        store: SharedUserDefaults.shared
    ) private var windowOrientationPreference: String = "landscape"
#endif
    
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
        VStack(spacing: 0) {
            // ВЕРХНИЙ БЛОК (фиксированный) - Напоминание с винтиками
            VStack(spacing: 16) {
                if let reminder = reminderManager.currentReminder {
#if os(iOS)
                    let modeChangeHandler: ((Bool) -> Void)? = { isDaily in
                        Task {
                            await reminderManager.updateReminderRepeat(isDaily: isDaily)
                        }
                    }
                    let liveActivityHandler: ((Bool) -> Void)? = { isEnabled in
                        Task {
                            await reminderManager.updateLiveActivityEnabled(isEnabled: isEnabled)
                        }
                    }
                    let criticalHandler: ((Bool) -> Void)? = { isEnabled in
                        Task {
                            await reminderManager.updateCriticalEnabled(isEnabled: isEnabled)
                        }
                    }
                    let alwaysLiveActivityHandler: ((Bool) -> Void)? = { isEnabled in
                        Task {
                            await reminderManager.updateAlwaysLiveActivity(isEnabled: isEnabled)
                        }
                    }

                    ReminderRow(
                        reminder: reminder,
                        isPreview: false,
                        onModeChange: modeChangeHandler,
                        onLiveActivityToggle: liveActivityHandler,
                        onAlwaysLiveActivityToggle: alwaysLiveActivityHandler,
                        onCriticalToggle: criticalHandler,
                        onEdit: {
                            editContext = ReminderEditContext(kind: .current, reminder: reminder)
                        },
                        onRemove: {
                            reminderManager.deleteReminder()
                        },
                        onConfirm: nil
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
#else
                    let modeChangeHandler: ((Bool) -> Void)? = { isDaily in
                        Task {
                            await reminderManager.updateReminderRepeat(isDaily: isDaily)
                        }
                    }

                    ReminderRow(
                        reminder: reminder,
                        isPreview: false,
                        onModeChange: modeChangeHandler,
                        onEdit: {
                            editContext = ReminderEditContext(kind: .current, reminder: reminder)
                        },
                        onRemove: {
                            reminderManager.deleteReminder()
                        },
                        onConfirm: nil
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
#endif
                } else if let preview = reminderManager.previewReminder {
#if os(iOS)
                    ReminderRow(
                        reminder: preview,
                        isPreview: true,
                        onModeChange: nil,
                        onLiveActivityToggle: nil,
                        onAlwaysLiveActivityToggle: nil,
                        onCriticalToggle: nil,
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
#else
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
#endif
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            // НИЖНИЙ БЛОК (прокручиваемый) - Города и настройки темы
            ScrollView {
                VStack(spacing: 16) {
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
                        HStack(spacing: 8) {
                            Image(systemName: "globe")
                                .font(.body)
                            Text("Choose Cities")
                                .font(.body)
                        }
                        .foregroundStyle(colorScheme == .light ? .black : .white)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color.primary, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: 360)
#elseif os(macOS)
                    // В macOS показываем выбор городов инлайн с ограниченной высотой
                    VStack(spacing: 0) {
                        Button {
                            showMacOSCityPicker.toggle()
                        } label: {
                            HStack(spacing: 8) {
                                Spacer()
                                Image(systemName: showMacOSCityPicker ? "chevron.down" : "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Choose Cities")
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if showMacOSCityPicker {
                            TimeZoneSelectionInlineView(selection: $selectedIds, onChanged: persistSelection)
                                .frame(maxHeight: 300)
                        }
                    }
                    .frame(maxWidth: 360)
                    .padding(.top, 8)
#endif

                    // Пузыри для выбора темы и ориентации (на macOS)
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

#if os(macOS)
                        ColorSchemeButton(
                            title: "Portrait",
                            systemImage: "rectangle.portrait",
                            isSelected: windowOrientationPreference == "portrait",
                            colorScheme: colorScheme
                        ) {
                            windowOrientationPreference = "portrait"
                        }

                        ColorSchemeButton(
                            title: "Landscape",
                            systemImage: "rectangle",
                            isSelected: windowOrientationPreference == "landscape",
                            colorScheme: colorScheme
                        ) {
                            windowOrientationPreference = "landscape"
                        }
#endif
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 16)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onAppear { loadSelection() }
        .onChange(of: selectedIds) { _, _ in
            persistSelection()
        }
        .onChange(of: selectedCityIdentifiers) { _, _ in
            loadSelection()
        }
        .onChange(of: colorSchemePreference) { _, newValue in
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
                            isEnabled: context.reminder.isEnabled,
                            liveActivityEnabled: context.reminder.liveActivityEnabled,
                            alwaysLiveActivity: context.reminder.alwaysLiveActivity,
                            isCritical: context.reminder.isCritical
                        )
                        reminderManager.setPreviewReminder(updatedReminder)
                    }
                    editContext = nil
                }
            }
#if os(iOS)
            .presentationDetents([.height(380)])
            .presentationDragIndicator(.hidden)
#endif
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
}

private struct ReminderRow: View {
    let reminder: ClockReminder
    let isPreview: Bool
    let onModeChange: ((Bool) -> Void)?
    let onLiveActivityToggle: ((Bool) -> Void)?
    let onAlwaysLiveActivityToggle: ((Bool) -> Void)?
    let onCriticalToggle: ((Bool) -> Void)?
    let onEdit: (() -> Void)?
    let onRemove: () -> Void
    let onConfirm: (() -> Void)?

    @State private var isDailyMode: Bool
#if os(iOS)
    @State private var isLiveActivityEnabled: Bool
    @State private var isAlwaysLiveActivity: Bool
    @State private var isCriticalEnabled: Bool
#endif
    @Environment(\.colorScheme) private var colorScheme

    init(
        reminder: ClockReminder,
        isPreview: Bool,
        onModeChange: ((Bool) -> Void)?,
        onLiveActivityToggle: ((Bool) -> Void)? = nil,
        onAlwaysLiveActivityToggle: ((Bool) -> Void)? = nil,
        onCriticalToggle: ((Bool) -> Void)? = nil,
        onEdit: (() -> Void)?,
        onRemove: @escaping () -> Void,
        onConfirm: (() -> Void)?
    ) {
        self.reminder = reminder
        self.isPreview = isPreview
        self.onModeChange = onModeChange
        self.onLiveActivityToggle = onLiveActivityToggle
        self.onAlwaysLiveActivityToggle = onAlwaysLiveActivityToggle
        self.onCriticalToggle = onCriticalToggle
        self.onEdit = onEdit
        self.onRemove = onRemove
        self.onConfirm = onConfirm
        _isDailyMode = State(initialValue: reminder.isDaily)
#if os(iOS)
        _isLiveActivityEnabled = State(initialValue: reminder.liveActivityEnabled)
        _isAlwaysLiveActivity = State(initialValue: reminder.alwaysLiveActivity)
        _isCriticalEnabled = State(initialValue: reminder.isCritical)
#endif
    }

    var body: some View {
        ZStack {
            // Центр - только таймер
            Button {
                onEdit?()
            } label: {
                Text(reminder.formattedTime)
                    .font(.headline)
                    .foregroundColor(isPreview ? .primary : .red)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit reminder time")

            HStack {
                let borderColor: Color = colorScheme == .light ? .black : .white
                HStack(spacing: 12) {
                    if let onModeChange = onModeChange {
                        Button {
#if os(iOS)
                            // Блокируем переключение на Every day если включен Critical
                            guard !isCriticalEnabled else { return }
#endif
                            isDailyMode.toggle()
                            onModeChange(isDailyMode)
                            // При переключении на ежедневный режим автоматически выключаем Live Activity
#if os(iOS)
                            if isDailyMode && isLiveActivityEnabled {
                                isLiveActivityEnabled = false
                                onLiveActivityToggle?(false)
                            }
#endif
                        } label: {
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
                                .overlay(
                                    Image(systemName: isDailyMode ? "infinity" : "1.circle.fill")
                                        .font(.system(size: isDailyMode ? 10 : 9, weight: .semibold))
                                        .foregroundStyle(isDailyMode ? (colorScheme == .light ? .white : .black) : borderColor)
                                )
                                .shadow(color: isDailyMode ? borderColor.opacity(0.25) : .clear, radius: 3)
                                .contentShape(Circle())
#if os(iOS)
                                .opacity(isCriticalEnabled ? 0.3 : 1.0)
#endif
                        }
                        .buttonStyle(.plain)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
#if os(iOS)
                        .disabled(isCriticalEnabled)
#endif
                        .accessibilityLabel("Toggle reminder repeat mode")
                    }

#if os(iOS)
                    if let onLiveActivityToggle = onLiveActivityToggle, !isPreview {
                        Button {
                            // Обычное нажатие - toggle как обычно
                            guard !isDailyMode && !isAlwaysLiveActivity else { return }
                            isLiveActivityEnabled.toggle()
                            onLiveActivityToggle(isLiveActivityEnabled)
                        } label: {
                            Circle()
                                .fill(isLiveActivityEnabled ? (colorScheme == .light ? .black : .white) : .clear)
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Circle()
                                        .stroke(borderColor, lineWidth: isAlwaysLiveActivity ? 2.0 : 1.5)
                                )
                                .overlay(
                                    Image(systemName: isAlwaysLiveActivity ? "infinity" : "waveform.path.ecg")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(isLiveActivityEnabled ? (colorScheme == .light ? .white : .black) : borderColor)
                                )
                                .shadow(color: isLiveActivityEnabled ? borderColor.opacity(0.25) : .clear, radius: 3)
                                .opacity((isDailyMode && !isAlwaysLiveActivity) ? 0.3 : 1.0)
                        }
                        .buttonStyle(.plain)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                        .disabled(isDailyMode && !isAlwaysLiveActivity)
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.5)
                                .onEnded { _ in
                                    // Long press - включаем/выключаем always-on режим
                                    isAlwaysLiveActivity.toggle()
                                    onAlwaysLiveActivityToggle?(isAlwaysLiveActivity)
                                    // Генерируем тактильный отклик
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
                                }
                        )
                        .accessibilityLabel("Toggle Live Activity")
                    }

                    if let onCriticalToggle = onCriticalToggle, !isPreview {
                        Button {
                            isCriticalEnabled.toggle()
                            onCriticalToggle(isCriticalEnabled)
                            // При включении Critical автоматически переключаем на One time
                            if isCriticalEnabled && isDailyMode {
                                isDailyMode = false
                                onModeChange?(false)
                            }
                        } label: {
                            Circle()
                                .fill(isCriticalEnabled ? .red : .clear)
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Circle()
                                        .stroke(isCriticalEnabled ? .red : borderColor, lineWidth: 1.5)
                                )
                                .overlay(
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(isCriticalEnabled ? .white : borderColor)
                                )
                                .shadow(color: isCriticalEnabled ? .red.opacity(0.4) : .clear, radius: 3)
                        }
                        .buttonStyle(.plain)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                        .accessibilityLabel("Toggle Critical Alert")
                    }
#endif
                }

                Spacer()

                // Статусы (три строки) - всегда присутствуют для сохранения размера
                VStack(alignment: .trailing, spacing: 2) {
                    if !isPreview {
#if os(iOS)
                        // Строка 1: Every day / One time (всегда показывается)
                        Text(isDailyMode ? "Every day" : "One time")
                            .font(.caption2)
                            .foregroundStyle(.primary)

                        // Строка 2: Live Activity (всегда занимает место)
                        if onLiveActivityToggle != nil {
                            if isLiveActivityEnabled {
                                HStack(spacing: 2) {
                                    if isAlwaysLiveActivity {
                                        Image(systemName: "infinity")
                                            .font(.system(size: 8))
                                            .foregroundStyle(.primary)
                                    }
                                    Text("Live Activity")
                                        .font(.caption2)
                                        .foregroundStyle(.primary)
                                }
                            } else {
                                // Placeholder для сохранения высоты
                                Text("Live Activity")
                                    .font(.caption2)
                                    .foregroundStyle(.clear)
                            }
                        }

                        // Строка 3: Critical (всегда занимает место)
                        if onCriticalToggle != nil {
                            Text("Critical")
                                .font(.caption2)
                                .foregroundStyle(isCriticalEnabled ? .red : .clear)
                        }
#else
                        // macOS: Строка 1 - пустая
                        Text(" ")
                            .font(.caption2)
                            .foregroundStyle(.clear)

                        // Строка 2: Every day / One time (центральная строка)
                        Text(isDailyMode ? "Every day" : "One time")
                            .font(.caption2)
                            .foregroundStyle(.primary)

                        // Строка 3 - пустая
                        Text(" ")
                            .font(.caption2)
                            .foregroundStyle(.clear)
#endif
                    } else {
                        // Placeholder для preview - показываем "PREVIEW" в центральной строке
                        Text(" ")
                            .font(.caption2)
                        Text("PREVIEW")
                            .font(.caption2)
                            .foregroundStyle(.red)
                        Text(" ")
                            .font(.caption2)
                    }
                }

                // Одна кнопка: галочка для preview, крестик для созданного
                if isPreview, let onConfirm = onConfirm {
                    Button(action: onConfirm) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Confirm reminder")
                } else {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove reminder")
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .frame(minHeight: 44)
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
#if os(iOS)
        .onChange(of: reminder.liveActivityEnabled) { _, newValue in
            if newValue != isLiveActivityEnabled {
                isLiveActivityEnabled = newValue
            }
        }
        .onChange(of: reminder.alwaysLiveActivity) { _, newValue in
            if newValue != isAlwaysLiveActivity {
                isAlwaysLiveActivity = newValue
            }
        }
        .onChange(of: reminder.isCritical) { _, newValue in
            if newValue != isCriticalEnabled {
                isCriticalEnabled = newValue
            }
        }
#endif
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

    @State private var showConflictAlert = false
    @State private var conflictMessage = ""
    @State private var attemptedCityId: String?

    private let entries = TimeZoneDirectory.allEntries()

    private var filteredEntries: [TimeZoneDirectory.Entry] {
        let currentTime = Date()
        let baseEntries = searchText.isEmpty ? entries : entries.filter { entry in
            entry.name.localizedCaseInsensitiveContains(searchText) ||
            entry.gmtOffset.localizedCaseInsensitiveContains(searchText)
        }

        return baseEntries.sorted { lhs, rhs in
            guard let lhsTZ = TimeZone(identifier: lhs.id),
                  let rhsTZ = TimeZone(identifier: rhs.id) else {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }

            var lhsCal = Calendar.current
            lhsCal.timeZone = lhsTZ
            let lhsHour = lhsCal.component(.hour, from: currentTime)
            let lhsMinute = lhsCal.component(.minute, from: currentTime)

            var rhsCal = Calendar.current
            rhsCal.timeZone = rhsTZ
            let rhsHour = rhsCal.component(.hour, from: currentTime)
            let rhsMinute = rhsCal.component(.minute, from: currentTime)

            let lhsTime = lhsHour * 60 + lhsMinute
            let rhsTime = rhsHour * 60 + rhsMinute

            return lhsTime < rhsTime
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
                            .foregroundStyle(.primary)
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
        .alert("Computer says no", isPresented: $showConflictAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(conflictMessage)
        }
    }

    private func toggle(_ identifier: String) {
        if selection.contains(identifier) {
            if identifier == localCityIdentifier { return }
            selection.remove(identifier)
        } else {
            // Проверяем конфликт ПЕРЕД добавлением
            var testSelection = selection
            testSelection.insert(identifier)
            let testCities = WorldCity.cities(from: Array(testSelection))

            let result = CityOrbitDistribution.distributeCities(
                cities: testCities,
                currentTime: Date()
            )

            if result.hasConflicts {
                attemptedCityId = identifier
                conflictMessage = result.conflictMessage ?? "This city conflicts with existing cities"
                showConflictAlert = true
            } else {
                selection.insert(identifier)
            }
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

    @State private var showConflictAlert = false
    @State private var conflictMessage = ""
    @State private var attemptedCityId: String?

    private let entries = TimeZoneDirectory.allEntries()

    private var filteredEntries: [TimeZoneDirectory.Entry] {
        let currentTime = Date()
        let baseEntries = searchText.isEmpty ? entries : entries.filter { entry in
            entry.name.localizedCaseInsensitiveContains(searchText) ||
            entry.gmtOffset.localizedCaseInsensitiveContains(searchText)
        }

        return baseEntries.sorted { lhs, rhs in
            guard let lhsTZ = TimeZone(identifier: lhs.id),
                  let rhsTZ = TimeZone(identifier: rhs.id) else {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }

            var lhsCal = Calendar.current
            lhsCal.timeZone = lhsTZ
            let lhsHour = lhsCal.component(.hour, from: currentTime)
            let lhsMinute = lhsCal.component(.minute, from: currentTime)

            var rhsCal = Calendar.current
            rhsCal.timeZone = rhsTZ
            let rhsHour = rhsCal.component(.hour, from: currentTime)
            let rhsMinute = rhsCal.component(.minute, from: currentTime)

            let lhsTime = lhsHour * 60 + lhsMinute
            let rhsTime = rhsHour * 60 + rhsMinute

            return lhsTime < rhsTime
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                TextField("Search cities...", text: $searchText)
                    .textFieldStyle(.roundedBorder)

                Button("Reset") {
                    selection = Set(WorldCity.initialSelectionIdentifiers())
                    selection.insert(localCityIdentifier)
                    onChanged()
                }
                .buttonStyle(.bordered)
            }

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
        .alert("Computer says no", isPresented: $showConflictAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(conflictMessage)
        }
    }

    private func toggle(_ identifier: String) {
        if selection.contains(identifier) {
            if identifier == localCityIdentifier { return }
            selection.remove(identifier)
        } else {
            // Проверяем конфликт ПЕРЕД добавлением
            var testSelection = selection
            testSelection.insert(identifier)
            let testCities = WorldCity.cities(from: Array(testSelection))

            let result = CityOrbitDistribution.distributeCities(
                cities: testCities,
                currentTime: Date()
            )

            if result.hasConflicts {
                attemptedCityId = identifier
                conflictMessage = result.conflictMessage ?? "This city conflicts with existing cities"
                showConflictAlert = true
            } else {
                selection.insert(identifier)
            }
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
    @Environment(\.colorScheme) private var colorScheme

    init(reminder: ClockReminder, onSave: @escaping (Int, Int) -> Void) {
        self.reminder = reminder
        self.onSave = onSave
        self._selectedHour = State(initialValue: reminder.hour)
        self._selectedMinute = State(initialValue: reminder.minute)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Spacer for sheet rounded corners
            Color.clear
                .frame(height: 16)

            // Header
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Text("Edit Reminder")
                    .font(.headline)

                Spacer()

                Button("Save") {
                    onSave(selectedHour, selectedMinute)
                }
                .keyboardShortcut(.defaultAction)
                .fontWeight(.semibold)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(headerBackgroundColor)

            Divider()

            // Time Picker
            VStack(spacing: 24) {
                Text("Set Time")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    // Hour Picker
                    VStack(spacing: 4) {
                        Text("Hour")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Picker("", selection: $selectedHour) {
                            ForEach(0..<24, id: \.self) { hour in
                                Text(String(format: "%02d", hour))
                                    .tag(hour)
                                    .font(.system(.title2, design: .rounded))
                            }
                        }
#if os(iOS)
                        .pickerStyle(.wheel)
#endif
                        .frame(width: 80, height: 120)
                        .clipped()
                    }

                    Text(":")
                        .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.light)
                        .foregroundStyle(.secondary)
                        .padding(.top, 20)

                    // Minute Picker
                    VStack(spacing: 4) {
                        Text("Minute")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Picker("", selection: $selectedMinute) {
                            ForEach([0, 15, 30, 45], id: \.self) { minute in
                                Text(String(format: "%02d", minute))
                                    .tag(minute)
                                    .font(.system(.title2, design: .rounded))
                            }
                        }
#if os(iOS)
                        .pickerStyle(.wheel)
#endif
                        .frame(width: 80, height: 120)
                        .clipped()
                    }
                }

                // Preview
                VStack(spacing: 8) {
                    Text("Preview")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Text(String(format: "%02d:%02d", selectedHour, selectedMinute))
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.primary.opacity(0.05))
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 32)
            .background(backgroundColor)
        }
#if os(macOS)
        .frame(width: 320, height: 380)
        .background(backgroundColor)
#else
        .frame(maxWidth: .infinity, maxHeight: .infinity)
#endif
    }

    private var headerBackgroundColor: Color {
#if os(macOS)
        Color(nsColor: .controlBackgroundColor)
#else
        Color(uiColor: .secondarySystemBackground)
#endif
    }

    private var backgroundColor: Color {
#if os(macOS)
        Color(nsColor: .textBackgroundColor)
#else
        Color(uiColor: .systemBackground)
#endif
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
#if DEBUG
struct SwiftUIClockApp_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
