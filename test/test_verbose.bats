#!/usr/bin/env bats

# OPS-05: Verbose debug mode
# Verifies that debug() only produces output when VERBOSE=1
# debug() writes to stderr (prevents corruption of stdout captures in main())

setup() {
    load test_helper
    load_azure_ddns
}

@test "OPS-05: debug() produces stderr output when VERBOSE=1" {
    VERBOSE=1
    run bash -c 'source "'"$AZURE_DDNS_SCRIPT"'" && VERBOSE=1 debug "test message" 2>&1'
    [ "$status" -eq 0 ]
    [[ "$output" =~ "DEBUG" ]]
    [[ "$output" =~ "test message" ]]
}

@test "OPS-05: debug() produces no output when VERBOSE=0" {
    VERBOSE=0
    run bash -c 'source "'"$AZURE_DDNS_SCRIPT"'" && VERBOSE=0 debug "test message" 2>&1'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "OPS-05: debug() produces no output without VERBOSE" {
    unset VERBOSE
    run bash -c 'source "'"$AZURE_DDNS_SCRIPT"'" && unset VERBOSE && debug "test message" 2>&1'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "OPS-05: debug() uses log format [timestamp] DEBUG: message" {
    VERBOSE=1
    run bash -c 'source "'"$AZURE_DDNS_SCRIPT"'" && VERBOSE=1 debug "test message" 2>&1'
    [ "$status" -eq 0 ]
    [[ "$output" =~ "[" ]]
    [[ "$output" =~ "] DEBUG: test message" ]]
}
