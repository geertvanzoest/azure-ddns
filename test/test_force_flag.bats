#!/usr/bin/env bats

# OPS-04: --force flag
# Verifies that parse_args() correctly handles the --force flag

setup() {
    load test_helper
    load_azure_ddns
}

@test "OPS-04: parse_args sets FORCE=1 with --force" {
    FORCE=0
    parse_args --force
    [ "$FORCE" -eq 1 ]
}

@test "OPS-04: parse_args keeps FORCE=0 without arguments" {
    FORCE=0
    parse_args
    [ "$FORCE" -eq 0 ]
}

@test "OPS-04: parse_args exits 1 on unknown option --unknown" {
    run parse_args --unknown
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Unknown option" ]]
}

@test "OPS-04: parse_args exits 1 on short flag -f" {
    run parse_args -f
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Unknown option" ]]
}
