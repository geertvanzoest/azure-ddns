#!/usr/bin/env bats

# IP-04: Fallback cascade
# Verifies that get_public_ip() automatically falls back to the next service on failure

setup() {
    load test_helper
    load_azure_ddns
}

teardown() {
    teardown_curl_mock
}

@test "IP-04: first service succeeds, second not needed" {
    setup_curl_mock "93.184.216.34" "200"
    run get_public_ip
    [ "$status" -eq 0 ]
    [[ "$output" =~ "93.184.216.34" ]]
}

@test "IP-04: first service returns HTTP 500, fallback to second" {
    setup_curl_sequence "error|500" "93.184.216.34|200"
    run get_public_ip
    [ "$status" -eq 0 ]
    [[ "$output" =~ "93.184.216.34" ]]
}

@test "IP-04: first service returns invalid IP, fallback to second" {
    setup_curl_sequence "not-an-ip|200" "10.0.0.1|200"
    run get_public_ip
    [ "$status" -eq 0 ]
    [[ "$output" =~ "10.0.0.1" ]]
}

@test "IP-04: all services fail, exit code 2 (EXIT_IP)" {
    setup_curl_sequence "error|500" "error|503"
    run get_public_ip
    [ "$status" -eq 2 ]
    [[ "$output" =~ "No valid IP service available" ]]
}
