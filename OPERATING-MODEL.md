# OPERATING-MODEL.md
# Операционная модель: Swarm + Opus.Dev + Igor
# v2.0 — утверждена 2026-04-28

**Авторы:** Swarm 🛡️ + Gemini (аудит) + Igor (слои 6-7)
**Статус:** Утверждена к реализации

---

## Назначение этого документа

Единственный авторитетный источник правил взаимодействия двух AI-агентов (Swarm и Opus.Dev)
и их владельца (Igor). Все остальные файлы памяти подчиняются этой модели.

---

## Роли в системе

### Swarm 🛡️
- **Дом:** Timeweb MSK-1, YOUR_PRODUCTION_IP
- **Роль:** Production Ops / Deploy / Incident Response
- **Зона:** всё что на Timeweb: PM2, nginx, postgres, openclaw prod, боты
- **Не делает без явной задачи:** глубокую разработку, архитектуру новых модулей

### Opus.Dev 🧠
- **Дом:** Amsterdam, YOUR_DEV_IP
- **Роль:** Development / Architecture / Code Authoring
- **Зона:** code, architecture, project docs, staging
- **Не делает без явной задачи:** production operations на Timeweb

### Igor 👤
- **Роль:** Human Owner / Source of Intent / Final Arbiter
- **Зона:** приоритеты, бизнес-контекст, подтверждение важных действий
- **Human Vault:** хранит ключевые файлы в Telegram бессрочно

---

## Архитектура памяти v2 — 7 слоёв

```
Слой 1: Durable Memory     — Git-репозиторий как долговременное хранилище
Слой 2: Asymmetric Write   — каждый агент пишет только в свои файлы
Слой 3: Context Compiler   — bash-скрипт собирает стартовый payload
Слой 4: Memory Watchdog    — превентивный мониторинг целостности памяти
Слой 5: Blast Radius       — OS-level ограничения на запись
Слой 6: Point-in-Time      — tar.gz слепок каждые 3-5 дней + offsite
Слой 7: Human Vault        — важные файлы отправляются Igor в Telegram
```

---

## Слой 1: Durable Memory (Git)

**Репозиторий:** `github.com/YOUR_GITHUB_ORG/agent-memory-os`
**Ветка:** `main` (в будущем переименовать в `main`)

**Правила:**
- Git = долговременное хранилище, не real-time coordination bus
- Перед записью: `git pull --rebase origin main`
- После записи: commit + push
- Конфликтов почти нет, потому что запись асимметрична (Слой 2)

---

## Слой 2: Asymmetric Write Model (CQRS)

**Ключевое правило:** агент пишет ТОЛЬКО в свои файлы, читает всё.

### Swarm пишет в:
```
runtime/SWARM-STATUS.md
runtime/SWARM-HANDOFF.md
SWARM-BLUEPRINT.md
02-INFRA/SERVERS.md (production side)
```

### Opus.Dev пишет в:
```
runtime/OPUS-STATUS.md
runtime/OPUS-HANDOFF.md
OPUS-DEV-BLUEPRINT.md
projects/* (новые доки)
```

### Shared Core (редко, только по явной задаче):
```
MASTER.md
MEMORY.md
USER.md
OPERATING-MODEL.md
02-INFRA/SSH-TRUST.md
```

**Правило Blast Radius:** агент НЕ редактирует IDENTITY-файл другого агента.
Нарушение = стоп и алерт Igor.

---

## Слой 3: Context Compiler (prepare-new.sh)

**Требования:**
- только bash + awk/sed/cat + системный Python
- работает при мёртвом PM2, упавшей БД, режиме выживания
- НЕ зависит от Node.js или app runtime

**Что собирает:**
1. Identity агента (кто я, где я)
2. Bootstrap (что делать сейчас)
3. Handoff второго агента (что передал)
4. Critical infra markers
5. Current priorities

**Выход:**
- `compiled/swarm-context.txt` — для Swarm
- `compiled/opus-context.txt` — для Opus.Dev
- Минимум markdown-украшений, только структурированный plain text

**Запуск:** при каждом `/new`

---

## Слой 4: Memory Watchdog (memory-healthcheck.sh)

**Режим:** превентивный watchdog, не только on-demand

