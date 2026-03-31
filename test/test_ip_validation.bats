#!/usr/bin/env bats

# IP-02: IPv4 regex validatie
# Verifieert dat get_public_ip() alleen geldige IPv4 adressen accepteert

setup() {
    load test_helper
    load_ddns4j
}

teardown() {
    teardown_curl_mock
}

@test "IP-02: geldig IPv4 adres wordt geaccepteerd (1.2.3.4)" {
    setup_curl_mock "1.2.3.4" "200"
    run get_public_ip
    [ "$status" -eq 0 ]
    [[ "$output" =~ "1.2.3.4" ]]
}

@test "IP-02: geldig IPv4 adres met hoge octets (255.255.255.255)" {
    setup_curl_mock "255.255.255.255" "200"
    run get_public_ip
    [ "$status" -eq 0 ]
    [[ "$output" =~ "255.255.255.255" ]]
}

@test "IP-02: geldig IPv4 adres met lage octets (0.0.0.0)" {
    setup_curl_mock "0.0.0.0" "200"
    run get_public_ip
    [ "$status" -eq 0 ]
    [[ "$output" =~ "0.0.0.0" ]]
}

@test "IP-02: ongeldig IP (256.1.1.1) wordt afgewezen" {
    setup_curl_mock "256.1.1.1" "200"
    run get_public_ip
    [ "$status" -ne 0 ]
}

@test "IP-02: HTML response wordt afgewezen" {
    setup_curl_mock "<html>error</html>" "200"
    run get_public_ip
    [ "$status" -ne 0 ]
}

@test "IP-02: lege response wordt afgewezen" {
    setup_curl_mock "" "200"
    run get_public_ip
    [ "$status" -ne 0 ]
}

@test "IP-02: IPv6 adres wordt afgewezen" {
    setup_curl_mock "2001:db8::1" "200"
    run get_public_ip
    [ "$status" -ne 0 ]
}

@test "IP-02: tekst met spaties wordt afgewezen" {
    setup_curl_mock "not an ip" "200"
    run get_public_ip
    [ "$status" -ne 0 ]
}
