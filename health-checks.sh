#!/bin/bash
# Stop immediately on errors, unset variables, or pipe failures
set -euo pipefail

# Load variables
source /etc/monitoring.env

# Array to hold error messages
ALERTS=()

# Function to write to our local log instead of emailing
send_alert() {
    local subject="$1" body="$2"
    printf 'Subject: %s\n\n%s\n---\n' "$subject" "$body" >> "$ALERT_TO"
}

# 1. Disk Check: Extracts the usage percentage of the root directory
DISK=$(df / | awk 'NR==2{gsub(/%/,"",$5);print $5}')
[[ $DISK -gt $DISK_THRESHOLD ]] && ALERTS+=("Disk usage critical: ${DISK}%")

# 2. RAM Check: Calculates free memory as a percentage
RAM=$(free | awk '/^Mem/{printf "%.0f",$4/$2*100}')
[[ $RAM -lt $RAM_MIN_FREE ]] && ALERTS+=("RAM free critical: ${RAM}%")

# 3. Services Check: Loops through "sshd crond" and checks if active
for SVC in $SERVICES; do
    systemctl is-active --quiet "$SVC" || ALERTS+=("Service DOWN: $SVC")
done

# 4. Web Endpoint Check: Attempts to fetch the web page, times out in 5s
curl -sf --max-time 5 "$HEALTH_URL" >/dev/null || ALERTS+=("Web endpoint down or unreachable")

# Final Decision: If array is not empty, log the collected alerts
if [[ ${#ALERTS[@]} -gt 0 ]]; then
    MSG=$(printf '%s\n' "${ALERTS[@]}")
    send_alert "[$(hostname)] HEALTH CHECK FAILED" "$MSG"
fi
