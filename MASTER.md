# MASTER.md — [Your Project Name]
## Single source of truth

**Version:** 1.0
**Owner:** [Your Name]
**Maintained by:** Agent A (ops) + Agent B (arch/dev)

---

## 1. Organization

**[Company Name]** — [brief description]

---

## 2. Infrastructure

### Servers

| Role | Name | IP | Resources | Services |
|------|------|----|-----------|---------|
| 🧠 Brain | Agent-B | YOUR_DEV_IP | 2 CPU / 4GB | Dev, OpenClaw |
| 🏭 Production | Agent-A | YOUR_PROD_IP | 4 CPU / 8GB | Production |

---

## 3. AI Team

| Agent | Role | Server |
|-------|------|--------|
| Agent A | Production Ops & Incident Response | Production |
| Agent B | Architect & Developer | Dev |

**Owner:** [Your Name]

---

## 4. Memory Architecture (7 Layers)

| Layer | Component | File | Status |
|-------|-----------|------|--------|
| 1 | Git Durable Memory | git history | ✅ |
| 2 | Asymmetric Write (CQRS) | AGENT-A-* / AGENT-B-* split | ✅ |
| 3 | Context Compiler | `scripts/prepare-new.sh` | ✅ |
| 4 | Memory Watchdog | `scripts/memory-healthcheck.sh` | ✅ cron */30 |
| 5 | Blast Radius Control | `identity/` constitutions | ✅ |
| 6 | Point-in-Time Backup | `scripts/backup-memory.sh` | ✅ cron 0 3 */3 |
| 7 | Human Vault | Telegram → Owner | ✅ |

---

## 5. Projects

### ✅ [Project 1] — PRODUCTION
[Brief description]

### 🔲 [Project 2] — IN PROGRESS
[Brief description]

---

## 6. Principles

- **Radical honesty** — agents ask when unclear, never simulate activity
- **Blast radius under control** — wide-impact changes only after owner approval
- **Asymmetric write** — Agent A writes AGENT-A-*, Agent B writes AGENT-B-*, no conflicts
- **Every spec/roadmap** → immediately to owner
