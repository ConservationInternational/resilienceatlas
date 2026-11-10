#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/common.sh"

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
export TEST_DIR
mkdir "$TEST_DIR/bin"
export PATH="$TEST_DIR/bin:$PATH"

cat > "$TEST_DIR/bin/docker" <<'EOF'
#!/bin/bash
set -euo pipefail
[ "$1" = "pull" ]
if ! mkdir "$TEST_DIR/pulling"; then
    echo "Concurrent Docker operations detected" >&2
    exit 1
fi
trap 'rmdir "$TEST_DIR/pulling"' EXIT
echo "$2" >> "$TEST_DIR/pulls"
sleep 0.1
[ "$2" != "${FAIL_IMAGE:-}" ]
EOF
chmod +x "$TEST_DIR/bin/docker"

# Two independent hook processes must serialize all image pulls.
for environment in staging production; do
    (
        acquire_docker_lock
        BACKEND_IMAGE="$environment-backend"
        FRONTEND_IMAGE="$environment-frontend"
        pull_deployment_images
    ) > "$TEST_DIR/$environment.log" 2>&1 &
    if [ "$environment" = staging ]; then
        staging_pid=$!
    else
        production_pid=$!
    fi
done
wait "$staging_pid"
wait "$production_pid"
mapfile -t pulls < "$TEST_DIR/pulls"
[ "${#pulls[@]}" -eq 4 ]
if [ "${pulls[0]}" = staging-backend ]; then
    expected=(staging-backend staging-frontend production-backend production-frontend)
else
    expected=(production-backend production-frontend staging-backend staging-frontend)
fi
[ "${pulls[*]}" = "${expected[*]}" ]
echo "PASS: staging and production image pulls are serialized"

# Cleanup uses the same lock as pulls.
(
    acquire_docker_lock
    mkdir "$TEST_DIR/pulling"
    touch "$TEST_DIR/cleanup-started"
    sleep 0.3
    rmdir "$TEST_DIR/pulling"
) > "$TEST_DIR/cleanup.log" 2>&1 &
cleanup_pid=$!
for ((attempt = 0; attempt < 100; attempt++)); do
    [ ! -f "$TEST_DIR/cleanup-started" ] || break
    sleep 0.01
done
[ -f "$TEST_DIR/cleanup-started" ]
(
    acquire_docker_lock
    BACKEND_IMAGE=backend
    FRONTEND_IMAGE=frontend
    pull_deployment_images
) > "$TEST_DIR/after-cleanup.log" 2>&1 &
pull_pid=$!
wait "$cleanup_pid"
wait "$pull_pid"
echo "PASS: cleanup cannot overlap image pulls"

for failed_image in backend frontend; do
    : > "$TEST_DIR/pulls"
    if (
        acquire_docker_lock
        BACKEND_IMAGE=backend
        FRONTEND_IMAGE=frontend
        export FAIL_IMAGE="$failed_image"
        pull_deployment_images
    ) > "$TEST_DIR/failure.log" 2>&1; then
        echo "FAIL: image pull failure was ignored" >&2
        exit 1
    fi
    grep -q "Failed to pull image from ECR: $failed_image" "$TEST_DIR/failure.log"
    mapfile -t pulls < "$TEST_DIR/pulls"
    if [ "$failed_image" = backend ]; then
        [ "${pulls[*]}" = backend ]
    else
        [ "${pulls[*]}" = "backend frontend" ]
    fi
done
echo "PASS: failed pulls stop immediately and log the failing image"

(
    acquire_docker_lock
) > "$TEST_DIR/reacquire.log" 2>&1
echo "PASS: failed hooks release the Docker lock"

if (
    flock() { return 1; }
    acquire_docker_lock
) > "$TEST_DIR/timeout.log" 2>&1; then
    echo "FAIL: lock acquisition failure was ignored" >&2
    exit 1
fi
grep -q "Could not acquire the shared deployment Docker lock within 300 seconds" "$TEST_DIR/timeout.log"
echo "PASS: lock acquisition failures are explicit"
