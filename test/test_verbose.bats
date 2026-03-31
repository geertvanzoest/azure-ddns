#!/usr/bin/env bats

# OPS-05: Verbose debug modus
# Verifieert dat debug() alleen output produceert bij VERBOSE=1
# debug() schrijft naar stderr (voorkomt corruptie van stdout captures in main())

setup() {
    load test_helper
    load_azure_ddns
}

@test "OPS-05: debug() produceert stderr output bij VERBOSE=1" {
    VERBOSE=1
    run bash -c 'source "'"$AZURE_DDNS_SCRIPT"'" && VERBOSE=1 debug "test bericht" 2>&1'
    [ "$status" -eq 0 ]
    [[ "$output" =~ "DEBUG" ]]
    [[ "$output" =~ "test bericht" ]]
}

@test "OPS-05: debug() produceert geen output bij VERBOSE=0" {
    VERBOSE=0
    run bash -c 'source "'"$AZURE_DDNS_SCRIPT"'" && VERBOSE=0 debug "test bericht" 2>&1'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "OPS-05: debug() produceert geen output zonder VERBOSE" {
    unset VERBOSE
    run bash -c 'source "'"$AZURE_DDNS_SCRIPT"'" && unset VERBOSE && debug "test bericht" 2>&1'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "OPS-05: debug() gebruikt log formaat [timestamp] DEBUG: bericht" {
    VERBOSE=1
    run bash -c 'source "'"$AZURE_DDNS_SCRIPT"'" && VERBOSE=1 debug "test bericht" 2>&1'
    [ "$status" -eq 0 ]
    [[ "$output" =~ "[" ]]
    [[ "$output" =~ "] DEBUG: test bericht" ]]
}
