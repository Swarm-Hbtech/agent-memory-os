# OPERATING-MODEL.md
# Operating Model: Multi-Agent Memory System
# v2.0

**Status:** Production-ready template

---

## Purpose

Single authoritative source of interaction rules between two AI agents (Agent A and Agent B)
and their human owner. All other memory files are subordinate to this model.

---

## Roles

### Agent A 🏭
- **Home:** Production server
- **Role:** Production Ops / Deploy / Incident Response
- **Zone:** everything on production: process manager, reverse proxy, databases, bots
- **Does NOT do without explicit task:** deep development, architecture of new modules

### Agent B 🧠
- **Home:** Development server
- **Role:** Development / Architecture / Code Authoring
- **Zone:** code, architecture, project docs, staging
- **Does NOT do without explicit task:** production operations

### Owner 👤
- **Role:** Human Owner / Source of Intent / Final Arbiter
- **Zone:** priorities, business context, approval of important actions
- **Human Vault:** stores critical files in Telegram indefinitely

---

## Memory Architecture v2 — 7 Layers

```
Layer 1: Durable Memory     — Git repository as long-term storage
Layer 2: Asymmetric Write   — each agent writes only to its own files
Layer 3: Context Compiler   — bash script assembles startup payload
Layer 4: Memory Watchdog    — preventive integrity monitoring
Layer 5: Blast Radius       — OS-level write restrictions
Layer 6: Point-in-Time      — tar.gz snapshot every 3-5 days + offsite
Layer 7: Human Vault        — critical files sent to owner via Telegram
```

---

## Layer 1: Durable Memory (Git)

**Repository:** `github.com/YOUR_ORG/agent-memory-os`
**Branch:** `main`

**Rules:**
- Git = long-term storage, not real-time coordination bus
- Before writing: `git pull --rebase origin main`
- After writing: commit + push
- Conflicts are nearly impossible because writes are asymmetric (Layer 2)

---

## Layer 2: Asymmetric Write Model (CQRS)

**Key rule:** an agent writes ONLY to its own files, reads everything.

### Agent A writes to:
```
runtime/AGENT-A-STATUS.md
runtime/AGENT-A-HANDOFF.md
blueprints/AGENT-A-BLUEPRINT.md
infra/SERVERS.md (production side)
```

### Agent B writes to:
```
runtime/AGENT-B-STATUS.md
runtime/AGENT-B-HANDOFF.md
blueprints/AGENT-B-BLUEPRINT.md
projects/* (new docs)
```

### Shared Core (rarely, only by explicit task):
```
MASTER.md
OPERATING-MODEL.md
infra/SSH-TRUST.md
```

**Blast Radius Rule:** an agent NEVER edits the other agent's IDENTITY file.
Violation = stop and alert owner.

---

## Layer 3: Context Compiler (prepare-new.sh)

**Requirements:**
- bash only + awk/sed/cat + system Python
- works with dead process manager, crashed DB, survival mode
- does NOT depend on Node.js or app runtime

**What it assembles:**
1. Agent identity (who am I, where am I)
2. Bootstrap (what to do now)
3. Handoff from the other agent (what they passed)
4. Critical infra markers
5. Current priorities

**Output:**
- `compiled/agent-a-context.txt` — for Agent A
- `compiled/agent-b-context.txt` — for Agent B

**Run:** on every `/new` session start

---

## Layer 4: Memory Watchdog (memory-healthcheck.sh)

**Mode:** preventive watchdog, not just on-demand

**Alert triggers:**
- core file missing
- core file empty
- core file shrank > 30% suddenly
- git conflict markers found (`<<<<<<<`)
- one agent's IDENTITY file modified by the other agent

**Actions on alert:**
1. Create `memory.lock` → block all writes
2. Alert owner via Telegram bot
3. Log event in `runtime/WATCHDOG-LOG.md`
4. Do NOT attempt auto-fix — wait for owner confirmation

**Schedule:** cron every 30 minutes

---

## Layer 5: Blast Radius Control

**Physical restrictions:**

### On production server:
```bash
# Agent B files: read-only for Agent A
chown root:root agent-memory-os/runtime/AGENT-B-*.md
chmod 644 agent-memory-os/runtime/AGENT-B-*.md
```

### CRITICAL_INFRA marking:
The following components are marked `[CRITICAL_INFRA: DO_NOT_TOUCH]`:
- Reverse proxy configs (nginx/caddy)
- Gateway service
- SSL certificates
- SSH authorized_keys
- Critical production services

Agent does NOT touch CRITICAL_INFRA without explicit owner command.

---

## Layer 6: Point-in-Time Backup (3-2-1 Rule)

**Schedule:** every 3-5 days (cron on both servers)

