#!/bin/ash

LOCK_DIR="/tmp/check_proxy.lock"

# Prevent multiple instances
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "Script already running"
    exit 1
fi

cleanup() {
    rmdir "$LOCK_DIR"
}

trap cleanup EXIT INT TERM

#######################################
# Check internet connection and switch to another server if needed
#######################################

PODKOP_BIN="/usr/bin/podkop"

# Configuration
TEST_URL="https://xvideos.com"
CHECK_TIMEOUT=5
MAX_RETRIES=3
DELAY_BETWEEN_CHECKS=3

# Default group
SELECTOR_GROUP="${1:-main-out}"

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >&2
}

check_internet_connection() {
    local retries="${1:-$MAX_RETRIES}"
    local i

    for i in $(seq 1 $retries); do
        if curl -s -m "$CHECK_TIMEOUT" "$TEST_URL" >/dev/null 2>&1; then
            return 0
        fi

        log_msg "Connection check failed (attempt $i/$retries)"
        sleep "$DELAY_BETWEEN_CHECKS"
    done

    return 1
}

get_available_proxies() {
    local group_tag="$1"

    "$PODKOP_BIN" clash_api get_proxies 2>/dev/null \
        | jq -r ".proxies[\"$group_tag\"].all[]?"
}

get_current_proxy() {
    local group_tag="$1"

    "$PODKOP_BIN" clash_api get_proxies 2>/dev/null \
        | jq -r ".proxies[\"$group_tag\"].now // empty"
}

switch_to_next_proxy() {
    local group_tag="$1"
    local current_proxy="$2"

    local proxies
    proxies=$(get_available_proxies "$group_tag")

    [ -z "$proxies" ] && {
        log_msg "No proxies found in group $group_tag"
        return 1
    }

    local next_proxy=""
    local first_proxy=""
    local found=0

    for proxy in $proxies; do

        [ -z "$first_proxy" ] && first_proxy="$proxy"

        if [ "$found" = "1" ]; then
            next_proxy="$proxy"
            break
        fi

        if [ "$proxy" = "$current_proxy" ]; then
            found=1
        fi
    done

    [ -z "$next_proxy" ] && next_proxy="$first_proxy"

    log_msg "Switching from '$current_proxy' to '$next_proxy'"

    "$PODKOP_BIN" clash_api set_group_proxy "$group_tag" "$next_proxy" >/dev/null 2>&1

    if [ $? -eq 0 ]; then
        log_msg "✅ Switched to '$next_proxy'"
        return 0
    else
        log_msg "❌ Failed to switch proxy"
        return 1
    fi
}

main() {

    log_msg "Starting connection check..."
    log_msg "Using selector group: $SELECTOR_GROUP"

    if check_internet_connection; then
        log_msg "✅ Internet connection OK"
        exit 0
    fi

    log_msg "❌ Internet connection failed"

    current_proxy=$(get_current_proxy "$SELECTOR_GROUP")

    log_msg "Current proxy: $current_proxy"

    if switch_to_next_proxy "$SELECTOR_GROUP" "$current_proxy"; then

        log_msg "Waiting for connection..."
        sleep 5

        if check_internet_connection 2; then
            log_msg "✅ Connection restored"
            exit 0
        fi
    fi

    log_msg "❌ Connection still down"
    exit 1
}

main "$@"
