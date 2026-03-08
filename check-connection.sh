#!/bin/ash

#######################################
# Check internet connection and switch to another server if needed
# This script uses the clash_api to manage proxy selection
#######################################

PODKOP_BIN="/usr/bin/podkop"

# Configuration
TEST_URL="https://www.gstatic.com/generate_204"
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
    
    # Get all available proxies
    local available_proxies
    available_proxies=$(get_available_proxies "$group_tag")
    
    if [ -z "$available_proxies" ]; then
        log_msg "No available proxies found"
        return 1
    fi
    
    # Convert to array
    local proxies_array=()
    while IFS= read -r proxy; do
        [ -n "$proxy" ] && proxies_array+=("$proxy")
    done <<< "$available_proxies"
    
    local total_proxies=${#proxies_array[@]}
    
    if [ "$total_proxies" -eq 0 ]; then
        log_msg "No proxies available in group"
        return 1
    fi
    
    # Find current proxy index and select next one
    local next_index=0
    local found_current=0
    
    for i in $(seq 0 $((total_proxies - 1))); do
        if [ "${proxies_array[$i]}" = "$current_proxy" ]; then
            next_index=$(( (i + 1) % total_proxies ))
            found_current=1
            break
        fi
    done
    
    local next_proxy="${proxies_array[$next_index]}"
    
    log_msg "Switching from '$current_proxy' to '$next_proxy'"
    
    # Use clash_api to set the new proxy
    local result
    result=$("$PODKOP_BIN" clash_api set_group_proxy "$group_tag" "$next_proxy" 2>/dev/null)
    
    if echo "$result" | jq -e '.success' > /dev/null 2>&1; then
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
