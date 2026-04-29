# Agent Memory OS

**7-layer durable memory architecture for multi-agent AI systems.**

Built for teams running two or more AI agents (e.g. one for production ops, one for development) that need to share context reliably across sessions — without conflicts, data loss, or hallucinations from stale context.

---

## The Problem

AI agents lose context between sessions. When you run multiple agents on different servers, they overwrite each other's memory, create git conflicts, and wake up confused about what happened while they were offline.

## The Solution

A structured, git-backed memory system with 7 layers of protection:

| Layer | Name | What it does |
|-------|------|-------------|
| 1 | Git Durable Memory | Every memory write is a git commit. Full history, rollback anytime. |
| 2 | Asymmetric Write (CQRS) | Each agent writes ONLY to its own files. Zero conflicts by design. |
| 3 | Context Compiler | `prepare-new.sh` assembles a clean startup payload on every `/new`. |
| 4 | Memory Watchdog | `memory-healthcheck.sh` runs every 30min. Detects corruption, raises lock. |
| 5 | Blast Radius Control | Identity constitutions define hard boundaries for each agent. |
| 6 | Point-in-Time Backup | `backup-memory.sh` sends a tar.gz to Telegram every 3 days. |
| 7 | Human Vault | Critical docs delivered to the human owner via Telegram immediately. |

---

## Quick Start

### 1. Clone and configure

```bash
git clone https://github.com/YOUR_ORG/agent-memory-os.git
cd agent-memory-os
```

Edit the following placeholders in all files:
- `YOUR_TG_BOT_TOKEN` — Telegram bot token for alerts
- `YOUR_TG_CHAT_ID` — your Telegram user ID
- `YOUR_PRODUCTION_SERVER_IP` / `YOUR_DEV_SERVER_IP`
- `Agent A` / `Agent B` — rename to your agents

### 2. Set up cron jobs

```bash
# Memory watchdog — every 30 minutes
*/30 * * * * /path/to/agent-memory-os/scripts/memory-healthcheck.sh >> /path/to/agent-memory-os/runtime/watchdog-cron.log 2>&1

# Backup — every 3 days at 03:00
0 3 */3 * * /path/to/agent-memory-os/scripts/backup-memory.sh >> /path/to/agent-memory-os/runtime/backup-cron.log 2>&1
```

### 3. Agent startup command

Add this to your agent's system prompt or `/new` handler:

```bash
cd /path/to/agent-memory-os && \
git pull --rebase origin main && \
bash scripts/prepare-new.sh agent-a && \
cat compiled/agent-a-context.txt
```

---

## Repository Structure

```
agent-memory-os/
├── scripts/
│   ├── prepare-new.sh          # Context Compiler (Layer 3)
│   ├── memory-healthcheck.sh   # Memory Watchdog (Layer 4)
│   └── backup-memory.sh        # Point-in-Time Backup (Layer 6)
├── identity/
│   ├── IDENTITY-AGENT-A.md     # Agent A constitution (ops)
│   └── IDENTITY-AGENT-B.md     # Agent B constitution (dev)
├── bootstrap/
│   ├── BOOTSTRAP-AGENT-A.md    # Agent A startup checklist
│   └── BOOTSTRAP-AGENT-B.md    # Agent B startup checklist
├── runtime/
│   ├── AGENT-A-HANDOFF.md      # Agent A → Agent B async messages
│   ├── AGENT-B-HANDOFF.md      # Agent B → Agent A async messages
│   ├── AGENT-A-STATUS.md       # Agent A current state
│   ├── AGENT-B-STATUS.md       # Agent B current state
│   └── WATCHDOG-LOG.md         # Watchdog event history
├── blueprints/                 # Full recovery maps per agent
├── infra/                      # Infrastructure docs
├── compiled/                   # Generated context payloads (gitignored)
├── MASTER.md                   # Single source of truth
└── OPERATING-MODEL.md          # v2 architecture spec
```

---

## Asymmetric Write Rule

The core principle that eliminates git conflicts:

```
Agent A  →  writes: AGENT-A-*, runtime/AGENT-A-*
            reads:  AGENT-B-*, MASTER.md, identity/, bootstrap/

Agent B  →  writes: AGENT-B-*, runtime/AGENT-B-*
            reads:  AGENT-A-*, MASTER.md, identity/, bootstrap/
```

No agent ever writes to another agent's files. Ever.

---

## Alert Protocol

When the watchdog detects a problem:
1. Creates `memory.lock` with reason and timestamp
2. Sends Telegram alert to owner: 🚨 `[AGENT MEMORY LOCK]`
3. Exits with code `42`

Owner response:
1. Ask the agent "what happened?"
2. Agent investigates and fixes
3. Tell agent "remove the lock"
4. Agent verifies integrity and deletes `memory.lock`

---

## Requirements

- bash 4+
- git
- curl
- awk, sed, tar (standard GNU utils)
- A Telegram bot token (for alerts and backups)

No Node.js. No databases. No dependencies beyond standard Linux tools.

---

## License

MIT — use freely, attribution appreciated.

---

*Built by [Swarm-Hbtech](https://github.com/Swarm-Hbtech) in production. Battle-tested.*
