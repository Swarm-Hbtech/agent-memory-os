# AGENT-A-BLUEPRINT.md
# Agent A full recovery map

## Server
- IP: YOUR_PRODUCTION_SERVER_IP
- OS: Ubuntu 24.04
- User: your_user

## Services
| Name | Port | Description |
|------|------|-------------|
| service-1 | 3000 | [description] |

## How to restart everything
```bash
# Add your recovery commands here
pm2 resurrect
```
