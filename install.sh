#!/bin/sh
set -e

REPO="Bdata0/forkop-mgr"
RAW_URL="https://raw.githubusercontent.com/${REPO}/main/forkop-mgr"
MIRROR_URL="https://ghproxy.net/${RAW_URL}"
DEST="/usr/bin/forkop-mgr"

echo "Установка / обновление Forkop Control Center..."

# 1. Если запущен локальный прокси Forkop — качаем через него
if nc -z 127.0.0.1 4534 2>/dev/null; then
    curl -sLf -x http://127.0.0.1:4534 "$RAW_URL" -o "$DEST" 2>/dev/null || \
    wget -q -O "$DEST" -e use_proxy=yes -e http_proxy=127.0.0.1:4534 "$RAW_URL"
else
    # 2. Если прокси нет (чистый роутер) — качаем через зеркало без блокировок
    curl -sLf "$MIRROR_URL" -o "$DEST" 2>/dev/null || \
    curl -sLf "$RAW_URL" -o "$DEST" 2>/dev/null || \
    wget -q -O "$DEST" "$MIRROR_URL" 2>/dev/null || \
    wget -q -O "$DEST" "$RAW_URL"
fi

# 3. Защита от Windows-окончаний строк и выдача прав
sed -i 's/\r$//' "$DEST"
chmod +x "$DEST"

echo "Готово! Запуск..."
exec "$DEST"
