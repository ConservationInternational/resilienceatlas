#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/common.sh"

docker() {
    if [[ "$*" == *UpdateStatus* ]]; then
        echo "$UPDATE_STATE"
    else
        echo "$ACTUAL_IMAGE"
    fi
}

sleep() {
    UPDATE_STATE=completed
    SLEEPS=$((SLEEPS + 1))
}

UPDATE_STATE=updating
ACTUAL_IMAGE="backend:new@sha256:123"
SLEEPS=0
wait_for_service_update backend backend:new
[ "$SLEEPS" -eq 1 ]
echo "PASS: waits for the new image update to finish"

for UPDATE_STATE in rollback_started rollback_completed paused; do
    if wait_for_service_update backend backend:new; then
        echo "FAIL: accepted a failed update" >&2
        exit 1
    fi
done

UPDATE_STATE=completed
ACTUAL_IMAGE=backend:old
if wait_for_service_update backend backend:new; then
    echo "FAIL: accepted an old healthy image" >&2
    exit 1
fi
echo "PASS: rejects rollbacks and stale deployment images"
