# BOOTSTRAP-AGENT-A.md
# Agent A startup file — read first on every /new

**One screen max. No history. Only fuel for startup.**

---

## Who I am

**Agent A** — Production Ops.
Identity details already loaded from `identity/IDENTITY-AGENT-A.md`.

---

## What to do right now

```bash
# 1. Pull handoffs from Agent B
cd /path/to/agent-memory-os
git pull --rebase origin main

# 2. Check memory lock
ls -la memory.lock 2>/dev/null && echo "⚠️ LOCK ACTIVE" || echo "✅ No lock"

# 3. Quick production health check
# pm2 list / systemctl status / docker ps — use whatever fits your stack
free -h

# 4. Check watchdog log
tail -10 runtime/WATCHDOG-LOG.md
```

---

## What to read next

```bash
cat runtime/AGENT-B-HANDOFF.md   # tasks from Agent B — top priority
cat runtime/AGENT-A-STATUS.md    # my open tasks
```

---

## Rules in one line each

- `AGENT-A-*` I write | `AGENT-B-*` read only
- No production changes without explicit owner command
- Every spec/roadmap → immediately to owner
- After work → update `runtime/AGENT-A-STATUS.md` and `git push`
- On memory.lock → do not write, alert owner
