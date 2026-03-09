#!/bin/ash

#######################################
# Check internet connection and switch to another server if needed
# This script uses the clash_api to manage proxy selection
#######################################

PODKOP_BIN="/usr/bin/podkop"

# Configuration
TEST_URL="https://xvideos.com"
CHECK_TIMEOUT=5
MAX_RETRIES=3
DELAY_BETWEEN_CHECKS=3

# Get the selector group tag (default to "selector" if not specified)
SELECTOR_GROUP="${1:-selector}"

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

check_internet_connection() {
    local retries="${1:-$MAX_RETRIES}"
    local i

    for i in $(seq 1 $retries); do
        if curl -s -m "$CHECK_TIMEOUT" "$TEST_URL" > /dev/null 2>&1; then
            return 0
        fi
        log_msg "Connection check failed (attempt $i/$retries)"
        sleep "$DELAY_BETWEEN_CHECKS"
    done

    return 1
}

get_available_proxies() {
    local group_tag="$1"
    
    # Get proxies list from clash_api
    local proxies_json
    proxies_json=$("$PODKOP_BIN" clash_api get_proxies 2>/dev/null)
    
    if [ -z "$proxies_json" ]; then
        log_msg "Failed to get proxies list"
        return 1
    fi
    
    # Extract all proxy tags from the specified group
    local group_data
    group_data=$(echo "$proxies_json" | jq -r ".proxies[\"$group_tag\"] // empty")
    
    if [ -z "$group_data" ]; then
        log_msg "Group '$group_tag' not found"
        return 1
    fi
    
    # Get all available proxies in the group (excluding the group itself)
    echo "$group_data" | jq -r '.all[]? | select(. != null)' 2>/dev/null
}

get_current_proxy() {
    local group_tag="$1"
    
    local proxies_json
    proxies_json=$("$PODKOP_BIN" clash_api get_proxies 2>/dev/null)
    
    if [ -z "$proxies_json" ]; then
        return 1
    fi
    
    # Get the currently selected proxy for the group
    echo "$proxies_json" | jq -r ".proxies[\"$group_tag\"].now // empty" 2>/dev/null
}

switch_to_next_proxy() {
    local group_tag="$1"
    local current_proxy="$2"

    local proxies
    proxies=$(get_available_proxies "$group_tag")

    if [ -z "$proxies" ]; then
        log_msg "No available proxies found"
        return 1
    fi

    local next_proxy=""
    local found=0
    local first_proxy=""

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

    # если текущий был последний → берем первый
    if [ -z "$next_proxy" ]; then
        next_proxy="$first_proxy"
    fi

    log_msg "Switching from '$current_proxy' to '$next_proxy'"

    result=$("$PODKOP_BIN" clash_api set_group_proxy "$group_tag" "$next_proxy" 2>/dev/null)

    if echo "$result" | jq -e '.success' >/dev/null 2>&1; then
        log_msg "✅ Successfully switched to '$next_proxy'"
        return 0
    else
        log_msg "❌ Failed to switch proxy: $result"
        return 1
    fi
}

main() {
    log_msg "Starting connection check..."
    log_msg "Using selector group: $SELECTOR_GROUP"
    
    # Check internet connection
    if check_internet_connection; then
        log_msg "✅ Internet connection is working"
        exit 0
    fi
    
    log_msg "❌ No internet connection detected"
    
    # Get current proxy
    local current_proxy
    current_proxy=$(get_current_proxy "$SELECTOR_GROUP")
    
    if [ -n "$current_proxy" ]; then
        log_msg "Current proxy: $current_proxy"
    else
        log_msg "Unable to determine current proxy"
    fi
    
    # Try to switch to another proxy
    if switch_to_next_proxy "$SELECTOR_GROUP" "$current_proxy"; then
        log_msg "Proxy switched. Waiting for connection to stabilize..."
        sleep 5
        
        # Verify connection after switch
        if check_internet_connection 2; then
            log_msg "✅ Connection restored after proxy switch"
            exit 0
        else
            log_msg "⚠️ Connection still not working after proxy switch"
            exit 1
        fi
    else
        log_msg "❌ Failed to switch proxy"
        exit 1
    fi
}

main "$@"
