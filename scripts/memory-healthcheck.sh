#!/usr/bin/env bash
# =============================================================================
# memory-healthcheck.sh — Memory Watchdog (Layer 4)
# v1.1 — 2026-04-29
#
# Превентивная проверка целостности памяти.
# Работает без Node.js/PM2/БД. Только bash + awk + sed + grep + wc + date.
#
# Триггеры тревоги:
# - core-файл отсутствует
# - core-файл пустой
# - core-файл уменьшился более чем на THRESHOLD_PCT относительно baseline
# - найдены git conflict markers <<<<<<< ======= >>>>>>>
#
# Действия:
# - создаёт memory.lock (если ещё нет)
# - пишет причину в memory.lock
# - пишет событие в runtime/WATCHDOG-LOG.md
# - возвращает exit 42 при тревоге, exit 0 если всё ок
# - отправляет Telegram-алерт через @SwarmNotification_bot
#
# Использование:
#   ./memory-healthcheck.sh
# =============================================================================

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUNTIME_DIR="$REPO_DIR/runtime"
STATE_DIR="$REPO_DIR/.health"
LOCK_FILE="$REPO_DIR/memory.lock"
LOG_FILE="$RUNTIME_DIR/WATCHDOG-LOG.md"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M UTC')"
THRESHOLD_PCT="30"
TG_TOKEN="YOUR_TG_BOT_TOKEN"
TG_CHAT_ID="YOUR_TG_CHAT_ID"

mkdir -p "$RUNTIME_DIR" "$STATE_DIR"
TMP_ALERTS="$(mktemp)"
TMP_LOCK="$(mktemp)"

cleanup() {
    local ec=$?
    [[ -f "$TMP_ALERTS" ]] && rm -f "$TMP_ALERTS"
    [[ -f "$TMP_LOCK" ]] && rm -f "$TMP_LOCK"
    exit $ec
}
trap cleanup EXIT

CORE_FILES=(
    "$REPO_DIR/MASTER.md"
    "$REPO_DIR/OPERATING-MODEL.md"
    "$REPO_DIR/identity/IDENTITY-AGENT-A.md"
    "$REPO_DIR/identity/IDENTITY-AGENT-B.md"
    "$REPO_DIR/bootstrap/BOOTSTRAP-AGENT-A.md"
    "$REPO_DIR/bootstrap/BOOTSTRAP-AGENT-B.md"
    "$REPO_DIR/blueprints/AGENT-A-BLUEPRINT.md"
    "$REPO_DIR/blueprints/AGENT-B-BLUEPRINT.md"
)

append_alert() {
    echo "$1" >> "$TMP_ALERTS"
}

record_baseline() {
    local filepath="$1"
    local key
    key="$(echo "$filepath" | sed 's#/#__#g')"
    local baseline_file="$STATE_DIR/${key}.size"
    local size
    size="$(wc -c < "$filepath" | tr -d ' ')"
    echo "$size" > "$baseline_file"
}

check_missing_or_empty() {
    local filepath="$1"

    if [[ ! -f "$filepath" ]]; then
        append_alert "[CRITICAL] Missing core file: $filepath"
        return
    fi

    if [[ ! -r "$filepath" ]]; then
        append_alert "[CRITICAL] Unreadable core file: $filepath"
        return
    fi

    if [[ ! -s "$filepath" ]]; then
        append_alert "[CRITICAL] Empty core file: $filepath"
        return
    fi
}

check_conflict_markers() {
    local filepath="$1"

    if grep -Eq '^(<<<<<<<|=======|>>>>>>>)' "$filepath" 2>/dev/null; then
        append_alert "[CRITICAL] Git conflict markers found in: $filepath"
    fi
}

check_shrink() {
    local filepath="$1"
    local key baseline_file current_size baseline_size min_allowed

    key="$(echo "$filepath" | sed 's#/#__#g')"
    baseline_file="$STATE_DIR/${key}.size"
    current_size="$(wc -c < "$filepath" | tr -d ' ')"

    if [[ ! -f "$baseline_file" ]]; then
        echo "$current_size" > "$baseline_file"
        return
    fi

    baseline_size="$(cat "$baseline_file" 2>/dev/null || echo 0)"

    if ! [[ "$baseline_size" =~ ^[0-9]+$ ]] || [[ "$baseline_size" -le 0 ]]; then
        echo "$current_size" > "$baseline_file"
        return
    fi

    min_allowed=$(( baseline_size * (100 - THRESHOLD_PCT) / 100 ))

    if [[ "$current_size" -lt "$min_allowed" ]]; then
        append_alert "[CRITICAL] File shrank > ${THRESHOLD_PCT}%: $filepath (baseline=${baseline_size}B, current=${current_size}B)"
    fi
}

write_log() {
    local status="$1"
    {
        echo "## $TIMESTAMP — $status"
        if [[ -s "$TMP_ALERTS" ]]; then
            sed 's/^/- /' "$TMP_ALERTS"
        else
            echo "- OK: all checks passed"
        fi
        echo ""
    } >> "$LOG_FILE"
}

send_telegram_alert() {
    local text="$1"
    # fire-and-forget: не падаем если curl/сеть недоступны
    curl -s --max-time 10 \
        -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
        -d "chat_id=${TG_CHAT_ID}" \
        --data-urlencode "text=${text}" \
        -x http://127.0.0.1:10809 \
        > /dev/null 2>&1 || true
}

raise_lock() {
    {
        echo "WATCHDOG ALERT — $TIMESTAMP"
        echo "memory-healthcheck.sh detected integrity failure."
        echo ""
        sed 's/^/- /' "$TMP_ALERTS"
        echo ""
        echo "ACTION: Do NOT write to memory until Igor reviews this state."
    } > "$TMP_LOCK"

    mv "$TMP_LOCK" "$LOCK_FILE"
}

build_alert_message() {
    local reasons
    reasons="$(sed 's/^/  • /' "$TMP_ALERTS")"
    echo -e "🚨 [SWARM MEMORY LOCK]\n${TIMESTAMP}\n\nMemory integrity failure detected:\n${reasons}\n\nACTION: Memory is locked for writes. Review runtime/WATCHDOG-LOG.md."
}

main() {
    local fp

    for fp in "${CORE_FILES[@]}"; do
        check_missing_or_empty "$fp"

        if [[ -f "$fp" && -r "$fp" && -s "$fp" ]]; then
            check_conflict_markers "$fp"
            check_shrink "$fp"
        fi
    done

    if [[ -s "$TMP_ALERTS" ]]; then
        raise_lock
        write_log "ALERT"
        echo "[memory-healthcheck] ALERT: integrity issues detected" >&2
        cat "$TMP_ALERTS" >&2
        send_telegram_alert "$(build_alert_message)" || true
        exit 42
    fi

    for fp in "${CORE_FILES[@]}"; do
        if [[ -f "$fp" && -r "$fp" && -s "$fp" ]]; then
            record_baseline "$fp"
        fi
    done

    write_log "OK"
    echo "[memory-healthcheck] OK: all checks passed" >&2
}

main "$@"
