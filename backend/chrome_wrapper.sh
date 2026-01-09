#!/bin/bash
set -e

# Ensure we're not running as root
if [ "$(id -u)" -eq 0 ]; then
    echo "ERROR: Chrome wrapper should not run as root! User ID: $(id -u)"
    exit 1
fi

# Detect which browser is available (Chrome or Chromium for ARM64)
CHROME_CMD=""
if command -v google-chrome &> /dev/null; then
    CHROME_CMD="google-chrome"
    echo "Using Google Chrome"
elif command -v chromium &> /dev/null; then
    CHROME_CMD="chromium"
    echo "Using Chromium (ARM64 compatible)"
elif command -v chromium-browser &> /dev/null; then
    CHROME_CMD="chromium-browser"
    echo "Using Chromium Browser (ARM64 compatible)"
else
    echo "ERROR: No Chrome or Chromium browser found in PATH"
    exit 1
fi

# Ensure Xvfb is running if DISPLAY is set to :99
if [ "$DISPLAY" = ":99" ]; then
    echo "Checking Xvfb for display :99..."
    if ! pgrep -f "Xvfb.*:99" > /dev/null; then
        echo "Starting Xvfb for display :99..."
        Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset > /dev/null 2>&1 &
        XVFB_PID=$!
        sleep 3
        
        # Verify Xvfb started
        if ! pgrep -f "Xvfb.*:99" > /dev/null; then
            echo "ERROR: Failed to start Xvfb"
            exit 1
        fi
        echo "✅ Xvfb started successfully (PID: $XVFB_PID)"
    else
        echo "✅ Xvfb already running for display :99"
    fi
fi

# Create secure temp directories for appuser

TEMP_DIR="/tmp/appuser-tmp/chrome-$$"
mkdir -p "$TEMP_DIR/chrome-data" "$TEMP_DIR/chrome-cache" "$TEMP_DIR/downloads"
chmod 700 "$TEMP_DIR"  # More secure permissions

# Enhanced Chrome flags for running in Docker container
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
  --disable-extensions
  --disable-plugins
  --disable-images
  --disable-default-apps
  --disable-sync
  --disable-translate
  --disable-background-networking
  --safebrowsing-disable-auto-update
  --disable-client-side-phishing-detection
  --disable-component-update
  --disable-default-apps
  --disable-domain-reliability
  --user-data-dir="$TEMP_DIR/chrome-data"
  --data-path="$TEMP_DIR/chrome-data"
  --disk-cache-dir="$TEMP_DIR/chrome-cache"
  --download-directory="$TEMP_DIR/downloads"
)

# Set environment variables for Chrome
export TMPDIR="/tmp/appuser-tmp"
export TMP="/tmp/appuser-tmp"
export TEMP="/tmp/appuser-tmp"
export HOME="/home/appuser"
export CHROME_LOG_FILE="/tmp/chrome-logs/chrome-$$.log"

# Create log directory
mkdir -p /tmp/chrome-logs
chmod 755 /tmp/chrome-logs

# Log the Chrome command for debugging
echo "Chrome command: $CHROME_CMD ${CHROME_ARGS[*]} $*" > "$CHROME_LOG_FILE"
echo "Environment: DISPLAY=$DISPLAY, USER=$(whoami), UID=$(id -u)" >> "$CHROME_LOG_FILE"

# Test Chrome version before running
echo "Testing browser version..."
if timeout 10 $CHROME_CMD --version >> "$CHROME_LOG_FILE" 2>&1; then
    echo "✅ Browser version test successful"
else
    echo "❌ Browser version test failed"
    cat "$CHROME_LOG_FILE"
    exit 1
fi

# Run Chrome with error handling
echo "Starting browser with arguments: ${CHROME_ARGS[*]} $*"
exec $CHROME_CMD "${CHROME_ARGS[@]}" "$@" 2>&1 | tee -a "$CHROME_LOG_FILE"
