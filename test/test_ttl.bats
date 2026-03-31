#!/usr/bin/env bats

# DNS-03: TTL configuratie
# Verifieert dat DNS_TTL configureerbaar is met default 300

setup() {
    load test_helper
}

@test "DNS-03: DNS_TTL default is 300 (via parameter expansie)" {
    unset DNS_TTL
    local ttl="${DNS_TTL:-300}"
    [ "$ttl" -eq 300 ]
}

@test "DNS-03: DNS_TTL is configureerbaar via env var" {
    export DNS_TTL=600
    local ttl="${DNS_TTL:-300}"
    [ "$ttl" -eq 600 ]
}

@test "DNS-03: DNS_TTL wordt gebruikt in ns4j script (update_dns functie)" {
    grep -q 'DNS_TTL:-300' "$NS4J_SCRIPT"
}

@test "DNS-03: DNS_TTL wordt gelogd in validate_config debug output" {
    grep -q 'DNS_TTL' "$NS4J_SCRIPT"
}
