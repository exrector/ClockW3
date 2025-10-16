# Build Error Troubleshooting Guide

## Проблема: "Multiple commands produce Info.plist"

### Описание ошибки
```
Multiple commands produce '/Users/.../MOW.app/Info.plist'
The Copy Bundle Resources build phase contains this target's Info.plist file
duplicate output file '/Users/.../MOW.app/Info.plist' on task: ProcessInfoPlistFile
```

### Причина
Эта ошибка возникает в проектах Xcode 15+, которые используют новую систему `PBXFileSystemSynchronizedRootGroup`. Система автоматически включает все файлы из папки проекта, включая `Info.plist`, но при этом `Info.plist` также обрабатывается отдельно как специальный файл конфигурации.

### Решение
Нужно добавить исключение для `Info.plist` в настройках файловой синхронизации:

1. **Добавить исключение в project.pbxproj:**
   ```xml
   ADD4DAFB2E97D4D800439B5F /* Exceptions for "ClockW3" folder in "MOW" target */ = {
       isa = PBXFileSystemSynchronizedBuildFileExceptionSet;
       membershipExceptions = (
           Info.plist,
       );
       target = ADD4DAEC2E97D4D700439B5F /* MOW */;
   };
   ```

2. **Связать исключение с группой файлов:**
   ```xml
   ADD4DAEF2E97D4D700439B5F /* ClockW3 */ = {
       isa = PBXFileSystemSynchronizedRootGroup;
       exceptions = (
           ADD4DAFB2E97D4D800439B5F /* Exceptions for "ClockW3" folder in "MOW" target */,
       );
       path = ClockW3;
       sourceTree = "<group>";
   };
   ```

### Что это исправляет
- Убирает конфликт между автоматическим включением файлов и специальной обработкой Info.plist
- Позволяет Xcode правильно обрабатывать Info.plist как конфигурационный файл
- Сохраняет преимущества автоматической синхронизации файлов для остальных ресурсов

### Проверка исправления
После внесения изменений проект должен собираться без ошибок:
```bash
xcodebuild -project ClockW3.xcodeproj -scheme MOW -destination "id=DEVICE_ID" clean build
```

### Альтернативные решения
1. **Отключить файловую синхронизацию** (не рекомендуется)
2. **Вручную управлять всеми файлами** (трудозатратно)
3. **Переместить Info.plist в отдельную папку** (может нарушить структуру проекта)

### Примечания
- Эта проблема характерна для проектов, созданных в Xcode 15+
- Аналогичные исключения могут потребоваться для других специальных файлов (entitlements, etc.)
- Изменения в project.pbxproj лучше делать через Xcode, но в данном случае ручное редактирование было необходимо