#!/bin/bash

# Ensure we're not running as root
if [ "$(id -u)" -eq 0 ]; then
    echo "ERROR: Chrome wrapper is still running as root!"
    exit 1
fi

# Ensure Xvfb is running if DISPLAY is set to :99
if [ "$DISPLAY" = ":99" ]; then
    if ! pgrep -x "Xvfb" > /dev/null; then
        Xvfb :99 -screen 0 1920x1080x24 > /dev/null 2>&1 &
        sleep 2
    fi
fi

# Create temp directories for appuser
TEMP_DIR="/tmp/appuser-tmp/chrome-$$"
mkdir -p "$TEMP_DIR/chrome-data" "$TEMP_DIR/chrome-cache"
chmod 755 "$TEMP_DIR"

# Chrome flags for running in Docker container
CHROME_ARGS=(
  --no-sandbox
  --disable-web-security
  --disable-features=VizDisplayCompositor
  --disable-dev-shm-usage
  --disable-gpu
  --headless=new
  --remote-debugging-port=9222
  --window-size=1920,1080
  --disable-background-timer-throttling
  --disable-renderer-backgrounding
  --disable-backgrounding-occluded-windows
  --user-data-dir="$TEMP_DIR/chrome-data"
  --data-path="$TEMP_DIR/chrome-data"
  --disk-cache-dir="$TEMP_DIR/chrome-cache"
)

# Set environment variables
export TMPDIR="/tmp/appuser-tmp"
export TMP="/tmp/appuser-tmp"
export TEMP="/tmp/appuser-tmp"
export HOME="/home/appuser"

# Run Chrome directly (no sudo needed since we're already appuser)
exec google-chrome "${CHROME_ARGS[@]}" "$@" 2>&1
