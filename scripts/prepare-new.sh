#!/usr/bin/env bash
# =============================================================================
# prepare-new.sh — Context Compiler (Layer 3)
# v1.1 — 2026-04-29
#
# Собирает стартовый payload для AI-агента при каждом /new
# Работает без Node.js, PM2, БД — только bash + awk/sed/cat
#
# Использование:
#   ./prepare-new.sh agent-a   → compiled/agent-a-context.txt
#   ./prepare-new.sh agent-b   → compiled/agent-b-context.txt
#
# Spec: Fail-Safe + Aggressive Compression + Smart Tail
# =============================================================================

set -euo pipefail

AGENT="${1:-}"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
COMPILED_DIR="$REPO_DIR/compiled"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M UTC')"

if [[ "$AGENT" != "agent-a" && "$AGENT" != "agent-b" ]]; then
    echo "Usage: $0 <agent-a|agent-b>" >&2
    exit 1
fi

mkdir -p "$COMPILED_DIR"
OUTPUT="$COMPILED_DIR/${AGENT}-context.txt"
TMP="$(mktemp)"

cleanup() {
    [[ -f "$TMP" ]] && rm -f "$TMP"
}
trap cleanup EXIT

compress_stream() {
    awk '
        BEGIN { in_comment=0; blank=0 }
        {
            line=$0

            # Удаляем inline markdown comments <!-- ... --> на одной строке
            gsub(/<!--[[:space:]]*[^>]*[[:space:]]*-->/, "", line)

            # Грубая, но безопасная обработка многострочных HTML-комментариев
            if (in_comment) {
                if (line ~ /-->/) {
                    sub(/^.*-->/, "", line)
                    in_comment=0
                } else {
                    next
                }
            }
            if (line ~ /<!--/ && line !~ /-->/) {
                sub(/<!--.*$/, "", line)
                in_comment=1
            }

            sub(/[[:space:]]+$/, "", line)

            if (line ~ /^[[:space:]]*$/) {
                blank++
                if (blank <= 1) print ""
                next
            }

            blank=0
            print line
        }
    '
}

read_file() {
    local label="$1"
    local filepath="$2"
    local limit="${3:-0}"

    echo "=== $label ==="

    if [[ ! -f "$filepath" ]]; then
        echo "[CRITICAL WARNING: FILE NOT FOUND: $filepath]"
        echo ""
        return
    fi

    if [[ ! -r "$filepath" ]]; then
        echo "[CRITICAL WARNING: FILE NOT READABLE: $filepath]"
        echo ""
        return
    fi

    if [[ "$limit" -gt 0 ]]; then
        head -n "$limit" "$filepath" | compress_stream
    else
        cat "$filepath" | compress_stream
    fi

    echo ""
}

read_handoff() {
    local label="$1"
    local filepath="$2"
    local lines="${3:-50}"

    echo "=== $label ==="

    if [[ ! -f "$filepath" ]]; then
        echo "[CRITICAL WARNING: HANDOFF FILE NOT FOUND: $filepath]"
        echo ""
        return
    fi

    if [[ ! -r "$filepath" ]]; then
        echo "[CRITICAL WARNING: HANDOFF FILE NOT READABLE: $filepath]"
        echo ""
        return
    fi

    # Smart Tail strategy:
    # 1. Если есть маркер последней сессии — берём всё после последнего маркера.
    # 2. Иначе берём последние N строк.
    # 3. Если срез оборвался внутри code block ``` — добираем/закрываем безопасно.
    awk -v lines="$lines" '
        BEGIN {
            marker_found=0
            last_marker=0
        }
        /^##[[:space:]]+(Последняя сессия|Last session|Session|Сессия)/ {
            last_marker=NR
            marker_found=1
        }
        {
            buf[NR]=$0
        }
        END {
            start=1
            if (marker_found) {
                start=last_marker
            } else if (NR > lines) {
                start=NR-lines+1
            }

            fence_count=0
            for (i=start; i<=NR; i++) {
                print buf[i]
                if (buf[i] ~ /^```/) fence_count++
            }

            if (fence_count % 2 == 1) {
                print "```"
                print "[CRITICAL WARNING: CODE BLOCK WAS TRUNCATED; AUTO-CLOSED BY prepare-new.sh]"
            }
        }
    ' "$filepath" | compress_stream

    echo ""
}

check_memory_lock() {
    if [[ -f "$REPO_DIR/memory.lock" ]]; then
        echo "=== [!] MEMORY LOCK ACTIVE ==="
        echo "[CRITICAL ALERT: MEMORY.LOCK DETECTED. SYSTEM HALTED FOR WRITES.]"
        echo "ACTION REQUIRED: Do NOT write to memory. Alert Igor immediately."

        if [[ -s "$REPO_DIR/memory.lock" ]]; then
            echo "Reason:"
            cat "$REPO_DIR/memory.lock" 2>/dev/null || echo "(unreadable)"
        else
            echo "[CRITICAL WARNING: memory.lock exists but is empty or unreadable]"
        fi
        echo ""
    fi
}

{
    echo "============================================================"
    echo "AGENT STARTUP CONTEXT — ${AGENT^^}"
    echo "Generated: $TIMESTAMP"
    echo "Compiler: prepare-new.sh v1.1"
    echo "============================================================"
    echo ""

    check_memory_lock

    # Determine the OTHER agent for handoff reading
    if [[ "$AGENT" == "agent-a" ]]; then
        OTHER="agent-b"
    else
        OTHER="agent-a"
    fi

    read_file "IDENTITY: WHO AM I" "$REPO_DIR/identity/IDENTITY-${AGENT^^}.md"
    read_file "BOOTSTRAP: WHAT TO DO" "$REPO_DIR/bootstrap/BOOTSTRAP-${AGENT^^}.md"
    read_handoff "HANDOFF FROM ${OTHER^^}" "$REPO_DIR/runtime/${OTHER^^}-HANDOFF.md" 50
    read_handoff "MY LAST STATUS" "$REPO_DIR/runtime/${AGENT^^}-STATUS.md" 30
    read_file "MASTER: PROJECT OVERVIEW" "$REPO_DIR/MASTER.md" 100

    if [[ "$AGENT" == "agent-a" ]]; then
        read_file "CRITICAL INFRA" "$REPO_DIR/infra/SERVERS.md" 60
    fi

    read_file "OPERATING RULES (summary)" "$REPO_DIR/OPERATING-MODEL.md" 50

    echo "============================================================"
    echo "END OF CONTEXT"
    echo "============================================================"
} > "$TMP"

LINES="$(wc -l < "$TMP")"
CHARS="$(wc -c < "$TMP")"

echo "Total lines: ${LINES}" >> "$TMP"
echo "--- Stats: ${LINES} lines, ${CHARS} chars ---" >> "$TMP"

mv "$TMP" "$OUTPUT"
trap - EXIT

echo "[prepare-new] ✅ Context compiled for ${AGENT^^}" >&2
echo "[prepare-new] Output: $OUTPUT" >&2
echo "[prepare-new] Size: ${LINES} lines, ${CHARS} chars" >&2
