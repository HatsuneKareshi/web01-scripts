#!/bin/bash
# Stop immediately on errors, unset variables, or pipe failures
set -euo pipefail

# Load variables
source /etc/backup.env

# Guard variables to ensure the script doesn't run if they are missing
: "${DATA_DIR:?data dir required}"
: "${ALERT_TO:?alert log required}"
: "${DEST:?destination required}"
: "${RETAIN_DAYS:?retain days required}"

DATE=$(date +%F_%H%M)
TMP_DIR="/tmp/backup_$$"
ARCHIVE_NAME="backup-${DATE}.tar.gz"

# Function to write to our local log
send_alert() {
    local subject="$1" body="$2"
    printf 'Subject: %s\n\n%s\n---\n' "$subject" "$body" >> "$ALERT_TO"
}

# The cleanup trap that runs on EVERY exit
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        send_alert "[$(hostname)] BACKUP FAILED" "Backup failed at $DATE with exit code $exit_code."
    fi
    # Always delete the temporary directory
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# Create a fresh temporary directory
mkdir -p "$TMP_DIR"

# 1. Create the MD5 manifest of the data directory
# We cd into it so the file paths in the manifest are relative (easier to test later)
cd "$DATA_DIR"
find . -type f -not -name '*.log' -not -name '*.tmp' -exec md5sum {} + > "$TMP_DIR/manifest.txt"

# 2. Archive the data folder AND the manifest together
tar -czf "$TMP_DIR/$ARCHIVE_NAME" --exclude='*.log' --exclude='*.tmp' . -C "$TMP_DIR" manifest.txt

# 3. Ship the archive to the target destination
rsync -az "$TMP_DIR/$ARCHIVE_NAME" "$DEST/"

# 4. Rotate old backups (delete files older than RETAIN_DAYS)
find "$DEST" -type f -name 'backup-*.tar.gz' -mtime +"$RETAIN_DAYS" -delete

# 5. Send success alert
SIZE=$(du -h "$DEST/$ARCHIVE_NAME" | awk '{print $1}')
send_alert "[$(hostname)] ✅ Backup OK" "Archive: $ARCHIVE_NAME\nSize: $SIZE\nDestination: $DEST"
