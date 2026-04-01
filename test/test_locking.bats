#!/usr/bin/env bats

# OPS-03: flock locking
# Verifies that concurrent execution prevention works correctly
# flock is only available on Linux (util-linux)

setup() {
    if [[ "$(uname)" != "Linux" ]]; then
        skip "flock not available on $(uname) -- Linux only"
    fi
    load test_helper
}

@test "OPS-03: LOCK_FILE is /tmp/azure-ddns.lock" {
    load_azure_ddns
    [ "$LOCK_FILE" = "/tmp/azure-ddns.lock" ]
}

@test "OPS-03: script contains flock --nonblock" {
    grep -q "flock --nonblock" "$AZURE_DDNS_SCRIPT"
}

@test "OPS-03: blocked lock gives WARN and exit 0" {
    # Simulate a blocked lock by holding the lock file
    exec 200>/tmp/azure-ddns.lock
    flock --nonblock 200

    # Start second instance (should fail on flock)
    export AZURE_TENANT_ID="test" AZURE_CLIENT_ID="test" AZURE_CLIENT_SECRET="test"
    export AZURE_SUBSCRIPTION_ID="test" AZURE_RESOURCE_GROUP="test"
    export DNS_ZONE_NAME="test.com" DNS_RECORD_NAME="test"

    run bash "$AZURE_DDNS_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Another instance is running" ]]

    # Release lock
    flock --unlock 200
    exec 200>&-
}
