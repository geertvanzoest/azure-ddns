#!/bin/bash
# Test helper voor azure-ddns bats tests
# Source azure-ddns functies zonder main() uit te voeren (BASH_SOURCE guard)

# Pad naar het azure-ddns script (relatief vanuit test/ directory)
AZURE_DDNS_SCRIPT="${BATS_TEST_DIRNAME}/../azure-ddns"

# Source het script -- BASH_SOURCE guard voorkomt main() executie
load_azure_ddns() {
    # Zet minimale env vars zodat source niet faalt op set -u
    export AZURE_TENANT_ID="${AZURE_TENANT_ID:-test-tenant}"
    export AZURE_CLIENT_ID="${AZURE_CLIENT_ID:-test-client}"
    export AZURE_CLIENT_SECRET="${AZURE_CLIENT_SECRET:-test-secret}"
    export AZURE_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-test-sub}"
    export AZURE_RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-test-rg}"
    export DNS_ZONE_NAME="${DNS_ZONE_NAME:-test.example.com}"
    export DNS_RECORD_NAME="${DNS_RECORD_NAME:-home}"

    source "$AZURE_DDNS_SCRIPT"
}

# Curl mock: vervang curl met een functie die gecontroleerde output geeft.
# Simuleert het --write-out "\n%{http_code}" formaat dat azure-ddns gebruikt:
#   body
#   http_code
# Gebruik: setup_curl_mock "response_body" "http_code"
setup_curl_mock() {
    local body="$1"
    local http_code="${2:-200}"

    # Maak een tijdelijk script dat als curl fungeert
    MOCK_CURL_BIN=$(mktemp "${TMPDIR:-/tmp}/mock_curl.XXXXXX")
    cat > "$MOCK_CURL_BIN" <<MOCK_EOF
#!/bin/bash
echo '${body}'
echo '${http_code}'
MOCK_EOF
    chmod +x "$MOCK_CURL_BIN"

    # Voeg mock directory toe aan PATH zodat het echte curl overschreven wordt
    MOCK_CURL_DIR=$(dirname "$MOCK_CURL_BIN")
    ln -sf "$MOCK_CURL_BIN" "${MOCK_CURL_DIR}/curl"
    export PATH="${MOCK_CURL_DIR}:${PATH}"
}

# Curl mock voor meerdere calls (fallback testing)
# Elke call geeft het volgende antwoord uit de reeks.
# Gebruik: setup_curl_sequence "body1|code1" "body2|code2"
setup_curl_sequence() {
    local call_count_file
    call_count_file=$(mktemp "${TMPDIR:-/tmp}/curl_count.XXXXXX")
    echo "0" > "$call_count_file"
    MOCK_CURL_COUNT_FILE="$call_count_file"

    # Schrijf response data naar tijdelijke bestanden
    local i=0
    MOCK_CURL_RESP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/curl_resp.XXXXXX")
    for resp in "$@"; do
        local body="${resp%%|*}"
        local code="${resp##*|}"
        echo "$body" > "${MOCK_CURL_RESP_DIR}/body_${i}"
        echo "$code" > "${MOCK_CURL_RESP_DIR}/code_${i}"
        i=$((i + 1))
    done
    local total=$i

    # Maak een tijdelijk script dat als curl fungeert
    MOCK_CURL_BIN=$(mktemp "${TMPDIR:-/tmp}/mock_curl.XXXXXX")
    cat > "$MOCK_CURL_BIN" <<MOCK_EOF
#!/bin/bash
IDX=\$(cat "${call_count_file}")
if [ -f "${MOCK_CURL_RESP_DIR}/body_\${IDX}" ]; then
    BODY=\$(cat "${MOCK_CURL_RESP_DIR}/body_\${IDX}")
    CODE=\$(cat "${MOCK_CURL_RESP_DIR}/code_\${IDX}")
    echo \$((\${IDX} + 1)) > "${call_count_file}"
    echo "\${BODY}"
    echo "\${CODE}"
else
    exit 1
fi
MOCK_EOF
    chmod +x "$MOCK_CURL_BIN"

    # Voeg mock directory toe aan PATH
    MOCK_CURL_DIR=$(dirname "$MOCK_CURL_BIN")
    ln -sf "$MOCK_CURL_BIN" "${MOCK_CURL_DIR}/curl"
    export PATH="${MOCK_CURL_DIR}:${PATH}"
}

# Cleanup: verwijder mock bestanden en herstel PATH
teardown_curl_mock() {
    # Verwijder mock curl symlink en script
    if [[ -n "${MOCK_CURL_DIR:-}" ]]; then
        rm -f "${MOCK_CURL_DIR}/curl" 2>/dev/null || true
    fi
    if [[ -n "${MOCK_CURL_BIN:-}" ]]; then
        rm -f "$MOCK_CURL_BIN" 2>/dev/null || true
    fi
    if [[ -n "${MOCK_CURL_COUNT_FILE:-}" ]]; then
        rm -f "$MOCK_CURL_COUNT_FILE" 2>/dev/null || true
    fi
    if [[ -n "${MOCK_CURL_RESP_DIR:-}" ]]; then
        rm -rf "$MOCK_CURL_RESP_DIR" 2>/dev/null || true
    fi
}
