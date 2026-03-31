#!/usr/bin/env bats

# OPS-05: Verbose debug modus
# Verifieert dat debug() alleen output produceert bij VERBOSE=1

setup() {
    load test_helper
    load_ns4j
}

@test "OPS-05: debug() produceert output bij VERBOSE=1" {
    VERBOSE=1
    run debug "test bericht"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "DEBUG" ]]
    [[ "$output" =~ "test bericht" ]]
}

@test "OPS-05: debug() produceert geen output bij VERBOSE=0" {
    VERBOSE=0
    run debug "test bericht"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "OPS-05: debug() produceert geen output zonder VERBOSE" {
    unset VERBOSE
    run debug "test bericht"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "OPS-05: debug() gebruikt log formaat [timestamp] DEBUG: bericht" {
    VERBOSE=1
    run debug "test bericht"
    [[ "$output" =~ "[" ]]
    [[ "$output" =~ "] DEBUG: test bericht" ]]
}
