#!/usr/bin/env bats

# OPS-03: flock locking
# Verifieert dat concurrent execution preventie correct werkt
# flock is alleen beschikbaar op Linux (util-linux)

setup() {
    if [[ "$(uname)" != "Linux" ]]; then
        skip "flock niet beschikbaar op $(uname) -- alleen Linux"
    fi
    load test_helper
}

@test "OPS-03: LOCK_FILE is /tmp/azure-ddns.lock" {
    load_azure_ddns
    [ "$LOCK_FILE" = "/tmp/azure-ddns.lock" ]
}

@test "OPS-03: script bevat flock --nonblock" {
    grep -q "flock --nonblock" "$AZURE_DDNS_SCRIPT"
}

@test "OPS-03: geblokkeerde lock geeft WARN en exit 0" {
    # Simuleer een geblokkeerde lock door het lockfile vast te houden
    exec 200>/tmp/azure-ddns.lock
    flock --nonblock 200

    # Start tweede instantie (moet falen op flock)
    export AZURE_TENANT_ID="test" AZURE_CLIENT_ID="test" AZURE_CLIENT_SECRET="test"
    export AZURE_SUBSCRIPTION_ID="test" AZURE_RESOURCE_GROUP="test"
    export DNS_ZONE_NAME="test.com" DNS_RECORD_NAME="test"

    run bash "$AZURE_DDNS_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Andere instantie draait" ]]

    # Release lock
    flock --unlock 200
    exec 200>&-
}
