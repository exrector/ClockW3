# Widget Margins Fix

## Проблема
Виджеты имеют внутренние отступы (margins) от системы iOS/macOS, из-за чего содержимое не занимает весь доступный размер.

## Решение

### 1. Добавить в TimeVector2WidgetEntryView

```swift
struct TimeVector2WidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        if let snapshot = LargeWidgetSnapshotManager.shared.loadSnapshot() {
            snapshot
                .resizable()
                .aspectRatio(contentMode: .fill) // Изменить на .fill
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .id(UUID())
        } else {
            Color.black.opacity(0.1)
                .overlay(
                    Text("Loading...")
                        .foregroundColor(.secondary)
                )
        }
    }
}
```

### 2. Или использовать .ignoresSafeArea()

```swift
var body: some View {
    if let snapshot = LargeWidgetSnapshotManager.shared.loadSnapshot() {
        snapshot
            .resizable()
            .aspectRatio(contentMode: .fill)
            .ignoresSafeArea()
            .id(UUID())
    } else {
        // ...
    }
}
```

### 3. Или через containerBackground (iOS 17+)

```swift
struct TimeVector2Widget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            TimeVector2WidgetEntryView(entry: entry)
        }
        .contentMarginsDisabled() // Отключить отступы
    }
}
```

## Рекомендация
Используйте комбинацию `.aspectRatio(contentMode: .fill)` + `.ignoresSafeArea()` для максимального заполнения.
