#!/usr/bin/env bats

# IP-02: IPv4 regex validation
# Verifies that get_public_ip() only accepts valid IPv4 addresses

setup() {
    load test_helper
    load_azure_ddns
}

teardown() {
    teardown_curl_mock
}

@test "IP-02: valid IPv4 address is accepted (1.2.3.4)" {
    setup_curl_mock "1.2.3.4" "200"
    run get_public_ip
    [ "$status" -eq 0 ]
    [[ "$output" =~ "1.2.3.4" ]]
}

@test "IP-02: valid IPv4 address with high octets (255.255.255.255)" {
    setup_curl_mock "255.255.255.255" "200"
    run get_public_ip
    [ "$status" -eq 0 ]
    [[ "$output" =~ "255.255.255.255" ]]
}

@test "IP-02: valid IPv4 address with low octets (0.0.0.0)" {
    setup_curl_mock "0.0.0.0" "200"
    run get_public_ip
    [ "$status" -eq 0 ]
    [[ "$output" =~ "0.0.0.0" ]]
}

@test "IP-02: invalid IP (256.1.1.1) is rejected" {
    setup_curl_mock "256.1.1.1" "200"
    run get_public_ip
    [ "$status" -ne 0 ]
}

@test "IP-02: HTML response is rejected" {
    setup_curl_mock "<html>error</html>" "200"
    run get_public_ip
    [ "$status" -ne 0 ]
}

@test "IP-02: empty response is rejected" {
    setup_curl_mock "" "200"
    run get_public_ip
    [ "$status" -ne 0 ]
}

@test "IP-02: IPv6 address is rejected" {
    setup_curl_mock "2001:db8::1" "200"
    run get_public_ip
    [ "$status" -ne 0 ]
}

@test "IP-02: text with spaces is rejected" {
    setup_curl_mock "not an ip" "200"
    run get_public_ip
    [ "$status" -ne 0 ]
}
