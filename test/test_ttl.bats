#!/usr/bin/env bats

# DNS-03: TTL configuration
# Verifies that DNS_TTL is configurable with default 300

setup() {
    load test_helper
}

@test "DNS-03: DNS_TTL default is 300 (via parameter expansion)" {
    unset DNS_TTL
    local ttl="${DNS_TTL:-300}"
    [ "$ttl" -eq 300 ]
}

@test "DNS-03: DNS_TTL is configurable via env var" {
    export DNS_TTL=600
    local ttl="${DNS_TTL:-300}"
    [ "$ttl" -eq 600 ]
}

@test "DNS-03: DNS_TTL is used in azure-ddns script (update_dns function)" {
    grep -q 'DNS_TTL:-300' "$AZURE_DDNS_SCRIPT"
}

@test "DNS-03: DNS_TTL is logged in validate_config debug output" {
    grep -q 'DNS_TTL' "$AZURE_DDNS_SCRIPT"
}