**Триггеры тревоги:**
- core-файл уменьшился > 30% внезапно
- появились git conflict markers (`<<<<<<<`)
- исчез critical файл (MASTER, IDENTITY, SWARM-BLUEPRINT)
- файл стал пустым
- IDENTITY-SWARM.md изменён Opus-агентом (и наоборот)

**Действия при тревоге:**
1. Создать `memory.lock` → заблокировать запись
2. Алерт Igor через Telegram бота
3. Зафиксировать событие в `runtime/WATCHDOG-LOG.md`
4. НЕ пытаться автоисправить — ждать подтверждения

**Запуск:** cron каждые 30 минут

---

## Слой 5: Blast Radius Control

**Физические ограничения:**

### На Swarm (Timeweb):
```bash
# OPUS-файлы: только чтение для openclaw
chown root:root agent-memory-os/runtime/OPUS-*.md
chmod 644 agent-memory-os/runtime/OPUS-*.md  # r/o для записи агентом

# IDENTITY-SWARM: только Swarm пишет
chown openclaw:openclaw IDENTITY-SWARM.md
chmod 644 IDENTITY-SWARM.md
```

### CRITICAL_INFRA маркировка:
Следующие компоненты помечены как `[CRITICAL_INFRA: DO_NOT_TOUCH]`:
- xray / WARP / proxy конфиги
- OpenClaw gateway
- nginx / SSL
- SSH authorized_keys
- PM2 critical services (ozon-bot, gamacchi-prod)

Агент НЕ трогает CRITICAL_INFRA без явной команды Igor.

---

## Слой 6: Point-in-Time Backup (3-2-1 Rule)

**Расписание:** каждые 3-5 дней (cron на обоих серверах)

**Что бэкапируется:**
- `/home/openclaw/agent-memory-os/` → tar.gz с датой
- git tag с именем `backup-YYYY-MM-DD`

**Offsite доставка (физически отвязана от контура исполнения):**
- tar.gz отправляется в приватный Telegram-канал (через бота)
- ИЛИ на S3-совместимое хранилище (Timeweb Object Storage)

**Ротация:** хранить последние 4 слепка

**RPO (Recovery Point Objective):** ≤ 2 дня потерь данных

**Cron пример:**
```bash
0 2 */3 * * /home/openclaw/agent-memory-os/scripts/backup-memory.sh
```

---

## Слой 7: Human Vault (Telegram)

**Правило:** каждый roadmap-файл и проработанное ТЗ немедленно отправляется Igor в Telegram файлом.

**Триггеры отправки:**
- создан новый `projects/*.md`
- обновлён `roadmap-*.md`
- завершено ТЗ / архитектурный документ
- существенное обновление MASTER.md

**Транспорт:** OpenClaw message tool → Telegram → Igor (ID: YOUR_TG_CHAT_ID)

**Почему это надёжнее всего:**
- Telegram хранит файлы бессрочно
- не зависит ни от одного сервера
- не зависит от GitHub
- не зависит от агентов
- Igor читает → контекст восстанавливается мгновенно

---

## Структура репозитория памяти (целевая)

```
agent-memory-os/
├── OPERATING-MODEL.md          ← этот файл
├── MASTER.md                   ← конституция проекта
├── MEMORY.md                   ← долговременная память
├── USER.md                     ← про Igor
│
├── identity/
│   ├── IDENTITY-SWARM.md
│   └── IDENTITY-OPUS.md
│
├── runtime/                    ← меняются часто, асимметричная запись
│   ├── SWARM-STATUS.md
│   ├── SWARM-HANDOFF.md
│   ├── OPUS-STATUS.md
│   ├── OPUS-HANDOFF.md
│   └── WATCHDOG-LOG.md
│
├── bootstrap/
│   ├── BOOTSTRAP-SWARM.md
│   └── BOOTSTRAP-OPUS.md
│
├── blueprints/
│   ├── SWARM-BLUEPRINT.md
│   └── OPUS-DEV-BLUEPRINT.md
│
├── infra/
│   ├── SERVERS.md
│   ├── SSH-TRUST.md
│   ├── DOMAINS.md
│   └── RECOVERY-PROTOCOL.md
│
├── projects/
│   ├── gamacchi/
│   ├── ozon/
│   ├── dds/
│   ├── oc-gd/
│   ├── pdf-shield/
│   └── bis/
│
├── compiled/                   ← генерируются скриптами, не редактировать
│   ├── swarm-context.txt
│   └── opus-context.txt
│
├── scripts/
│   ├── prepare-new.sh          ← context compiler (bash only)
│   ├── memory-healthcheck.sh   ← watchdog
│   ├── backup-memory.sh        ← offsite backup
│   └── resurrect-swarm.sh
│
└── archive/
    └── ...
```

