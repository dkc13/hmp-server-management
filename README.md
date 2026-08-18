# HappinessMP Server Management

A simple, lightweight Linux bash management toolset designed specifically for **HappinessMP** servers running on **Linux VPS / Dedicated servers**.

This toolset automates server execution using `screen`, handles graceful/force shutdowns, monitors system resource usage, checks ports and firewall rules, and manages scheduled daily restarts.

---

## Requirements

- **Operating System:** Linux (Ubuntu, Debian, CentOS, etc.)
- **Privileges:** Root access (`sudo` / `root`)
- **Dependencies:** `screen` (automatically installed if missing)

---

## Features

- **Linux Process Management:** Start, stop, force-kill, and restart your server safely in background screen sessions.
- **Graceful Shutdown:** Sends native in-game `stop` / `restart` commands and waits for server confirmation before killing processes.
- **Port & Firewall Guard:** Verifies open ports and UFW firewall configuration on Linux prior to launching.
- **Resource Monitoring:** Live overview of Linux process uptime, CPU, RAM, and overall VPS machine statistics.
- **Cron Auto-Restart:** Configures native Linux cron jobs for scheduled daily server restarts.
- **Interactive Setup:** Easy step-by-step installer with custom server paths and prefix selection.

---

## Installation (Linux)

Run the interactive installer as `root` in your Linux terminal:

```
rm -f install-hmp-server-management.sh* && wget https://raw.githubusercontent.com/dkc13/hmp-server-management/main/install-hmp-server-management.sh && sed -i 's/\r$//' install-hmp-server-management.sh && chmod +x install-hmp-server-management.sh && sudo ./install-hmp-server-management.sh
```

> **Note:** Ensure `HappinessMP.Server.out` exists in your server directory during installation (or specify your custom Linux path when prompted).

---

## Available Commands

All management commands use the default `hmp-` prefix (customizable during setup):

| Command | Description |
| :--- | :--- |
| `hmp-start` | Starts the server in a background Linux `screen` session. |
| `hmp-console` | Attaches to the active server console (*Detach with `Ctrl+A, D`*). |
| `hmp-stop` | Sends a graceful `stop` command to the server console. |
| `hmp-force` | Instantly force-kills the server process and screen session. |
| `hmp-restart` | Gracefully restarts the server. |
| `hmp-status` | Displays real-time Linux process stats, CPU/RAM usage, uptime, and auto-restart status. |
| `hmp-autorestart` | Configures daily auto-restarts via cron (e.g., `hmp-autorestart 04:00` or `off`). |
| `hmp-setdir` | Updates the configured Linux server directory path. |
| `hmp-help` | Displays the list of available commands and descriptions. |
| `hmp-remove` | Stops the server and completely uninstalls all management scripts. |

---

## License

Created by **dkc13**. Open-source and free to use on any Linux environment.
