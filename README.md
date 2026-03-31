# azure-ddns -- Azure DNS Dynamic Updater

![CI](https://github.com/geertvanzoest/azure-ddns/actions/workflows/test.yml/badge.svg)

Een lightweight bash script dat als DDNS-client werkt voor Azure DNS. Het detecteert het publieke IP-adres van het netwerk via een externe service en update een A-record in Azure DNS via de REST API. Ontworpen om als cron job op een Raspberry Pi te draaien met zero dependencies buiten standaard systeemtools.

## Features

- Automatische IP-detectie met fallback (icanhazip.com -> checkip.amazonaws.com)
- Slimme update: alleen PUT naar Azure DNS als het IP daadwerkelijk gewijzigd is
- Lock file (`/tmp/azure-ddns.lock`) voorkomt gelijktijdige runs via `flock`
- Force modus (`--force`) voor update ongeacht IP-wijziging
- Debug modus (`VERBOSE=1`) voor uitgebreide logging
- Configureerbare TTL (`DNS_TTL`, default 300 seconden)
- Exit codes voor gestructureerde foutafhandeling (0-4)

## Quick Start

1. Installeer dependencies: `sudo apt-get install jq`
2. Download het script en maak het uitvoerbaar (zie [Installatie](#installatie))
3. Maak een Azure Service Principal aan (zie [Configuratie](#configuratie))
4. Stel de environment variables in (zie [Environment variables](#environment-variables))
5. Test: `./azure-ddns`
6. Stel een cron job in (zie [Cron job instellen](#cron-job-instellen))

## Vereisten

| Dependency | Minimale versie | Controle commando | Standaard op Pi? |
|------------|-----------------|-------------------|------------------|
| bash | >= 4.x | `bash --version` | Ja |
| curl | >= 7.68 | `curl --version` | Ja |
| jq | >= 1.6 | `jq --version` | Nee |

Installeer jq (de enige niet-standaard dependency):

```bash
sudo apt-get install jq
```

## Installatie

```bash
# Download het script
sudo curl -o /usr/local/bin/azure-ddns \
  https://raw.githubusercontent.com/geertvanzoest/azure-ddns/main/azure-ddns

# Maak uitvoerbaar
sudo chmod +x /usr/local/bin/azure-ddns

# Controleer
azure-ddns --help || echo "Geinstalleerd in $(which azure-ddns)"
```

## Configuratie

### Azure Service Principal aanmaken

azure-ddns heeft een Azure Service Principal nodig met minimale rechten op de DNS zone. Voer de volgende stappen uit met de Azure CLI (`az`):

```bash
# 1. App registratie aanmaken
az ad app create --display-name "azure-ddns"
# Noteer de appId uit de output -> dit wordt AZURE_CLIENT_ID
```

```bash
# 2. Service Principal aanmaken
az ad sp create --id <APP_ID>
```

```bash
# 3. Client secret genereren
az ad app credential reset --id <APP_ID> --display-name "azure-ddns-secret"
# Noteer password uit de output -> dit wordt AZURE_CLIENT_SECRET
# Noteer tenant uit de output -> dit wordt AZURE_TENANT_ID
```

```bash
# 4. DNS Zone Contributor rol toekennen (scope op zone niveau)
az role assignment create \
  --assignee <APP_ID> \
  --role "DNS Zone Contributor" \
  --scope "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RESOURCE_GROUP>/providers/Microsoft.Network/dnsZones/<ZONE_NAAM>"
```

De scope is bewust beperkt tot de specifieke DNS zone. De Service Principal krijgt hiermee alleen rechten op die ene zone, niet op de hele subscription of resource group.

### Environment variables

| Variabele | Verplicht | Beschrijving | Voorbeeld |
|-----------|-----------|--------------|-----------|
| `AZURE_TENANT_ID` | Ja | Microsoft Entra tenant GUID | `aaaabbbb-0000-cccc-1111-dddd2222eeee` |
| `AZURE_CLIENT_ID` | Ja | Service Principal application ID | `11112222-bbbb-3333-cccc-4444dddd5555` |
| `AZURE_CLIENT_SECRET` | Ja | Service Principal secret | `A1bC2dE3fH4iJ5kL6mN7oP8qR9sT0u` |
| `AZURE_SUBSCRIPTION_ID` | Ja | Azure subscription GUID | `00000000-0000-0000-0000-000000000000` |
| `AZURE_RESOURCE_GROUP` | Ja | Resource group van de DNS zone | `rg-dns` |
| `DNS_ZONE_NAME` | Ja | DNS zone naam (zonder trailing dot) | `example.com` |
| `DNS_RECORD_NAME` | Ja | Relatieve recordnaam | `home` (resulteert in `home.example.com`) |
| `DNS_TTL` | Nee | TTL in seconden (default: 300) | `300` |

**Methode 1: Via `/etc/environment`** (persistent, alle gebruikers)

Voeg de variabelen toe aan `/etc/environment`:

```bash
sudo tee -a /etc/environment << 'EOF'
AZURE_TENANT_ID=<JOUW_TENANT_ID>
AZURE_CLIENT_ID=<JOUW_CLIENT_ID>
AZURE_CLIENT_SECRET=<JOUW_CLIENT_SECRET>
AZURE_SUBSCRIPTION_ID=<JOUW_SUBSCRIPTION_ID>
AZURE_RESOURCE_GROUP=<JOUW_RESOURCE_GROUP>
DNS_ZONE_NAME=<JOUW_ZONE>
DNS_RECORD_NAME=<JOUW_RECORD>
EOF
```

**Methode 2: Via crontab** (alleen voor cron, zie [Cron job instellen](#cron-job-instellen))

De variabelen worden direct in de crontab-regel gezet. Zie het voorbeeld hieronder.

> **Waarschuwing:** Sla secrets NOOIT op in het script zelf. Gebruik altijd environment variables.

## Gebruik

### Handmatig draaien

```bash
# Normaal (update alleen als IP gewijzigd is)
./azure-ddns

# Force update (altijd updaten, ongeacht IP-wijziging)
./azure-ddns --force

# Debug modus (uitgebreide logging)
VERBOSE=1 ./azure-ddns

# Combinatie: force update met debug output
VERBOSE=1 ./azure-ddns --force
```

### Cron job instellen

Open de crontab:

```bash
crontab -e
```

Voeg een regel toe om het script elke 5 minuten te draaien:

```bash
*/5 * * * * AZURE_TENANT_ID=xxx AZURE_CLIENT_ID=xxx AZURE_CLIENT_SECRET=xxx AZURE_SUBSCRIPTION_ID=xxx AZURE_RESOURCE_GROUP=xxx DNS_ZONE_NAME=xxx DNS_RECORD_NAME=xxx /usr/local/bin/azure-ddns >> /var/log/azure-ddns.log 2>&1
```

Als de environment variables al in `/etc/environment` staan, volstaat:

```bash
*/5 * * * * /usr/local/bin/azure-ddns >> /var/log/azure-ddns.log 2>&1
```

De output wordt naar `/var/log/azure-ddns.log` geschreven voor troubleshooting. Maak het logbestand aan als het nog niet bestaat:

```bash
sudo touch /var/log/azure-ddns.log
sudo chown $(whoami) /var/log/azure-ddns.log
```

### Lock file

Het script gebruikt `/tmp/azure-ddns.lock` via `flock` om te voorkomen dat twee instanties tegelijk draaien. Als een vorige run nog bezig is, wordt de nieuwe run overgeslagen met de melding "Andere instantie draait, overgeslagen". Hier is geen actie van de gebruiker voor nodig.

## Troubleshooting

### Exit codes

| Code | Constante | Betekenis | Mogelijke oorzaken | Oplossing |
|------|-----------|-----------|--------------------|-----------| 
| 0 | EXIT_OK | Succes | - | Geen actie nodig |
| 1 | EXIT_CONFIG | Configuratiefout | Ontbrekende env var, jq niet geinstalleerd | Controleer alle verplichte env vars, installeer jq |
| 2 | EXIT_IP | IP-detectie mislukt | Geen internet, IP-services onbereikbaar | Controleer internetverbinding, test `curl https://icanhazip.com` |
| 3 | EXIT_AUTH | Authenticatie mislukt | Onjuiste credentials, verlopen secret, verkeerde tenant | Controleer AZURE_TENANT_ID/CLIENT_ID/CLIENT_SECRET, vernieuw secret |
| 4 | EXIT_DNS | DNS-operatie mislukt | Onvoldoende rechten, verkeerde zone/record naam | Controleer RBAC-rol, resource group, zone naam |

Controleer de exit code na een run:

```bash
./azure-ddns; echo "Exit code: $?"
```

### Debug modus

Gebruik `VERBOSE=1` voor uitgebreide logging:

```bash
VERBOSE=1 ./azure-ddns
```

Dit toont:
- Welke configuratie geladen is
- OAuth2 token status
- Welke IP-service gebruikt wordt en het gedetecteerde IP
- Vergelijking van huidig DNS record met het nieuwe IP
- DNS update payload

### Veelvoorkomende problemen

**"Andere instantie draait, overgeslagen"**

Een vorige run is nog bezig. Wacht tot deze klaar is. Als het script vasthangt, verwijder handmatig de lock file:

```bash
rm /tmp/azure-ddns.lock
```

**HTTP 401 bij token request (exit code 3)**

De client secret is verlopen of onjuist. Genereer een nieuw secret:

```bash
az ad app credential reset --id <APP_ID> --display-name "azure-ddns-secret"
```

Werk vervolgens `AZURE_CLIENT_SECRET` bij in de environment variables.

**HTTP 403 bij DNS update (exit code 4)**

De DNS Zone Contributor rol is niet (correct) toegekend. Controleer de roltoekenning:

```bash
az role assignment list \
  --assignee <APP_ID> \
  --scope "/subscriptions/<SUB_ID>/resourceGroups/<RG>/providers/Microsoft.Network/dnsZones/<ZONE>"
```

Wijs de rol opnieuw toe als deze ontbreekt (zie [Azure Service Principal aanmaken](#azure-service-principal-aanmaken)).

**Geen IP gedetecteerd (exit code 2)**

Controleer of de Pi uitgaand HTTPS-verkeer kan versturen:

```bash
curl -s https://icanhazip.com
curl -s https://checkip.amazonaws.com
```

Als beide falen, controleer de internetverbinding en eventuele firewall-regels.

## IP-services

azure-ddns probeert achtereenvolgens de volgende services om het publieke IP-adres te detecteren:

| Volgorde | Service | URL | Eigenaar |
|----------|---------|-----|----------|
| 1 (primair) | icanhazip.com | `https://icanhazip.com` | Cloudflare |
| 2 (fallback) | checkip.amazonaws.com | `https://checkip.amazonaws.com` | Amazon AWS |

Als de primaire service niet bereikbaar is, wordt automatisch de fallback gebruikt.

## Technische details

- **Azure DNS REST API versie:** 2018-05-01 (huidige stabiele GA release)
- **OAuth2 flow:** Client credentials grant via Microsoft Entra
- **Token endpoint:** `https://login.microsoftonline.com/{tenantId}/oauth2/v2.0/token`
- **IP-validatie:** Strikte IPv4 regex-validatie op responses van IP-services
