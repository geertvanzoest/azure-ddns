# azure-ddns -- Azure DNS Dynamic Updater

[![CI](https://github.com/geertvanzoest/azure-ddns/actions/workflows/test.yml/badge.svg)](https://github.com/geertvanzoest/azure-ddns/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/github/license/geertvanzoest/azure-ddns)](LICENSE)
[![Bash](https://img.shields.io/badge/bash-%3E%3D4.x-green?logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/platform-Raspberry%20Pi%20%7C%20Linux-blue?logo=linux&logoColor=white)](https://www.raspberrypi.com/)
[![Azure DNS](https://img.shields.io/badge/Azure%20DNS-REST%20API%202018--05--01-0078D4?logo=microsoftazure&logoColor=white)](https://learn.microsoft.com/en-us/rest/api/dns/)

A lightweight bash script that acts as a DDNS client for Azure DNS. It detects the public IP address of the network via an external service and updates an A record in Azure DNS via the REST API. Designed to run as a cron job on a Raspberry Pi with minimal dependencies (bash, curl, jq).

## Features

- Automatic IP detection with fallback (icanhazip.com -> checkip.amazonaws.com)
- Smart update: only PUT to Azure DNS when the IP has actually changed
- Lock file (`/tmp/azure-ddns.lock`) prevents concurrent runs via `flock`
- Force mode (`--force`) to update regardless of IP change
- Debug mode (`VERBOSE=1`) for detailed logging
- Configurable TTL (`DNS_TTL`, default 300 seconds)
- Exit codes for structured error handling (0-4)

## Quick Start

1. Install dependencies: `sudo apt-get install jq`
2. Download the script and make it executable (see [Installation](#installation))
3. Create an Azure Service Principal (see [Configuration](#configuration))
4. Set the environment variables (see [Environment variables](#environment-variables))
5. Test: `./azure-ddns`
6. Set up a cron job (see [Setting up a cron job](#setting-up-a-cron-job))

## Requirements

| Dependency | Minimum version | Check command | Default on Pi? |
|------------|-----------------|---------------|----------------|
| bash | >= 4.x | `bash --version` | Yes |
| curl | >= 7.68 | `curl --version` | Yes |
| jq | >= 1.6 | `jq --version` | No |

Install jq (the only non-default dependency):

```bash
sudo apt-get install jq
```

## Installation

```bash
# Download the script
sudo curl -o /usr/local/bin/azure-ddns \
  https://raw.githubusercontent.com/geertvanzoest/azure-ddns/main/azure-ddns

# Make executable
sudo chmod +x /usr/local/bin/azure-ddns

# Verify
azure-ddns --help || echo "Installed at $(which azure-ddns)"
```

## Configuration

### Creating an Azure Service Principal

azure-ddns requires an Azure Service Principal with minimal permissions on the DNS zone. Follow these steps using the Azure CLI (`az`):

```bash
# 1. Create app registration
az ad app create --display-name "azure-ddns"
# Note the appId from the output -> this becomes AZURE_CLIENT_ID
```

```bash
# 2. Create Service Principal
az ad sp create --id <APP_ID>
```

```bash
# 3. Generate client secret
az ad app credential reset --id <APP_ID> --display-name "azure-ddns-secret"
# Note password from the output -> this becomes AZURE_CLIENT_SECRET
# Note tenant from the output -> this becomes AZURE_TENANT_ID
```

```bash
# 4. Assign DNS Zone Contributor role (scoped to zone level)
az role assignment create \
  --assignee <APP_ID> \
  --role "DNS Zone Contributor" \
  --scope "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RESOURCE_GROUP>/providers/Microsoft.Network/dnsZones/<ZONE_NAME>"
```

The scope is intentionally limited to the specific DNS zone. The Service Principal only receives permissions on that single zone, not on the entire subscription or resource group.

### Environment variables

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `AZURE_TENANT_ID` | Yes | Microsoft Entra tenant GUID | `aaaabbbb-0000-cccc-1111-dddd2222eeee` |
| `AZURE_CLIENT_ID` | Yes | Service Principal application ID | `11112222-bbbb-3333-cccc-4444dddd5555` |
| `AZURE_CLIENT_SECRET` | Yes | Service Principal secret | `A1bC2dE3fH4iJ5kL6mN7oP8qR9sT0u` |
| `AZURE_SUBSCRIPTION_ID` | Yes | Azure subscription GUID | `00000000-0000-0000-0000-000000000000` |
| `AZURE_RESOURCE_GROUP` | Yes | Resource group of the DNS zone | `rg-dns` |
| `DNS_ZONE_NAME` | Yes | DNS zone name (without trailing dot) | `example.com` |
| `DNS_RECORD_NAME` | Yes | Relative record name | `home` (results in `home.example.com`) |
| `DNS_TTL` | No | TTL in seconds (default: 300) | `300` |

**Method 1: Via `/etc/environment`** (persistent, all users)

Add the variables to `/etc/environment`:

```bash
sudo tee -a /etc/environment << 'EOF'
AZURE_TENANT_ID=<YOUR_TENANT_ID>
AZURE_CLIENT_ID=<YOUR_CLIENT_ID>
AZURE_CLIENT_SECRET=<YOUR_CLIENT_SECRET>
AZURE_SUBSCRIPTION_ID=<YOUR_SUBSCRIPTION_ID>
AZURE_RESOURCE_GROUP=<YOUR_RESOURCE_GROUP>
DNS_ZONE_NAME=<YOUR_ZONE>
DNS_RECORD_NAME=<YOUR_RECORD>
EOF
```

**Method 2: Via crontab** (cron only, see [Setting up a cron job](#setting-up-a-cron-job))

The variables are set directly in the crontab entry. See the example below.

> **Warning:** NEVER store secrets in the script itself. Always use environment variables.

## Usage

### Running manually

```bash
# Normal (only updates if IP has changed)
./azure-ddns

# Force update (always update, regardless of IP change)
./azure-ddns --force

# Debug mode (detailed logging)
VERBOSE=1 ./azure-ddns

# Combination: force update with debug output
VERBOSE=1 ./azure-ddns --force
```

### Setting up a cron job

Open the crontab:

```bash
crontab -e
```

Add an entry to run the script every 5 minutes:

```bash
*/5 * * * * AZURE_TENANT_ID=xxx AZURE_CLIENT_ID=xxx AZURE_CLIENT_SECRET=xxx AZURE_SUBSCRIPTION_ID=xxx AZURE_RESOURCE_GROUP=xxx DNS_ZONE_NAME=xxx DNS_RECORD_NAME=xxx /usr/local/bin/azure-ddns >> /var/log/azure-ddns.log 2>&1
```

If the environment variables are already in `/etc/environment`, this suffices:

```bash
*/5 * * * * /usr/local/bin/azure-ddns >> /var/log/azure-ddns.log 2>&1
```

Output is written to `/var/log/azure-ddns.log` for troubleshooting. Create the log file if it doesn't exist yet:

```bash
sudo touch /var/log/azure-ddns.log
sudo chown $(whoami) /var/log/azure-ddns.log
```

### Lock file

The script uses `/tmp/azure-ddns.lock` via `flock` to prevent two instances from running simultaneously. If a previous run is still in progress, the new run is skipped with the message "Another instance is running, skipped". No user action is required.

## Troubleshooting

### Exit codes

| Code | Constant | Meaning | Possible causes | Solution |
|------|----------|---------|-----------------|----------|
| 0 | EXIT_OK | Success | - | No action needed |
| 1 | EXIT_CONFIG | Configuration error | Missing env var, jq not installed | Check all required env vars, install jq |
| 2 | EXIT_IP | IP detection failed | No internet, IP services unreachable | Check internet connection, test `curl https://icanhazip.com` |
| 3 | EXIT_AUTH | Authentication failed | Invalid credentials, expired secret, wrong tenant | Check AZURE_TENANT_ID/CLIENT_ID/CLIENT_SECRET, renew secret |
| 4 | EXIT_DNS | DNS operation failed | Insufficient permissions, wrong zone/record name | Check RBAC role, resource group, zone name |

Check the exit code after a run:

```bash
./azure-ddns; echo "Exit code: $?"
```

### Debug mode

Use `VERBOSE=1` for detailed logging:

```bash
VERBOSE=1 ./azure-ddns
```

This shows:
- Which configuration is loaded
- OAuth2 token status
- Which IP service is used and the detected IP
- Comparison of current DNS record with the new IP
- DNS update payload

### Common issues

**"Another instance is running, skipped"**

A previous run is still in progress. Wait for it to finish. Check if there's an active process:

```bash
ps aux | grep azure-ddns
```

If no process is running but the message persists, restart the Pi or wait until the next reboot (flock is automatically released when the process ends).

**HTTP 401 on token request (exit code 3)**

The client secret has expired or is incorrect. Generate a new secret:

```bash
az ad app credential reset --id <APP_ID> --display-name "azure-ddns-secret"
```

Then update `AZURE_CLIENT_SECRET` in the environment variables.

**HTTP 403 on DNS update (exit code 4)**

The DNS Zone Contributor role is not (correctly) assigned. Check the role assignment:

```bash
az role assignment list \
  --assignee <APP_ID> \
  --scope "/subscriptions/<SUB_ID>/resourceGroups/<RG>/providers/Microsoft.Network/dnsZones/<ZONE>"
```

Reassign the role if it's missing (see [Creating an Azure Service Principal](#creating-an-azure-service-principal)).

**No IP detected (exit code 2)**

Check if the Pi can send outbound HTTPS traffic:

```bash
curl -s https://icanhazip.com
curl -s https://checkip.amazonaws.com
```

If both fail, check the internet connection and any firewall rules.

## IP services

azure-ddns tries the following services to detect the public IP address:

| Order | Service | URL | Owner |
|-------|---------|-----|-------|
| 1 (primary) | icanhazip.com | `https://icanhazip.com` | Cloudflare |
| 2 (fallback) | checkip.amazonaws.com | `https://checkip.amazonaws.com` | Amazon AWS |

If the primary service is unreachable, the fallback is used automatically.

## Technical details

- **Azure DNS REST API version:** 2018-05-01 (current stable GA release)
- **OAuth2 flow:** Client credentials grant via Microsoft Entra
- **Token endpoint:** `https://login.microsoftonline.com/{tenantId}/oauth2/v2.0/token`
- **IP validation:** Strict IPv4 regex validation on IP service responses
