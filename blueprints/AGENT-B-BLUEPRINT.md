# AGENT-B-BLUEPRINT.md
# Agent B full recovery map

## Server
- IP: YOUR_DEV_SERVER_IP
- OS: Ubuntu 24.04
- User: your_user

## Key paths
- OpenClaw config: /path/to/.openclaw/
- Memory repo: /path/to/agent-memory-os/

## How to restart
```bash
# Add your recovery commands here
systemctl --user restart openclaw-gateway
```
