#!/bin/bash
set -euo pipefail

source /etc/backup.env

# Find the most recently modified backup file
LATEST_BACKUP=$(ls -t "$DEST"/backup-*.tar.gz | head -n 1)
TEST_DIR="/tmp/restore_test_$$"

echo "Testing restore of: $LATEST_BACKUP"

# Clean up the test directory when the script finishes
trap 'rm -rf "$TEST_DIR"' EXIT

mkdir -p "$TEST_DIR"

# 1. Extract the archive into the temporary test directory
tar -xzf "$LATEST_BACKUP" -C "$TEST_DIR"

cd "$TEST_DIR"

# 2. Check the manifest
echo "Running manifest verification..."
# This command compares the extracted files to the hashes in manifest.txt
md5sum -c manifest.txt > check_results.txt

# 3. Report the matches
MATCHES=$(grep -c "OK$" check_results.txt)
echo "✅ Restore Test Complete: $MATCHES files matched successfully."
