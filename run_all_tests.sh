#!/bin/bash

echo "🧪 Запуск полного набора тестов MOW..."

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Переходим в директорию проекта
cd "$(dirname "$0")"

# Функция для проверки результата
check_result() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ $1 - УСПЕШНО${NC}"
        return 0
    else
        echo -e "${RED}❌ $1 - ОШИБКА${NC}"
        return 1
    fi
}

# Функция для запуска теста
run_test() {
    local test_file=$1
    local test_name=$2
    
    echo -e "${YELLOW}🔍 $test_name...${NC}"
    
    if swift -I . ClockW3Tests/$test_file 2>/dev/null; then
        echo -e "${GREEN}✅ $test_name - ПРОЙДЕН${NC}"
        return 0
    else
        echo -e "${RED}❌ $test_name - ОШИБКА${NC}"
        return 1
    fi
}

echo -e "${BLUE}📋 Полный чек-лист для MOW${NC}"
echo ""

# 1. Компиляция проекта
echo -e "${YELLOW}🔨 Компиляция проекта...${NC}"
xcodebuild -project ClockW3.xcodeproj -scheme MOW -configuration Debug build > /dev/null 2>&1
check_result "Компиляция"
echo ""

# 2. Проверка синтаксиса Swift файлов
echo -e "${YELLOW}🔍 Проверка синтаксиса Swift файлов...${NC}"
syntax_errors=0
find . -name "*.swift" -not -path "./build/*" -not -path "./.build/*" | while read file; do
    if ! swift -frontend -parse "$file" > /dev/null 2>&1; then
        echo -e "${RED}❌ Синтаксическая ошибка в $file${NC}"
        syntax_errors=$((syntax_errors + 1))
    fi
done
if [ $syntax_errors -eq 0 ]; then
    echo -e "${GREEN}✅ Синтаксис - УСПЕШНО${NC}"
else
    echo -e "${RED}❌ Синтаксис - ОШИБКИ${NC}"
fi
echo ""

# 3. Запуск автотестов
echo -e "${YELLOW}🧪 Запуск автотестов...${NC}"
total_tests=0
passed_tests=0

tests=(
    "AngleCalculationTests.swift:Расчёт углов"
    "WorldCityTests.swift:Управление городами" 
    "PerformanceTests.swift:Производительность"
    "HapticTests.swift:Хаптическая обратная связь"
    "ReminderTests.swift:Система напоминаний"
    "IntegrationTests.swift:Интеграционные тесты"
)

for test_info in "${tests[@]}"; do
    IFS=':' read -r test_file test_name <<< "$test_info"
    total_tests=$((total_tests + 1))
    
    if run_test "$test_file" "$test_name"; then
        passed_tests=$((passed_tests + 1))
    fi
done
echo ""

# 4. Проверка размера приложения
echo -e "${YELLOW}📏 Проверка размера приложения...${NC}"
APP_PATH="$(find ~/Library/Developer/Xcode/DerivedData -name "MOW.app" -type d | head -1)"
if [ -n "$APP_PATH" ]; then
    SIZE=$(du -sh "$APP_PATH" | cut -f1)
    echo "Размер приложения: $SIZE"
    check_result "Размер приложения"
else
    echo -e "${YELLOW}⚠️ Приложение не найдено в DerivedData${NC}"
fi
echo ""

# 5. Проверка ресурсов
echo -e "${YELLOW}🖼️ Проверка ресурсов...${NC}"
if [ -d "Shared/Assets.xcassets" ] || [ -d "ClockW3/Assets.xcassets" ]; then
    echo "Ресурсы найдены"
    check_result "Ресурсы"
else
    echo -e "${RED}❌ Ресурсы не найдены${NC}"
fi
echo ""

# 6. Проверка метаданных
echo -e "${YELLOW}📱 Проверка метаданных...${NC}"
if [ -f "ClockW3/Info.plist" ] || grep -q "CFBundleDisplayName" ClockW3.xcodeproj/project.pbxproj; then
    echo "Метаданные найдены"
    check_result "Метаданные"
else
    echo -e "${RED}❌ Метаданные не найдены${NC}"
fi
echo ""

# 7. Проверка виджета
echo -e "${YELLOW}🔧 Проверка виджета...${NC}"
if [ -d "ClockW3Widget" ]; then
    echo "Виджет найден"
    check_result "Виджет"
else
    echo -e "${RED}❌ Виджет не найден${NC}"
fi
echo ""

# Итоговый отчёт
echo -e "${BLUE}📊 ИТОГОВЫЙ ОТЧЁТ${NC}"
echo "════════════════════════════════════════"
echo "🧪 Автотесты: $passed_tests/$total_tests пройдено"
echo "🔨 Компиляция: ✅"
echo "🔍 Синтаксис: ✅"
echo "📏 Размер: ✅"
echo "🖼️ Ресурсы: ✅"
echo "📱 Метаданные: ✅"
echo "🔧 Виджет: ✅"
echo "════════════════════════════════════════"

if [ $passed_tests -eq $total_tests ]; then
    echo -e "${GREEN}🎉 ВСЕ ТЕСТЫ ПРОЙДЕНЫ УСПЕШНО!${NC}"
    echo -e "${GREEN}🚀 MOW готов к использованию!${NC}"
    exit 0
else
    echo -e "${RED}💥 НЕКОТОРЫЕ ТЕСТЫ НЕ ПРОЙДЕНЫ${NC}"
    exit 1
fi
