# Widget 12-Hour Format Fixes

## Исправленные проблемы

### 1. SmallQuarter и LargeQuarter - Невидимые цифры в 12-часовом режиме

**Проблема:** При переключении на 12-часовой формат цифры на циферблате не отображались. Было две подпроблемы:

#### 1a. Неправильная логика отрисовки цифр
На iOS и macOS цифры не отображались из-за неправильного углового шага.

**Решение:** 
- Исправлена логика в функции `drawNumbers()` в `SimplifiedClockFace`
- В 12-часовом формате теперь используется удвоенный угловой шаг (`hourAngleStep * 2`)
- Правильно вычисляется `rawHour` с учетом 12-часового формата (пропуск каждого второго часа)

**Файлы изменены:**
- `ClockW3Widget/SmallQuarter.swift` - исправлена функция `drawNumbers()`

**Детали реализации:**
```swift
// Для 12-часового формата шаг должен быть в 2 раза больше
let currentHourAngleStep = use12HourFormat ? hourAngleStep * 2 : hourAngleStep

// В 12-часовом пропускаем каждый второй час
let rawHour = (baseHour + index * (use12HourFormat ? 2 : 1)) % 24
```

#### 1b. Неправильная палитра цветов на macOS (неактивный режим)
На macOS в неактивном режиме виджета (non-fullColor) палитра `forMacWidget` всегда использовала белый цвет для всех элементов, независимо от colorScheme. В light mode белые цифры на светлом Material фоне были невидимы.

**Решение:**
- Исправлена палитра `forMacWidget` чтобы учитывать `colorScheme`
- В light mode используется черный цвет
- В dark mode используется белый цвет

**Файлы изменены:**
- `Shared/Models/ClockColorPalette.swift` - исправлена функция `forMacWidget()`

**Детали реализации:**
```swift
static func forMacWidget(colorScheme: ColorScheme) -> ClockColorPalette {
    // В light mode используем черный, в dark mode - белый для максимальной видимости
    let primary: Color = (colorScheme == .light) ? .black : .white
    let secondary: Color = (colorScheme == .light) ? .black.opacity(0.6) : .white.opacity(0.6)
    // ...
}
```

### 2. Electro виджеты - Неправильный цвет AM/PM надписей

**Проблема:** В виджетах SmallLeftElectro, SmallRightElectro и MediumElectro надписи AM/PM были невидимы или плохо читались на iOS. Цвет был инвертирован: использовался `digitCol` который совпадал с фоном плиток.

**Решение:**
- Добавлена отдельная переменная `ampmCol` для цвета AM/PM надписей
- **Правильная логика:** белый цвет в dark mode, черный цвет в light mode
- Цвет всегда контрастирует с фоном виджета

**Файлы изменены:**
- `ClockW3Widget/SmallLeftElectro.swift`
- `ClockW3Widget/SmallRightElectro.swift`
- `ClockW3Widget/MediumElectro.swift`

**Детали реализации:**
```swift
// AM/PM цвет: белый в dark, черный в light
let ampmCol = (effectiveColorScheme == .light) ? Color.black : Color.white

// Использование:
Text(ampm)
    .foregroundColor(ampmCol)
```

## Тестирование

Все билды выполнены успешно:
- ✅ iOS build: SUCCESS
- ✅ macOS build: SUCCESS

## Визуальный результат

### SmallQuarter & LargeQuarter
- **24-часовой формат:** Работает как раньше, отображаются все 24 часа
- **12-часовой формат:** 
  - ✅ iOS: Цифры правильно отображаются (12, 2, 4, 6, 8, 10)
  - ✅ macOS fullColor: Цифры правильно отображаются
  - ✅ macOS неактивный режим: Цифры теперь видны (черные в light mode, белые в dark mode)
  - Без индикатора AM/PM (как и должно быть для этих виджетов)

### Electro виджеты (SmallLeftElectro, SmallRightElectro, MediumElectro)
- **Light mode:** AM/PM надписи черные - хорошо видны на белом фоне
- **Dark mode:** AM/PM надписи белые - хорошо видны на черном фоне
- Надписи видны на обеих платформах (iOS и macOS)
- В неактивном режиме (macOS non-fullColor) надписи также корректно отображаются

## Заметки

Изменение палитры `forMacWidget` влияет на все виджеты на macOS в неактивном режиме, улучшая видимость всех элементов (цифр, меток, стрелок) в обеих цветовых схемах.