**What gets backed up:**
- Full memory repo → tar.gz with date
- git tag: `backup-YYYY-MM-DD`

**Offsite delivery (physically decoupled from execution):**
- tar.gz sent to private Telegram channel (via bot)
- OR to S3-compatible storage

**Rotation:** keep last 4 snapshots

**RPO (Recovery Point Objective):** ≤ 2 days of data loss

**Cron example:**
```bash
0 3 */3 * * /path/to/agent-memory-os/scripts/backup-memory.sh
```

---

## Layer 7: Human Vault (Telegram)

**Rule:** every roadmap file and completed spec is immediately sent to owner via Telegram.

**Send triggers:**
- new `projects/*.md` created
- `roadmap-*.md` updated
- spec / architecture document completed
- significant MASTER.md update

**Why this is the most reliable:**
- Telegram stores files indefinitely
- independent of any server
- independent of GitHub
- independent of agents
- Owner reads → context restored instantly

---

## Repository Structure (target)

```
agent-memory-os/
├── OPERATING-MODEL.md          ← this file
├── MASTER.md                   ← single source of truth
│
├── identity/
│   ├── IDENTITY-AGENT-A.md
│   └── IDENTITY-AGENT-B.md
│
├── runtime/                    ← changes often, asymmetric write
│   ├── AGENT-A-STATUS.md
│   ├── AGENT-A-HANDOFF.md
│   ├── AGENT-B-STATUS.md
│   ├── AGENT-B-HANDOFF.md
│   └── WATCHDOG-LOG.md
│
├── bootstrap/
│   ├── BOOTSTRAP-AGENT-A.md
│   └── BOOTSTRAP-AGENT-B.md
│
├── blueprints/
│   ├── AGENT-A-BLUEPRINT.md
│   └── AGENT-B-BLUEPRINT.md
│
├── infra/
│   ├── SERVERS.md
│   ├── SSH-TRUST.md
│   ├── DOMAINS.md
│   └── RECOVERY-PROTOCOL.md
│
├── projects/                   ← project-specific docs
│
├── compiled/                   ← generated by scripts, do not edit
│   ├── agent-a-context.txt
│   └── agent-b-context.txt
│
├── scripts/
│   ├── prepare-new.sh          ← context compiler (bash only)
│   ├── memory-healthcheck.sh   ← watchdog
│   └── backup-memory.sh        ← offsite backup
│
└── archive/                    ← old/superseded documents
```

---

## Session Startup Protocol (mandatory for both agents)

### On every /new — Agent A reads:
```bash
cd /path/to/agent-memory-os
git pull --rebase origin main
bash scripts/prepare-new.sh agent-a
cat compiled/agent-a-context.txt
```

### On every /new — Agent B reads:
```bash
cd /path/to/agent-memory-os
git pull --rebase origin main
bash scripts/prepare-new.sh agent-b
cat compiled/agent-b-context.txt
```

---

## Mutual Recovery Protocol

### Level 1 — Context amnesia (agent alive but forgot itself)
Owner tells the agent:
```
Read OPERATING-MODEL.md and your IDENTITY file from the repo
github.com/YOUR_ORG/agent-memory-os, branch main
```
Resolved in minutes.

### Level 2 — Session broken, agent alive
Owner or other agent runs:
```bash
bash /path/to/agent-memory-os/scripts/prepare-new.sh agent-a
```

### Level 3 — Server dead, full recovery
```bash
git clone git@github.com:YOUR_ORG/agent-memory-os.git
cd agent-memory-os && git checkout main
# Follow AGENT-A-BLUEPRINT.md or AGENT-B-BLUEPRINT.md for full recovery
```
If Git unavailable → restore from tar.gz snapshot (Layer 6) or from owner (Layer 7).

---

## MASTER.md Rules

1. Only high-level facts
2. No logs, session tails, incident noise
3. Update only when system state changes
4. After every MASTER.md update → send file to owner via Telegram

---

## Memory Write Rules — Where to Write What

| Type of information | Where to write |
|---------------------|---------------|
| Stable system facts | MASTER.md |
| Current handoff | runtime/AGENT-A-HANDOFF.md or AGENT-B-HANDOFF.md |
| Architecture / specs | projects/ |
| Incidents, debugging | archive/ or daily notes |
| Temporary notes | runtime/*-STATUS.md |

---

## Principles

- **Radical honesty** — agents ask when unclear, never simulate activity
- **Blast radius under control** — wide-impact changes only after owner approval
- **Asymmetric write** — Agent A writes AGENT-A-*, Agent B writes AGENT-B-*, no conflicts
- **Every spec/roadmap** → immediately to owner

---

_"Any system, no matter how perfect, will eventually go down.
The difference between a reliable and unreliable system is not whether it goes down,
but how much it loses and how fast it recovers."_
