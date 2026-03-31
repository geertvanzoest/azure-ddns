#!/usr/bin/env bats

# OPS-04: --force flag
# Verifieert dat parse_args() de --force flag correct verwerkt

setup() {
    load test_helper
    load_azure_ddns
}

@test "OPS-04: parse_args zet FORCE=1 bij --force" {
    FORCE=0
    parse_args --force
    [ "$FORCE" -eq 1 ]
}

@test "OPS-04: parse_args laat FORCE=0 zonder argumenten" {
    FORCE=0
    parse_args
    [ "$FORCE" -eq 0 ]
}

@test "OPS-04: parse_args exit 1 bij onbekende optie --unknown" {
    run parse_args --unknown
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Onbekende optie" ]]
}

@test "OPS-04: parse_args exit 1 bij korte flag -f" {
    run parse_args -f
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Onbekende optie" ]]
}
