#!/usr/bin/env bats

# IP-04: Fallback cascade
# Verifieert dat get_public_ip() automatisch naar de volgende service schakelt bij falen

setup() {
    load test_helper
    load_azure_ddns
}

teardown() {
    teardown_curl_mock
}

@test "IP-04: eerste service succesvol, tweede niet nodig" {
    setup_curl_mock "93.184.216.34" "200"
    run get_public_ip
    [ "$status" -eq 0 ]
    [[ "$output" =~ "93.184.216.34" ]]
}

@test "IP-04: eerste service geeft HTTP 500, fallback naar tweede" {
    setup_curl_sequence "error|500" "93.184.216.34|200"
    run get_public_ip
    [ "$status" -eq 0 ]
    [[ "$output" =~ "93.184.216.34" ]]
}

@test "IP-04: eerste service geeft ongeldig IP, fallback naar tweede" {
    setup_curl_sequence "not-an-ip|200" "10.0.0.1|200"
    run get_public_ip
    [ "$status" -eq 0 ]
    [[ "$output" =~ "10.0.0.1" ]]
}

@test "IP-04: alle services falen, exit code 2 (EXIT_IP)" {
    setup_curl_sequence "error|500" "error|503"
    run get_public_ip
    [ "$status" -eq 2 ]
    [[ "$output" =~ "Geen geldige IP-service beschikbaar" ]]
}
