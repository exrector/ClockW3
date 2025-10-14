#!/bin/bash

echo "🧪 Запуск автотестов ClockW3..."

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Переходим в директорию проекта
cd "$(dirname "$0")"

# Функция для запуска теста
run_test() {
    local test_file=$1
    local test_name=$2
    
    echo -e "${YELLOW}🔍 $test_name...${NC}"
    
    # Запускаем Swift файл как скрипт
    if swift -I . ClockW3Tests/$test_file 2>/dev/null; then
        echo -e "${GREEN}✅ $test_name - ПРОЙДЕН${NC}"
        return 0
    else
        echo -e "${RED}❌ $test_name - ОШИБКА${NC}"
        return 1
    fi
}

# Счётчики
total_tests=0
passed_tests=0

# Запускаем основные тесты
tests=(
    "AngleCalculationTests.swift:Расчёт углов"
    "WorldCityTests.swift:Управление городами"
    "TimeConversionTests.swift:Точность преобразования"
    "PerformanceTests.swift:Производительность"
    "HapticTests.swift:Хаптическая обратная связь"
    "ReminderTests.swift:Система напоминаний"
)

for test_info in "${tests[@]}"; do
    IFS=':' read -r test_file test_name <<< "$test_info"
    total_tests=$((total_tests + 1))
    
    if run_test "$test_file" "$test_name"; then
        passed_tests=$((passed_tests + 1))
    fi
    echo ""
done

# Итоговый результат
echo "📊 Результаты тестирования:"
echo "Пройдено: $passed_tests/$total_tests"

if [ $passed_tests -eq $total_tests ]; then
    echo -e "${GREEN}🎉 Все тесты пройдены успешно!${NC}"
    exit 0
else
    echo -e "${RED}💥 Некоторые тесты не пройдены${NC}"
    exit 1
fi