---

## Протокол старта сессии (обязателен для обоих агентов)

### При каждом /new — Swarm читает:
```bash
cd /home/openclaw/agent-memory-os
git pull --rebase origin main
cat compiled/swarm-context.txt
# если compiled не существует:
cat identity/IDENTITY-SWARM.md
cat bootstrap/BOOTSTRAP-SWARM.md
cat runtime/OPUS-HANDOFF.md
cat MASTER.md | head -80
```

### При каждом /new — Opus.Dev читает:
```bash
cd /root/openclaw-memory
git pull --rebase origin main
cat compiled/opus-context.txt
# если compiled не существует:
cat identity/IDENTITY-OPUS.md
cat bootstrap/BOOTSTRAP-OPUS.md
cat runtime/SWARM-HANDOFF.md
cat MASTER.md | head -80
```

---

## Протокол взаимного восстановления

### Уровень 1 — контекстная амнезия (агент жив, но забыл себя)
Igor пишет агенту:
```
Прочитай OPERATING-MODEL.md и свой IDENTITY файл из репо
YOUR_GITHUB_ORG/agent-memory-os, ветка main
```
Решается за минуты.

### Уровень 2 — сессия сломана, агент жив
Igor или другой агент даёт команду запустить:
```bash
bash /home/openclaw/agent-memory-os/scripts/prepare-new.sh swarm
```

### Уровень 3 — сервер мёртв, полное восстановление
```bash
git clone git@github.com:YOUR_GITHUB_ORG/agent-memory-os.git
cd agent-memory-os && git checkout main
bash scripts/resurrect-swarm.sh
```
Если Git недоступен → восстановление из tar.gz слепка (Слой 6) или от Igor (Слой 7).

---

## Правила ведения MASTER.md

1. Только высокоуровневые факты
2. Без логов, хвостов сессий, инцидентного шума
3. Обновлять только при изменении состояния системы
4. После каждого обновления MASTER.md — отправить файлом Igor в Telegram

---

## Правила записи памяти — куда что писать

| Тип информации | Куда писать |
|---------------|------------|
| Устойчивые факты о системе | MEMORY.md |
| Состояние проектов | MASTER.md |
| Текущий handoff | runtime/SWARM-HANDOFF.md или OPUS-HANDOFF.md |
| Архитектура / ТЗ | projects/[проект]/ |
| Инциденты, отладка | daily/ |
| Временные заметки | daily/ |
| Старые session-restore файлы | archive/ |

---

## Migration Plan: текущее → v2

### Sprint 1 — Foundation (приоритет)
- [ ] Создать `identity/IDENTITY-SWARM.md`
- [ ] Создать `identity/IDENTITY-OPUS.md`
- [ ] Создать `bootstrap/BOOTSTRAP-SWARM.md`
- [ ] Создать `bootstrap/BOOTSTRAP-OPUS.md`
- [ ] Создать `runtime/` с SWARM/OPUS файлами
- [ ] Создать `infra/SERVERS.md`
- [ ] Создать `infra/SSH-TRUST.md`
- [ ] Создать `infra/RECOVERY-PROTOCOL.md`
- [ ] Заполнить `USER.md`
- [ ] Обновить `MEMORY.md`

### Sprint 2 — Automation
- [ ] Написать `scripts/prepare-new.sh` (bash only)
- [ ] Написать `scripts/memory-healthcheck.sh`
- [ ] Написать `scripts/backup-memory.sh` (offsite)
- [ ] Настроить cron watchdog (каждые 30 мин)
- [ ] Настроить cron backup (каждые 3-5 дней)

### Sprint 3 — Hardening
- [ ] ACL / chmod для asym. write boundaries
- [ ] SSH mutual trust (проверить и задокументировать)
- [ ] Первый offsite backup → Telegram канал
- [ ] Прогнать сценарий полного восстановления

---

_"Любая, даже самая совершенная система, рано или поздно ляжет.
Разница между надёжной и ненадёжной системой — не в том, ложится ли она,
а в том, сколько она теряет и как быстро встаёт."_
— Igor D, 2026-04-28
