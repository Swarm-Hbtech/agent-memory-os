# Project Chronicle — Agent Memory OS

_Последнее обновление: 2026-05-21_

## Текущее состояние

Open-source шаблон 7-слойной архитектуры памяти для мультиагентных AI-систем. Рабочее состояние — все скрипты проверены, шаблоны заполнены, готов к использованию.

## История

| Дата | Событие |
|------|---------|
| 2026-04-28 | Операционная модель v2 утверждена (7 слоёв) |
| 2026-04-29 | Репозиторий создан, скрипты перенесены из рабочей системы |
| 2026-04-29 | Обезличивание: Swarm/Opus → Agent-A/Agent-B |
| 2026-05-21 | Mind Palace: исправлены рассинхроны в скриптах, добавлены LICENSE, WATCHDOG-LOG, projects/, archive/ |

## Карта файлов

| Файл/Директория | Назначение | Статус |
|-----------------|-----------|--------|
| README.md | Точка входа, Quick Start | ✅ Актуален |
| OPERATING-MODEL.md | Полная спецификация 7 слоёв | ✅ Актуален |
| MASTER.md | Шаблон single source of truth | 📝 Шаблон |
| LICENSE | MIT лицензия | ✅ |
| identity/ | Конституции агентов (кто я, что делаю) | 📝 Шаблон |
| bootstrap/ | Стартовые чеклисты | 📝 Шаблон |
| blueprints/ | Карты восстановления | 📝 Шаблон |
| runtime/ | Handoff + Status (асимметричная запись) | 📝 Шаблон |
| infra/ | Инфраструктура (серверы, домены) | 📝 Шаблон |
| projects/ | Проектная документация | 📁 Пустой |
| archive/ | Устаревшие документы | 📁 Пустой |
| compiled/ | Генерируемые контексты (gitignored) | ⚙️ Auto |
| scripts/prepare-new.sh | Context Compiler (Layer 3) | ✅ Рабочий |
| scripts/memory-healthcheck.sh | Memory Watchdog (Layer 4) | ✅ Рабочий |
| scripts/backup-memory.sh | Point-in-Time Backup (Layer 6) | ✅ Рабочий |

## Ключевые решения

- **Asymmetric Write (CQRS):** каждый агент пишет только в свои файлы → zero git conflicts by design
- **Bash-only скрипты:** работают при мёртвом Node.js/PM2/БД — режим выживания
- **7 слоёв защиты:** от git (Layer 1) до Human Vault в Telegram (Layer 7)
- **Generic naming:** Agent-A/Agent-B вместо конкретных имён — переиспользуемость

## Участники

| Роль | Кто |
|------|-----|
| Архитектор | Opus.Dev (AI) |
| Владелец | Igor Dvoretskiy |
| Аудит | Gemini (одноразовый) |

## Бэклог

- [ ] Добавить `infra/SSH-TRUST.md`, `infra/DOMAINS.md`, `infra/RECOVERY-PROTOCOL.md` (шаблоны)
- [ ] Сделать репо public (когда решим)
- [ ] Добавить GitHub Actions для автоматического healthcheck
- [ ] Написать CONTRIBUTING.md

---

Related: memory/2026-05-21.md (Mind Palace session), memory/OPERATING-MODEL.md (рабочая копия)
