#!/bin/sh
set -e

REPO="Bdata0/forkop-mgr"
DEST="/usr/bin/forkop-mgr"
RAW_URL="https://raw.githubusercontent.com/${REPO}/main/forkop-mgr"
CDN_URL="https://cdn.jsdelivr.net/gh/${REPO}@main/forkop-mgr"

echo "=== Установка / Обновление Forkop Control Center ==="

download() {
    src="$1"
    target="$2"

    # 1. Если на роутере уже запущен локальный прокси Forkop (4534)
    if nc -z 127.0.0.1 4534 2>/dev/null; then
        if command -v curl >/dev/null 2>&1; then
            curl -skLf -x http://127.0.0.1:4534 --connect-timeout 15 "$src" -o "$target" 2>/dev/null && return 0
        fi
        if command -v wget >/dev/null 2>&1; then
            wget -q --no-check-certificate -e use_proxy=yes -e http_proxy=127.0.0.1:4534 -O "$target" "$src" 2>/dev/null && return 0
        fi
    fi

    # 2. Если прокси нет (чистый роутер)
    if command -v curl >/dev/null 2>&1; then
        curl -skLf --connect-timeout 15 "$src" -o "$target" 2>/dev/null && return 0
    elif command -v wget >/dev/null 2>&1; then
        wget -q --no-check-certificate -O "$target" "$src" 2>/dev/null && return 0
    else
        echo "Ошибка: в системе не найдены ни curl, ни wget!"
        exit 1
    fi
    return 1
}

echo "Загрузка forkop-mgr..."
# Сначала пробуем CDN (работает в РФ без блокировок и Fake-IP), затем напрямую с GitHub
if ! download "$CDN_URL" "$DEST"; then
    echo "CDN недоступен, попытка прямого скачивания с GitHub..."
    if ! download "$RAW_URL" "$DEST"; then
        echo "Критическая ошибка: не удалось загрузить файл!"
        exit 1
    fi
fi

# Проверка, что файл не скачался пустым
if [ ! -s "$DEST" ]; then
    echo "Ошибка: загруженный файл пуст (0 байт)!"
    rm -f "$DEST"
    exit 1
fi

# Удаление символов возврата каретки Windows и выдача прав
sed -i 's/\r$//' "$DEST"
chmod +x "$DEST"

echo "Установка успешно завершена!"
echo "Запуск менеджера..."
exec "$DEST"
