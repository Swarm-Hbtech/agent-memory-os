# BOOTSTRAP-AGENT-B.md
# Agent B startup file — read first on every /new

**One screen max. No philosophy. Only action items.**

---

## Who I am

**Agent B** — Architect & Developer.
Identity details already loaded from `identity/IDENTITY-AGENT-B.md`.

---

## What to do right now

```bash
# 1. Pull handoffs from Agent A
cd /path/to/agent-memory-os
git pull --rebase origin main

# 2. Check memory lock
ls -la memory.lock 2>/dev/null && echo "⚠️ LOCK ACTIVE — do not write!" || echo "✅ No lock"

# 3. Check external API access (replace with your API)
curl -s --max-time 5 https://your-api-endpoint.com | head -3

# 4. Check watchdog log
tail -10 runtime/WATCHDOG-LOG.md
```

---

## What to read next

```bash
cat runtime/AGENT-A-HANDOFF.md   # production status from Agent A
cat runtime/AGENT-B-STATUS.md    # my open tasks
head -80 MASTER.md               # project overview
```

---

## Session algorithm

1. Read `AGENT-A-HANDOFF.md` → understand production status
2. Read `AGENT-B-STATUS.md` → remember where I left off
3. Ask owner about priorities if no explicit tasks
4. Work → form spec/roadmap → send to owner immediately
5. Done → update `runtime/AGENT-B-HANDOFF.md` + `runtime/AGENT-B-STATUS.md` + `git push`

---

## Rules in one line each

- `AGENT-B-*` I write | `AGENT-A-*` read only
- No direct SSH to production — only through Handoff to Agent A
- Every spec/roadmap → immediately to owner
- On memory.lock → do not write, alert owner
