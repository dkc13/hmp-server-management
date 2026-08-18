#!/bin/bash

# ============================================================
# COLOR PALETTE
# ============================================================
NC='\033[0m'               # No Color / Reset
BOLD='\033[1m'
GRAY='\033[0;90m'

BLUE='\033[1;34m'          # Reserved for Prefix [hmp-server]
CYAN='\033[0;36m'          # Borders & Accent
L_CYAN='\033[1;36m'        # Headers & Commands

GREEN='\033[0;32m'
L_GREEN='\033[1;32m'      # Success / Online

RED='\033[0;31m'
L_RED='\033[1;31m'        # Errors / Offline

YELLOW='\033[1;33m'       # Warnings
WHITE='\033[1;37m'        # Standard Highlight Text

# ============================================================
# CHECK ROOT
# ============================================================

if [ "$EUID" -ne 0 ]; then
    echo -e "${L_RED}ERROR: Please run this installer as root.${NC}"
    exit 1
fi

# Visual clear without wiping terminal scrollback history
clear -x 2>/dev/null || true

HEADER_TITLE="HAPPINESSMP MANAGEMENT COMMANDS INSTALLER"
HEADER_CREDITS="Created by: dkc13 | github.com/dkc13"

echo ""
echo -e "${CYAN}============================================================${NC}"
printf "${BOLD}${WHITE}%*s${NC}\n" $(( (${#HEADER_TITLE} + 60) / 2 )) "$HEADER_TITLE"
printf "${GRAY}%*s${NC}\n" $(( (${#HEADER_CREDITS} + 60) / 2 )) "$HEADER_CREDITS"
echo -e "${CYAN}============================================================${NC}"
echo ""

# ============================================================
# STEP 1: INTERACTIVE DIRECTORY SELECTION
# ============================================================

echo -e "${GRAY}------------------------------------------------------------${NC}"
echo -e "${BOLD}${L_CYAN}STEP 1: Server Directory Selection${NC}"
echo -e "${GRAY}------------------------------------------------------------${NC}"

SERVER_DIR=""

if [ -f "$PWD/HappinessMP.Server.out" ]; then
    echo -e "${L_GREEN}HappinessMP binary found in current directory:${NC}"
    echo -e "  ${GRAY}->${NC} ${WHITE}$PWD${NC}"
    read -r -p "Do you want to use this directory? [yes/no]: " USE_PWD
    USE_PWD_LOWER=$(echo "$USE_PWD" | tr '[:upper:]' '[:lower:]')
    if [ -z "$USE_PWD" ] || [[ "$USE_PWD_LOWER" =~ ^y(es)?$ ]]; then
        SERVER_DIR="$PWD"
    fi
fi

while [ -z "$SERVER_DIR" ]; do
    read -e -r -p "Enter full path to your HappinessMP server directory (Use TAB for autocomplete): " INPUT_DIR
    if [ -z "$INPUT_DIR" ]; then
        echo -e "${L_RED}Directory path cannot be empty. Please try again.${NC}"
        continue
    fi
    if [ ! -d "$INPUT_DIR" ]; then
        echo -e "${L_RED}Directory '$INPUT_DIR' does not exist. Please enter a valid path.${NC}"
        continue
    fi
    if [ ! -f "$INPUT_DIR/HappinessMP.Server.out" ]; then
        echo -e "${YELLOW}WARNING: 'HappinessMP.Server.out' was not found in '$INPUT_DIR'.${NC}"
        read -r -p "Use this directory anyway? [yes/no]: " CONFIRM_DIR
        CONFIRM_DIR_LOWER=$(echo "$CONFIRM_DIR" | tr '[:upper:]' '[:lower:]')
        if [[ "$CONFIRM_DIR_LOWER" =~ ^y(es)?$ ]]; then
            SERVER_DIR="$INPUT_DIR"
        fi
    else
        SERVER_DIR="$INPUT_DIR"
    fi
done

echo -e "${L_CYAN}Selected Server Directory:${NC} ${WHITE}$SERVER_DIR${NC}"
echo ""

# ============================================================
# STEP 2: INTERACTIVE PREFIX CONFIGURATION
# ============================================================

echo -e "${GRAY}------------------------------------------------------------${NC}"
echo -e "${BOLD}${L_CYAN}STEP 2: Prefix Configuration${NC}"
echo -e "${GRAY}------------------------------------------------------------${NC}"

DEFAULT_PREFIX="[hmp-server]"
echo -e "Current default prefix is: ${BLUE}$DEFAULT_PREFIX${NC}"
read -r -p "Do you want to change the prefix? [yes/no]: " CHANGE_PREFIX
CHANGE_PREFIX_LOWER=$(echo "$CHANGE_PREFIX" | tr '[:upper:]' '[:lower:]')

if [[ "$CHANGE_PREFIX_LOWER" =~ ^y(es)?$ ]]; then
    read -r -p "Enter custom prefix: " CUSTOM_PREFIX
    PREFIX="${CUSTOM_PREFIX:-$DEFAULT_PREFIX}"
else
    PREFIX="$DEFAULT_PREFIX"
fi

echo -e "${L_CYAN}Selected Prefix:${NC} ${BLUE}$PREFIX${NC}"
echo ""

HMP_BIN="/usr/local/bin"
SERVER_BINARY="$SERVER_DIR/HappinessMP.Server.out"
SCREEN_NAME="hmp-server"
CONF_FILE="/etc/hmp-server.conf"
CRON_FILE="/etc/cron.d/happinessmp-autorestart"
LOG_FILE="/var/log/happinessmp-autorestart.log"

cat > "$CONF_FILE" <<EOF
PREFIX="$PREFIX"
SERVER_DIR="$SERVER_DIR"
SERVER_BINARY="$SERVER_BINARY"
SCREEN_NAME="$SCREEN_NAME"
HMP_BIN="$HMP_BIN"
CRON_FILE="$CRON_FILE"
LOG_FILE="$LOG_FILE"
EOF

# ============================================================
# INSTALL DEPENDENCIES
# ============================================================

P_TAG="${BLUE}${PREFIX}${NC}"

if ! command -v screen >/dev/null 2>&1; then
    echo -e "${P_TAG} ${YELLOW}'screen' package is not installed. Installing...${NC}"
    apt-get update && apt-get install -y screen
    if ! command -v screen >/dev/null 2>&1; then
        echo -e "${P_TAG} ${L_RED}ERROR: Failed to install 'screen'.${NC}"
        exit 1
    fi
    echo -e "${P_TAG} ${L_GREEN}'screen' installed successfully.${NC}"
else
    echo -e "${P_TAG} ${WHITE}'screen' is already installed.${NC}"
fi

# ============================================================
# CLEANUP OLD COMMANDS
# ============================================================

rm -f \
    "$HMP_BIN/hmp-start" "$HMP_BIN/hrp-start" \
    "$HMP_BIN/hmp-console" "$HMP_BIN/hrp-console" \
    "$HMP_BIN/hmp-stop" "$HMP_BIN/hrp-stop" \
    "$HMP_BIN/hmp-force" "$HMP_BIN/hrp-force" \
    "$HMP_BIN/hmp-restart" "$HMP_BIN/hrp-restart" \
    "$HMP_BIN/hmp-status" "$HMP_BIN/hrp-status" \
    "$HMP_BIN/hmp-autorestart" "$HMP_BIN/hrp-autorestart" \
    "$HMP_BIN/hmp-setdir" "$HMP_BIN/hrp-setdir" \
    "$HMP_BIN/hmp-help" "$HMP_BIN/hrp-help" \
    "$HMP_BIN/hmp-remove" "$HMP_BIN/hrp-remove"

rm -f "$CRON_FILE" "/etc/cron.d/happinessroleplay-autorestart"

# ============================================================
# HMP-START
# ============================================================

cat > "$HMP_BIN/hmp-start" <<'EOF'
#!/bin/bash
source /etc/hmp-server.conf 2>/dev/null || { echo "ERROR: Configuration /etc/hmp-server.conf missing."; exit 1; }

NC='\033[0m'
BOLD='\033[1m'
BLUE='\033[1;34m'
CYAN='\033[0;36m'
L_CYAN='\033[1;36m'
L_GREEN='\033[1;32m'
L_RED='\033[1;31m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'

P_TAG="${BLUE}${PREFIX}${NC}"

if ! command -v screen >/dev/null 2>&1; then
    echo -e "${P_TAG} ${L_RED}ERROR: 'screen' is not installed.${NC}"
    exit 1
fi

if [ ! -x "$SERVER_BINARY" ]; then
    echo -e "${P_TAG} ${L_RED}ERROR: Server binary not found or not executable at: $SERVER_BINARY${NC}"
    exit 1
fi

PIDS=$(ps -eo pid=,args= | awk -v bin="$SERVER_BINARY" '$2 == bin {print $1}')
if [ -n "$PIDS" ]; then
    echo -e "${P_TAG} ${L_RED}ERROR: HappinessMP server is already running.${NC}"
    echo -e "${P_TAG} PID(s): ${WHITE}$PIDS${NC}"
    echo -e "${P_TAG} Use '${L_CYAN}hmp-console${NC}' to open server console."
    exit 1
fi

SETTINGS_FILE="$SERVER_DIR/settings.xml"
if [ -f "$SETTINGS_FILE" ]; then
    PORT=$(grep -oP '(?<=<port>)\d+(?=</port>)' "$SETTINGS_FILE" 2>/dev/null || awk -F'[<>]' '/<port>/{print $3}' "$SETTINGS_FILE")
    RELAY_PORT=$(grep -oP '(?<=<relayport>)\d+(?=</relayport>)' "$SETTINGS_FILE" 2>/dev/null || awk -F'[<>]' '/<relayport>/{print $3}' "$SETTINGS_FILE")

    PORT_ISSUES=0

    for P in "$PORT" "$RELAY_PORT"; do
        if [ -n "$P" ]; then
            if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
                if ! ufw status | grep -q "$P"; then
                    echo -e "${P_TAG} ${L_RED}ERROR: Port $P is NOT allowed in UFW firewall rules!${NC}"
                    PORT_ISSUES=1
                fi
            fi

            if command -v ss >/dev/null 2>&1; then
                if ss -tuln | grep -q ":$P "; then
                    echo -e "${P_TAG} ${L_RED}ERROR: Port $P is currently in use by another process!${NC}"
                    PORT_ISSUES=1
                fi
            fi
        fi
    done

    if [ "$PORT_ISSUES" -eq 1 ]; then
        echo -e "${P_TAG} ${YELLOW}WARNING: Port issues detected (Main: $PORT, Relay: $RELAY_PORT). Launching server anyway...${NC}"
    else
        echo -e "${P_TAG} ${WHITE}Port check passed (Main Port: ${L_CYAN}$PORT${NC}, Relay Port: ${L_CYAN}$RELAY_PORT${NC})."
    fi
else
    echo -e "${P_TAG} ${YELLOW}WARNING: settings.xml not found in $SERVER_DIR. Port check skipped.${NC}"
fi

if screen -list | grep -q "\.${SCREEN_NAME}"; then
    screen -S "$SCREEN_NAME" -X quit 2>/dev/null
    sleep 1
fi

cd "$SERVER_DIR" || exit 1
echo -e "${P_TAG} ${WHITE}Starting HappinessMP server...${NC}"
screen -dmS "$SCREEN_NAME" bash -c "exec $SERVER_BINARY"
sleep 2

PIDS=$(ps -eo pid=,args= | awk -v bin="$SERVER_BINARY" '$2 == bin {print $1}')
if [ -n "$PIDS" ] && screen -list | grep -q "\.${SCREEN_NAME}"; then
    echo -e "${P_TAG} ${L_GREEN}Server started successfully.${NC}"
    echo -e "${P_TAG} Screen: ${WHITE}$SCREEN_NAME${NC} | PID: ${WHITE}$PIDS${NC}"
    echo -e "${P_TAG} Use '${L_CYAN}hmp-console${NC}' to attach to server console."
else
    echo -e "${P_TAG} ${L_RED}ERROR: Server failed to start.${NC}"
    screen -S "$SCREEN_NAME" -X quit 2>/dev/null
    exit 1
fi
EOF

# ============================================================
# HMP-CONSOLE
# ============================================================

cat > "$HMP_BIN/hmp-console" <<'EOF'
#!/bin/bash
source /etc/hmp-server.conf 2>/dev/null || { echo "ERROR: Configuration /etc/hmp-server.conf missing."; exit 1; }

NC='\033[0m'
BLUE='\033[1;34m'
L_CYAN='\033[1;36m'
L_RED='\033[1;31m'
WHITE='\033[1;37m'

P_TAG="${BLUE}${PREFIX}${NC}"

if ! command -v screen >/dev/null 2>&1; then
    echo -e "${P_TAG} ${L_RED}ERROR: 'screen' is not installed.${NC}"
    exit 1
fi

if ! screen -list | grep -q "\.${SCREEN_NAME}"; then
    echo -e "${P_TAG} ${L_RED}ERROR: Server screen session is not running.${NC}"
    exit 1
fi

echo -e "${P_TAG} ${L_CYAN}Opening server console...${NC}"
echo -e "${P_TAG} Detach without stopping the server: ${WHITE}Ctrl+A, then D${NC}"
screen -r "$SCREEN_NAME"
EOF

# ============================================================
# HMP-STOP
# ============================================================

cat > "$HMP_BIN/hmp-stop" <<'EOF'
#!/bin/bash
source /etc/hmp-server.conf 2>/dev/null || { echo "ERROR: Configuration /etc/hmp-server.conf missing."; exit 1; }

NC='\033[0m'
BLUE='\033[1;34m'
L_GREEN='\033[1;32m'
L_RED='\033[1;31m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'

P_TAG="${BLUE}${PREFIX}${NC}"
LOG_TEMP=$(mktemp /tmp/hmp-stop.XXXXXX)
TIMEOUT=30

get_pids() {
    ps -eo pid=,args= | awk -v bin="$SERVER_BINARY" '$2 == bin {print $1}'
}

echo -e "${P_TAG} ${WHITE}Stopping HappinessMP server...${NC}"

PIDS=$(get_pids)
if [ -z "$PIDS" ] && ! screen -list | grep -q "\.${SCREEN_NAME}"; then
    echo -e "${P_TAG} ${YELLOW}Server is already stopped.${NC}"
    rm -f "$LOG_TEMP"
    exit 0
fi

if screen -list | grep -q "\.${SCREEN_NAME}"; then
    echo -e "${P_TAG} ${WHITE}Sending 'stop' command to server...${NC}"
    screen -S "$SCREEN_NAME" -X stuff $'stop\r'

    START_TIME=$(date +%s)
    CONFIRMED=0

    while true; do
        screen -S "$SCREEN_NAME" -X hardcopy -h "$LOG_TEMP" 2>/dev/null

        if grep -q "\[Server\] Stopped server\." "$LOG_TEMP" 2>/dev/null; then
            CONFIRMED=1
            break
        fi

        PIDS=$(get_pids)
        if [ -z "$PIDS" ]; then
            CONFIRMED=1
            break
        fi

        NOW=$(date +%s)
        if [ $((NOW - START_TIME)) -ge "$TIMEOUT" ]; then
            break
        fi
        sleep 1
    done

    if [ "$CONFIRMED" -eq 1 ]; then
        echo -e "${P_TAG} ${L_GREEN}Server stopped gracefully.${NC}"
    else
        echo -e "${P_TAG} ${YELLOW}WARNING: Shutdown confirmation was not received within $TIMEOUT seconds.${NC}"
        echo -e "${P_TAG} Force stopping server..."
    fi
fi

PIDS=$(get_pids)
if [ -n "$PIDS" ]; then
    for PID in $PIDS; do
        kill -9 "$PID" 2>/dev/null
    done
    sleep 1
fi

if screen -list | grep -q "\.${SCREEN_NAME}"; then
    screen -S "$SCREEN_NAME" -X quit 2>/dev/null
fi

rm -f "$LOG_TEMP"

PIDS=$(get_pids)
if [ -z "$PIDS" ] && ! screen -list | grep -q "\.${SCREEN_NAME}"; then
    echo -e "${P_TAG} ${L_GREEN}Server shutdown completed successfully.${NC}"
else
    echo -e "${P_TAG} ${L_RED}ERROR: Server could not be completely stopped.${NC}"
    exit 1
fi
EOF

# ============================================================
# HMP-FORCE
# ============================================================

cat > "$HMP_BIN/hmp-force" <<'EOF'
#!/bin/bash
source /etc/hmp-server.conf 2>/dev/null || { echo "ERROR: Configuration /etc/hmp-server.conf missing."; exit 1; }

NC='\033[0m'
BLUE='\033[1;34m'
L_GREEN='\033[1;32m'
L_RED='\033[1;31m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'

P_TAG="${BLUE}${PREFIX}${NC}"

get_pids() {
    ps -eo pid=,args= | awk -v bin="$SERVER_BINARY" '$2 == bin {print $1}'
}

echo -e "${P_TAG} ${WHITE}Force stopping HappinessMP server...${NC}"

PIDS=$(get_pids)
if [ -n "$PIDS" ]; then
    for PID in $PIDS; do
        echo -e "${P_TAG} Terminating PID ${WHITE}$PID${NC}..."
        kill -9 "$PID" 2>/dev/null
    done
    sleep 1
else
    echo -e "${P_TAG} ${YELLOW}No running HappinessMP process found.${NC}"
fi

if screen -list | grep -q "\.${SCREEN_NAME}"; then
    screen -S "$SCREEN_NAME" -X quit 2>/dev/null
fi

PIDS=$(get_pids)
if [ -z "$PIDS" ] && ! screen -list | grep -q "\.${SCREEN_NAME}"; then
    echo -e "${P_TAG} ${L_GREEN}Server force stopped successfully.${NC}"
else
    echo -e "${P_TAG} ${L_RED}ERROR: Failed to force stop server.${NC}"
    exit 1
fi
EOF

# ============================================================
# HMP-RESTART
# ============================================================

cat > "$HMP_BIN/hmp-restart" <<'EOF'
#!/bin/bash
source /etc/hmp-server.conf 2>/dev/null || { echo "ERROR: Configuration /etc/hmp-server.conf missing."; exit 1; }

NC='\033[0m'
BLUE='\033[1;34m'
L_GREEN='\033[1;32m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'

P_TAG="${BLUE}${PREFIX}${NC}"
LOG_TEMP=$(mktemp /tmp/hmp-restart.XXXXXX)
TIMEOUT=30

get_pids() {
    ps -eo pid=,args= | awk -v bin="$SERVER_BINARY" '$2 == bin {print $1}'
}

PIDS=$(get_pids)
if [ -z "$PIDS" ]; then
    echo -e "${P_TAG} ${YELLOW}Server is not running. Starting server...${NC}"
    rm -f "$LOG_TEMP"
    exec "$HMP_BIN/hmp-start"
fi

if ! screen -list | grep -q "\.${SCREEN_NAME}"; then
    echo -e "${P_TAG} ${YELLOW}WARNING: Process exists but screen session is missing. Force stopping orphaned process...${NC}"
    rm -f "$LOG_TEMP"
    "$HMP_BIN/hmp-force"
    exec "$HMP_BIN/hmp-start"
fi

echo -e "${P_TAG} ${WHITE}Sending 'restart' command to server...${NC}"
screen -S "$SCREEN_NAME" -X stuff $'restart\r'

START_TIME=$(date +%s)
while true; do
    screen -S "$SCREEN_NAME" -X hardcopy -h "$LOG_TEMP" 2>/dev/null
    if grep -q "\[Server\] Restarted server\." "$LOG_TEMP" 2>/dev/null; then
        echo -e "${P_TAG} ${L_GREEN}Server restarted successfully.${NC}"
        rm -f "$LOG_TEMP"
        exit 0
    fi

    NOW=$(date +%s)
    if [ $((NOW - START_TIME)) -ge "$TIMEOUT" ]; then
        break
    fi
    sleep 1
done

echo -e "${P_TAG} ${YELLOW}WARNING: Restart confirmation was not received. Initiating force restart...${NC}"
rm -f "$LOG_TEMP"
"$HMP_BIN/hmp-force"
sleep 1
exec "$HMP_BIN/hmp-start"
EOF

# ============================================================
# HMP-STATUS
# ============================================================

cat > "$HMP_BIN/hmp-status" <<'EOF'
#!/bin/bash
source /etc/hmp-server.conf 2>/dev/null || { echo "ERROR: Configuration /etc/hmp-server.conf missing."; exit 1; }

clear -x 2>/dev/null || true

NC='\033[0m'
BOLD='\033[1m'
GRAY='\033[0;90m'
BLUE='\033[1;34m'
CYAN='\033[0;36m'
L_CYAN='\033[1;36m'
L_GREEN='\033[1;32m'
L_RED='\033[1;31m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'

P_TAG="${BLUE}${PREFIX}${NC}"

get_pids() {
    ps -eo pid=,args= | awk -v bin="$SERVER_BINARY" '$2 == bin {print $1}'
}

format_uptime() {
    local seconds="$1"
    if [ -z "$seconds" ] || [ "$seconds" -lt 0 ] 2>/dev/null; then
        echo "N/A"
        return
    fi
    local days=$((seconds / 86400))
    local hours=$(((seconds % 86400) / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))

    if [ "$days" -gt 0 ]; then
        printf "%dd %02dh %02dm %02ds" "$days" "$hours" "$minutes" "$secs"
    else
        printf "%02dh %02dm %02ds" "$hours" "$minutes" "$secs"
    fi
}

get_vps_cpu() {
    read -r cpu user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat
    local prev_idle=$((idle + iowait))
    local prev_total=$((user + nice + system + idle + iowait + irq + softirq + steal))
    sleep 0.2
    read -r cpu user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat
    local idle_val=$((idle + iowait))
    local total_val=$((user + nice + system + idle + iowait + irq + softirq + steal))
    local diff_idle=$((idle_val - prev_idle))
    local diff_total=$((total_val - prev_total))
    if [ "$diff_total" -gt 0 ]; then
        awk -v i="$diff_idle" -v t="$diff_total" 'BEGIN {printf "%.1f", (1 - i/t)*100}'
    else
        echo "0.0"
    fi
}

TIMESTAMP=$(date "+%d.%m.%Y - %H:%M:%S")
HEADER_TEXT="SERVER STATUS | $TIMESTAMP"

echo ""
echo -e "${CYAN}============================================================${NC}"
printf "${BOLD}${WHITE}%*s${NC}\n" $(( (${#HEADER_TEXT} + 60) / 2 )) "$HEADER_TEXT"
echo -e "${CYAN}============================================================${NC}"
echo ""

SCREEN_STATE="${L_RED}OFFLINE${NC}"
screen -list | grep -q "\.${SCREEN_NAME}" && SCREEN_STATE="${L_GREEN}ONLINE${NC}"

PIDS=$(get_pids)
PROCESS_STATE="${L_RED}OFFLINE${NC}"
[ -n "$PIDS" ] && PROCESS_STATE="${L_GREEN}RUNNING${NC}"

echo -e "Screen:   $SCREEN_STATE"
echo -e "Process:  $PROCESS_STATE"
echo ""

TOTAL_RAM_KB=$(awk '/MemTotal:/ {print $2}' /proc/meminfo)
AVAILABLE_RAM_KB=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)
USED_RAM_KB=$((TOTAL_RAM_KB - AVAILABLE_RAM_KB))

TOTAL_RAM_GB=$(awk -v kb="$TOTAL_RAM_KB" 'BEGIN {printf "%.2f", kb/1024/1024}')
USED_RAM_GB=$(awk -v kb="$USED_RAM_KB" 'BEGIN {printf "%.2f", kb/1024/1024}')
FREE_RAM_GB=$(awk -v kb="$AVAILABLE_RAM_KB" 'BEGIN {printf "%.2f", kb/1024/1024}')
TOTAL_RAM_PERCENT=$(awk -v u="$USED_RAM_KB" -v t="$TOTAL_RAM_KB" 'BEGIN {if(t>0) printf "%.1f", (u/t)*100; else print "0.0"}')

CPU_CORES=$(nproc 2>/dev/null || grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo "1")
VPS_CPU=$(get_vps_cpu)
BOOT_SECONDS=$(awk '{print int($1)}' /proc/uptime)

if [ -n "$PIDS" ]; then
    PID=$(echo "$PIDS" | awk '{print $1}')
    ETIME=$(ps -p "$PID" -o etimes= 2>/dev/null | tr -d ' ')
    PROCESS_CPU=$(ps -p "$PID" -o %cpu= 2>/dev/null | tr -d ' ')
    PROCESS_RSS_KB=$(ps -p "$PID" -o rss= 2>/dev/null | tr -d ' ')

    [ -z "$ETIME" ] && ETIME=0
    [ -z "$PROCESS_CPU" ] && PROCESS_CPU="0.0"
    [ -z "$PROCESS_RSS_KB" ] && PROCESS_RSS_KB=0

    PROCESS_RAM_MB=$(awk -v kb="$PROCESS_RSS_KB" 'BEGIN {printf "%.1f", kb/1024}')
    PROCESS_RAM_TOTAL_PCT=$(awk -v p="$PROCESS_RSS_KB" -v t="$TOTAL_RAM_KB" 'BEGIN {if(t>0) printf "%.1f", (p/t)*100; else print "0.0"}')
    PROCESS_RAM_USED_PCT=$(awk -v p="$PROCESS_RSS_KB" -v u="$USED_RAM_KB" 'BEGIN {if(u>0) printf "%.1f", (p/u)*100; else print "0.0"}')

    PROCESS_CPU_TOTAL_PCT=$(awk -v pc="$PROCESS_CPU" -v cores="$CPU_CORES" 'BEGIN {if(cores>0) printf "%.1f", pc/cores; else print "0.0"}')

    echo -e "${BOLD}${L_CYAN}HAPPINESSMP PROCESS${NC}"
    echo -e "${GRAY}-------------------${NC}"
    echo -e "PID:        ${WHITE}$PID${NC}"
    echo -e "Uptime:     ${WHITE}$(format_uptime "$ETIME")${NC}"
    echo -e "CPU Usage:  ${WHITE}${PROCESS_CPU_TOTAL_PCT}%${NC} of total CPU (${WHITE}${PROCESS_CPU}%${NC} of 1 core | ${WHITE}${CPU_CORES}${NC} vCPU cores)"
    echo -e "RAM Usage:  ${WHITE}${PROCESS_RAM_MB} MB${NC} (${WHITE}${PROCESS_RAM_TOTAL_PCT}%${NC} of total RAM | ${WHITE}${PROCESS_RAM_USED_PCT}%${NC} of used RAM)"
    echo ""
fi

echo -e "${BOLD}${L_CYAN}VPS MACHINE${NC}"
echo -e "${GRAY}-----------${NC}"
echo -e "Uptime:     ${WHITE}$(format_uptime "$BOOT_SECONDS")${NC}"
echo -e "CPU Usage:  ${WHITE}${VPS_CPU}%${NC} (${WHITE}${CPU_CORES}${NC} vCPU cores)"
echo -e "RAM Usage:  ${WHITE}${USED_RAM_GB} GB${NC} / ${WHITE}${TOTAL_RAM_GB} GB${NC} (${WHITE}${TOTAL_RAM_PERCENT}%${NC})"
echo -e "Free RAM:   ${WHITE}${FREE_RAM_GB} GB${NC}"
echo ""

if [ -f "$CRON_FILE" ]; then
    AUTO_LINE=$(grep -v '^#' "$CRON_FILE" | grep -v '^$' | head -n 1)
    if [ -n "$AUTO_LINE" ]; then
        M=$(echo "$AUTO_LINE" | awk '{print $1}')
        H=$(echo "$AUTO_LINE" | awk '{print $2}')
        printf "$P_TAG Automatic restart: ${L_GREEN}ENABLED${NC} at ${WHITE}%02d:%02d${NC} every day.\n" "$H" "$M"
    else
        echo -e "$P_TAG Automatic restart: ${YELLOW}DISABLED${NC}"
    fi
else
    echo -e "$P_TAG Automatic restart: ${YELLOW}DISABLED${NC}"
fi

echo ""
echo -e "${CYAN}============================================================${NC}"
echo ""
EOF

# ============================================================
# HMP-AUTORESTART
# ============================================================

cat > "$HMP_BIN/hmp-autorestart" <<'EOF'
#!/bin/bash
source /etc/hmp-server.conf 2>/dev/null || { echo "ERROR: Configuration /etc/hmp-server.conf missing."; exit 1; }

NC='\033[0m'
BLUE='\033[1;34m'
L_GREEN='\033[1;32m'
L_RED='\033[1;31m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'

P_TAG="${BLUE}${PREFIX}${NC}"
RESTART_COMMAND="$HMP_BIN/hmp-restart"

if [ "$#" -eq 0 ]; then
    if [ -f "$CRON_FILE" ]; then
        LINE=$(grep -v '^#' "$CRON_FILE" | grep -v '^$' | head -n 1)
        if [ -n "$LINE" ]; then
            MINUTE=$(echo "$LINE" | awk '{print $1}')
            HOUR=$(echo "$LINE" | awk '{print $2}')
            printf "$P_TAG Automatic restart: ${L_GREEN}ENABLED${NC} at ${WHITE}%02d:%02d${NC} every day.\n" "$HOUR" "$MINUTE"
        else
            echo -e "$P_TAG Automatic restart: ${YELLOW}DISABLED${NC}"
        fi
    else
        echo -e "$P_TAG Automatic restart: ${YELLOW}DISABLED${NC}"
    fi
    exit 0
fi

if [ "$1" = "off" ]; then
    rm -f "$CRON_FILE"
    echo -e "$P_TAG Automatic restart ${YELLOW}disabled${NC}."
    exit 0
fi

if ! echo "$1" | grep -Eq '^([01][0-9]|2[0-3]):[0-5][0-9]$'; then
    echo -e "${P_TAG} ${L_RED}ERROR: Invalid time format. Use HH:MM format.${NC}"
    echo -e "Example: ${WHITE}hmp-autorestart 04:00${NC}"
    exit 1
fi

HOUR="${1%%:*}"
MINUTE="${1##*:}"

cat > "$CRON_FILE" <<CRON
# HappinessMP automatic daily restart
$MINUTE $HOUR * * * root $RESTART_COMMAND >> $LOG_FILE 2>&1
CRON

chmod 644 "$CRON_FILE"
printf "$P_TAG Automatic restart scheduled at ${L_GREEN}%02d:%02d${NC} every day.\n" "$HOUR" "$MINUTE"
EOF

# ============================================================
# HMP-SETDIR
# ============================================================

cat > "$HMP_BIN/hmp-setdir" <<'EOF'
#!/bin/bash
source /etc/hmp-server.conf 2>/dev/null || { echo "ERROR: Configuration /etc/hmp-server.conf missing."; exit 1; }

clear -x 2>/dev/null || true

NC='\033[0m'
BOLD='\033[1m'
BLUE='\033[1;34m'
CYAN='\033[0;36m'
L_CYAN='\033[1;36m'
L_GREEN='\033[1;32m'
L_RED='\033[1;31m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'

P_TAG="${BLUE}${PREFIX}${NC}"

echo ""
echo -e "${CYAN}============================================================${NC}"
echo -e "${BOLD}${WHITE}             CHANGE SERVER DIRECTORY                        ${NC}"
echo -e "${CYAN}============================================================${NC}"
echo ""
echo -e "${P_TAG} Current Server Directory: ${WHITE}$SERVER_DIR${NC}"
echo ""

NEW_DIR=""
while [ -z "$NEW_DIR" ]; do
    read -e -r -p "Enter new server directory path (Use TAB for autocomplete): " INPUT_DIR
    if [ -z "$INPUT_DIR" ]; then
        echo -e "${P_TAG} ${L_RED}Directory path cannot be empty.${NC}"
        continue
    fi
    if [ ! -d "$INPUT_DIR" ]; then
        echo -e "${P_TAG} ${L_RED}Directory '$INPUT_DIR' does not exist.${NC}"
        continue
    fi
    if [ ! -f "$INPUT_DIR/HappinessMP.Server.out" ]; then
        echo -e "${P_TAG} ${YELLOW}WARNING: 'HappinessMP.Server.out' was not found in '$INPUT_DIR'.${NC}"
        read -r -p "Use this directory anyway? [yes/no]: " CONFIRM_DIR
        CONFIRM_DIR_LOWER=$(echo "$CONFIRM_DIR" | tr '[:upper:]' '[:lower:]')
        if [[ "$CONFIRM_DIR_LOWER" =~ ^y(es)?$ ]]; then
            NEW_DIR="$INPUT_DIR"
        fi
    else
        NEW_DIR="$INPUT_DIR"
    fi
done

NEW_BINARY="$NEW_DIR/HappinessMP.Server.out"

sed -i "s|^SERVER_DIR=.*|SERVER_DIR=\"$NEW_DIR\"|" /etc/hmp-server.conf
sed -i "s|^SERVER_BINARY=.*|SERVER_BINARY=\"$NEW_BINARY\"|" /etc/hmp-server.conf

echo -e "${P_TAG} ${L_GREEN}Server directory successfully updated to:${NC} ${WHITE}$NEW_DIR${NC}"
EOF

# ============================================================
# HMP-HELP
# ============================================================

cat > "$HMP_BIN/hmp-help" <<'EOF'
#!/bin/bash
source /etc/hmp-server.conf 2>/dev/null || { echo "ERROR: Configuration /etc/hmp-server.conf missing."; exit 1; }

clear -x 2>/dev/null || true

NC='\033[0m'
BOLD='\033[1m'
GRAY='\033[0;90m'
CYAN='\033[0;36m'
L_CYAN='\033[1;36m'
WHITE='\033[1;37m'

HELP_TITLE="HMP COMMAND LIST"
HELP_CREDITS="Created by: dkc13 | github.com/dkc13"

echo ""
echo -e "${CYAN}============================================================${NC}"
printf "${BOLD}${WHITE}%*s${NC}\n" $(( (${#HELP_TITLE} + 60) / 2 )) "$HELP_TITLE"
printf "${GRAY}%*s${NC}\n" $(( (${#HELP_CREDITS} + 60) / 2 )) "$HELP_CREDITS"
echo -e "${CYAN}============================================================${NC}"
echo ""
echo -e "  ${L_CYAN}hmp-start${NC}         - Starts the HappinessMP server in screen session"
echo -e "  ${L_CYAN}hmp-console${NC}       - Opens server console (Detach: Ctrl+A, then D)"
echo -e "  ${L_CYAN}hmp-stop${NC}          - Gracefully stops the server (sends 'stop')"
echo -e "  ${L_CYAN}hmp-force${NC}         - Force kills server process and screen session"
echo -e "  ${L_CYAN}hmp-restart${NC}       - Restarts server (sends 'restart')"
echo -e "  ${L_CYAN}hmp-status${NC}        - Displays server status, CPU, RAM and uptime"
echo -e "  ${L_CYAN}hmp-autorestart${NC}   - Configures daily auto-restart (e.g. hmp-autorestart 04:00 or off)"
echo -e "  ${L_CYAN}hmp-setdir${NC}        - Changes the configured HappinessMP server directory"
echo -e "  ${L_CYAN}hmp-help${NC}          - Shows this help message"
echo -e "  ${L_CYAN}hmp-remove${NC}        - Stops server and removes all hmp management tools"
echo ""
echo -e "${CYAN}============================================================${NC}"
echo ""
EOF

# ============================================================
# HMP-REMOVE
# ============================================================

cat > "$HMP_BIN/hmp-remove" <<'EOF'
#!/bin/bash
source /etc/hmp-server.conf 2>/dev/null || { echo "ERROR: Configuration /etc/hmp-server.conf missing."; exit 1; }

NC='\033[0m'
BOLD='\033[1m'
BLUE='\033[1;34m'
CYAN='\033[0;36m'
L_GREEN='\033[1;32m'
L_RED='\033[1;31m'
WHITE='\033[1;37m'

P_TAG="${BLUE}${PREFIX}${NC}"

echo ""
echo -e "${CYAN}============================================================${NC}"
echo -e "${BOLD}${WHITE}               REMOVE MANAGEMENT COMMANDS                    ${NC}"
echo -e "${CYAN}============================================================${NC}"
echo ""
echo -e "${P_TAG} ${L_RED}WARNING: This will stop the server and remove all HMP commands.${NC}"
echo -e "${P_TAG} ${L_RED}Server files will NOT be deleted.${NC}"
echo ""

read -r -p "Are you sure you want to proceed? [yes/no]: " CONFIRM
CONFIRM_LOWER=$(echo "$CONFIRM" | tr '[:upper:]' '[:lower:]')

if [[ ! "$CONFIRM_LOWER" =~ ^y(es)?$ ]]; then
    echo -e "${P_TAG} Removal cancelled."
    exit 0
fi

echo -e "${P_TAG} Stopping server before removal..."
if [ -x "$HMP_BIN/hmp-force" ]; then
    "$HMP_BIN/hmp-force"
fi

rm -f "$CRON_FILE" /etc/profile.d/hmp-commands-path.sh
sed -i "\|export PATH=.*$HMP_BIN|d" /etc/bash.bashrc 2>/dev/null
rm -f \
    "$HMP_BIN/hmp-start" \
    "$HMP_BIN/hmp-console" \
    "$HMP_BIN/hmp-stop" \
    "$HMP_BIN/hmp-force" \
    "$HMP_BIN/hmp-restart" \
    "$HMP_BIN/hmp-status" \
    "$HMP_BIN/hmp-autorestart" \
    "$HMP_BIN/hmp-setdir" \
    "$HMP_BIN/hmp-help" \
    "$HMP_BIN/hmp-remove"

rm -f /etc/hmp-server.conf /tmp/hmp-stop.* /tmp/hmp-restart.*

echo ""
echo -e "${P_TAG} ${L_GREEN}All HMP management commands have been removed.${NC}"
EOF

# ============================================================
# MAKE EXECUTABLE
# ============================================================

chmod +x \
    "$HMP_BIN/hmp-start" \
    "$HMP_BIN/hmp-console" \
    "$HMP_BIN/hmp-stop" \
    "$HMP_BIN/hmp-force" \
    "$HMP_BIN/hmp-restart" \
    "$HMP_BIN/hmp-status" \
    "$HMP_BIN/hmp-autorestart" \
    "$HMP_BIN/hmp-setdir" \
    "$HMP_BIN/hmp-help" \
    "$HMP_BIN/hmp-remove"

echo ""
echo -e "${CYAN}============================================================${NC}"
echo -e "${BOLD}${L_GREEN}             INSTALLATION COMPLETED SUCCESSFULLY            ${NC}"
echo -e "${CYAN}============================================================${NC}"
echo ""
echo -e "Server Directory:  ${WHITE}$SERVER_DIR${NC}"
echo -e "Commands Path:     ${WHITE}$HMP_BIN${NC}"
echo -e "Prefix:            ${BLUE}$PREFIX${NC}"
echo ""
echo -e "Available commands: ${L_CYAN}hmp-start, hmp-console, hmp-stop, hmp-force,${NC}"
echo -e "                    ${L_CYAN}hmp-restart, hmp-status, hmp-autorestart,${NC}"
echo -e "                    ${L_CYAN}hmp-setdir, hmp-help, hmp-remove${NC}"
echo ""
echo -e "Type '${L_CYAN}hmp-help${NC}' to view all commands."
echo -e "${CYAN}============================================================${NC}"
echo ""