#!/bin/sh
set -e

REPO="Bdata0/forkop-mgr"
DEST="/usr/bin/forkop-mgr"
RAW_URL="https://raw.githubusercontent.com/${REPO}/main/forkop-mgr"

echo "=== Установка / Обновление Forkop Control Center ==="

download() {
    src="$1"
    target="$2"

    if netstat -ln 2>/dev/null | grep -q ":4534 "; then
        if command -v curl >/dev/null 2>&1; then
            curl -SLf -x http://127.0.0.1:4534 --connect-timeout 20 "$src" -o "$target" 2>/dev/null && return 0
        fi
        if command -v wget >/dev/null 2>&1; then
            wget -q --no-check-certificate -e use_proxy=yes -e http_proxy=127.0.0.1:4534 -O "$target" "$src" 2>/dev/null && return 0
        fi
    fi

    if command -v curl >/dev/null 2>&1; then
        curl -SLf --connect-timeout 20 "$src" -o "$target" 2>/dev/null && return 0
    elif command -v wget >/dev/null 2>&1; then
        wget -q --no-check-certificate -O "$target" "$src" 2>/dev/null && return 0
    else
        echo "Ошибка: в системе не найдены ни curl, ни wget!"
        exit 1
    fi
    return 1
}

echo "Загрузка forkop-mgr..."
if ! download "$RAW_URL" "$DEST"; then
    echo "Критическая ошибка: не удалось загрузить файл с GitHub!"
    exit 1
fi

if [ ! -s "$DEST" ]; then
    echo "Ошибка: загруженный файл пуст!"
    rm -f "$DEST"
    exit 1
fi

sed -i 's/\r$//' "$DEST"
chmod +x "$DEST"

# Гарантируем запуск службы Forkop
/etc/init.d/forkop start >/dev/null 2>&1 || true

echo "Установка успешно завершена!"
echo ""
echo "========================================================"
echo "  Для запуска панели управления введите команду:"
echo "  forkop-mgr"
echo "========================================================"
