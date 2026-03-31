# Requirements: ns4j

**Defined:** 2026-03-30
**Core Value:** Het Azure DNS A-record is altijd actueel met het huidige publieke IP-adres van het thuisnetwerk.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### IP-detectie

- [x] **IP-01**: Script haalt het huidige publieke IPv4-adres op via een externe service (icanhazip.com)
- [ ] **IP-02**: Script valideert het opgehaalde IP-adres met een IPv4 regex check
- [x] **IP-03**: Script vergelijkt het huidige IP met het bestaande DNS record en skipt update als ongewijzigd
- [ ] **IP-04**: Script valt terug op een alternatieve IP-service (checkip.amazonaws.com) als de primaire faalt

### Azure Authenticatie

- [x] **AUTH-01**: Script verkrijgt een OAuth2 access token via Service Principal client credentials flow
- [x] **AUTH-02**: Script controleert HTTP response codes van alle Azure API calls

### DNS Management

- [x] **DNS-01**: Script haalt het huidige A-record op uit Azure DNS via REST API (GET)
- [x] **DNS-02**: Script update het A-record in Azure DNS via REST API (PUT) wanneer het IP gewijzigd is
- [ ] **DNS-03**: TTL is configureerbaar via environment variable (AZURE_DNS_TTL) met default 300 seconden

### Configuratie

- [x] **CFG-01**: Alle configuratie via environment variables (AZURE_TENANT_ID, AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, AZURE_SUBSCRIPTION_ID, AZURE_RESOURCE_GROUP, AZURE_DNS_ZONE, AZURE_DNS_RECORD)
- [x] **CFG-02**: Script valideert alle verplichte env vars bij startup en geeft beschrijvende foutmelding per ontbrekende variabele

### Operatie

- [x] **OPS-01**: Script gebruikt correcte exit codes (0=ok, 1=config-fout, 2=IP-fout, 3=auth-fout, 4=DNS-fout)
- [x] **OPS-02**: Script logt naar stdout (info/succes) en stderr (fouten)
- [ ] **OPS-03**: Script gebruikt flock lock file om concurrent cron execution te voorkomen
- [ ] **OPS-04**: Script ondersteunt --force flag om IP-vergelijking te skippen en altijd te updaten
- [ ] **OPS-05**: Script ondersteunt verbose modus (VERBOSE=1 env var) voor extra debug output

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Operatie

- **OPS-06**: Dry-run modus (--dry-run) om te testen zonder daadwerkelijk te updaten
- **OPS-07**: Retry logica bij tijdelijke fouten (max 1-2 retries met backoff)
- **OPS-08**: Token caching (hergebruik OAuth2 token binnen expiry window)
- **OPS-09**: Versie-informatie (--version flag)

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Node.js / Python runtime | bash + curl volstaat, zero dependencies |
| Azure SDK of CLI | Directe REST API calls zijn lichter |
| Meerdere DNS records/zones | Scope creep; meerdere cron-entries met verschillende env vars |
| Push notificaties (email, Slack) | Cron mailt stderr; gebruiker kan wrapper script toevoegen |
| Docker container | Overkill voor een enkel bash script |
| IPv6 / AAAA records | Niet gevraagd; verdubbelt complexiteit |
| Daemon-modus | Cron handelt scheduling af |
| Config file parsing | Env vars zijn simpeler voor cron-model |
| Plugin-systeem | Single provider (Azure DNS), hardcoded |
| Interactieve setup wizard | Goede README met voorbeelden volstaat |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| IP-01 | Phase 1 | Complete |
| IP-02 | Phase 2 | Pending |
| IP-03 | Phase 1 | Complete |
| IP-04 | Phase 2 | Pending |
| AUTH-01 | Phase 1 | Complete |
| AUTH-02 | Phase 1 | Complete |
| DNS-01 | Phase 1 | Complete |
| DNS-02 | Phase 1 | Complete |
| DNS-03 | Phase 2 | Pending |
| CFG-01 | Phase 1 | Complete |
| CFG-02 | Phase 1 | Complete |
| OPS-01 | Phase 1 | Complete |
| OPS-02 | Phase 1 | Complete |
| OPS-03 | Phase 2 | Pending |
| OPS-04 | Phase 2 | Pending |
| OPS-05 | Phase 2 | Pending |

**Coverage:**
- v1 requirements: 16 total
- Mapped to phases: 16
- Unmapped: 0

---
*Requirements defined: 2026-03-30*
*Last updated: 2026-03-30 after roadmap creation*
