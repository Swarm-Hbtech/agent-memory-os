#!/usr/bin/env bash
# =============================================================================
# backup-memory.sh — Point-in-Time Backup (Layer 6)
# v1.0 — 2026-04-29
#
# Создаёт tar.gz снимок всей памяти агентов и доставляет offsite в Telegram.
# Работает без Node.js/PM2/БД. Только bash + tar + curl + find.
#
# Поведение:
# - Пакует openclaw-agent-memory/ в memory-backup-YYYY-MM-DD_HHMM.tar.gz
# - Отправляет архив в Telegram через @SwarmNotification_bot
# - Если TG недоступен — оставляет локальную копию, exit 0 (cron не спамит)
# - Хранит локально только последние KEEP_LOCAL архивов (ротация)
#
# Использование:
#   ./backup-memory.sh
#
# Cron (каждые 3 дня в 03:00):
#   0 3 */3 * * /home/openclaw/openclaw-agent-memory/scripts/backup-memory.sh
# =============================================================================

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BACKUP_DIR="$REPO_DIR/.backups"
TIMESTAMP="$(date '+%Y-%m-%d_%H%M')"
ARCHIVE_NAME="memory-backup-${TIMESTAMP}.tar.gz"
ARCHIVE_PATH="$BACKUP_DIR/$ARCHIVE_NAME"
KEEP_LOCAL=4

TG_TOKEN="YOUR_TG_BOT_TOKEN"
TG_CHAT_ID="YOUR_TG_CHAT_ID"
TG_PROXY="http://127.0.0.1:10809"

mkdir -p "$BACKUP_DIR"

TMP_RESULT="$(mktemp)"
cleanup() {
    [[ -f "$TMP_RESULT" ]] && rm -f "$TMP_RESULT"
}
trap cleanup EXIT

# =============================================================================
# 1. Создаём архив
# =============================================================================

echo "[backup] Creating archive: $ARCHIVE_NAME" >&2

tar -czf "$ARCHIVE_PATH" \
    --exclude='.git' \
    --exclude='.backups' \
    --exclude='.health' \
    --exclude='compiled' \
    --exclude='*.lock' \
    -C "$(dirname "$REPO_DIR")" \
    "$(basename "$REPO_DIR")"

ARCHIVE_SIZE="$(du -sh "$ARCHIVE_PATH" | cut -f1)"
echo "[backup] Archive created: $ARCHIVE_PATH ($ARCHIVE_SIZE)" >&2

# =============================================================================
# 2. Отправляем в Telegram (offsite)
# =============================================================================

TG_CAPTION="🗄 Memory Backup
Date: $TIMESTAMP
Size: $ARCHIVE_SIZE
Host: $(hostname)
Branch: amsterdam-sandbox"

echo "[backup] Uploading to Telegram..." >&2

HTTP_CODE="$(curl -s -o "$TMP_RESULT" -w "%{http_code}" \
    --max-time 60 \
    -x "$TG_PROXY" \
    -F "chat_id=${TG_CHAT_ID}" \
    -F "caption=${TG_CAPTION}" \
    -F "document=@${ARCHIVE_PATH};filename=${ARCHIVE_NAME}" \
    "https://api.telegram.org/bot${TG_TOKEN}/sendDocument" \
    2>/dev/null || echo "000")"

if [[ "$HTTP_CODE" == "200" ]]; then
    echo "[backup] ✅ Uploaded to Telegram successfully" >&2
else
    echo "[backup] ⚠️  TG Upload Failed (HTTP $HTTP_CODE), local copy saved: $ARCHIVE_PATH" >&2
    # Не падаем — локальная копия есть, cron не спамит
fi

# =============================================================================
# 3. Ротация локальных архивов (оставляем только KEEP_LOCAL последних)
# =============================================================================

echo "[backup] Rotating local archives (keep last $KEEP_LOCAL)..." >&2

# ls -t: сортировка по времени (новые первые)
# tail -n +N: всё начиная с N+1 элемента = старые архивы
STALE="$(ls -t "$BACKUP_DIR"/memory-backup-*.tar.gz 2>/dev/null | tail -n +"$((KEEP_LOCAL + 1))")"

if [[ -n "$STALE" ]]; then
    echo "$STALE" | while IFS= read -r f; do
        echo "[backup] Removing old archive: $(basename "$f")" >&2
        rm -f "$f"
    done
else
    echo "[backup] No old archives to remove" >&2
fi

# =============================================================================
# 4. Итог
# =============================================================================

REMAINING="$(ls "$BACKUP_DIR"/memory-backup-*.tar.gz 2>/dev/null | wc -l | tr -d ' ')"
echo "[backup] Done. Local archives: $REMAINING / $KEEP_LOCAL" >&2
