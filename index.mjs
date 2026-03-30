#!/usr/bin/env node

/**
 * ns4j — Zero-dependency Azure DDNS client for Raspberry Pi
 *
 * Updates an Azure DNS A-record when the public IP address changes.
 * Designed for systemd timer invocation (oneshot) or standalone daemon mode.
 *
 * Required environment variables: see .env.example
 */

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { resolve } from 'node:path';

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

const CONFIG = Object.freeze({
  tenantId:       env('AZURE_TENANT_ID'),
  clientId:       env('AZURE_CLIENT_ID'),
  clientSecret:   env('AZURE_CLIENT_SECRET'),
  subscriptionId: env('AZURE_SUBSCRIPTION_ID'),
  resourceGroup:  env('AZURE_RESOURCE_GROUP'),
  dnsZone:        env('AZURE_DNS_ZONE'),
  dnsRecord:      env('AZURE_DNS_RECORD', '@'),
  ttl:            envInt('DNS_TTL', 300),
  stateDir:       env('STATE_DIR', '/run/ns4j'),
  checkInterval:  envInt('CHECK_INTERVAL_MS', 300_000),   // 5 min
  forceInterval:  envInt('FORCE_INTERVAL_MS', 86_400_000), // 24 h
  requestTimeout: envInt('REQUEST_TIMEOUT_MS', 10_000),   // 10 s
  daemon:         env('DAEMON_MODE', 'false') === 'true',
});

// ---------------------------------------------------------------------------
// IP detection services (ordered by reliability)
// ---------------------------------------------------------------------------

const IP_SERVICES = [
  'https://icanhazip.com',
  'https://checkip.amazonaws.com',
  'https://api.ipify.org',
  'https://ifconfig.me/ip',
];

const IPV4_RE = /^(\d{1,3}\.){3}\d{1,3}$/;

function isValidIPv4(ip) {
  if (!isValidIPv4(ip)) return false;
  return ip.split('.').every(o => { const n = Number(o); return n >= 0 && n <= 255; });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function env(key, fallback) {
  const val = process.env[key];
  if (val !== undefined && val !== '') return val;
  if (fallback !== undefined) return fallback;
  console.error(`[fatal] Missing required environment variable: ${key}`);
  process.exit(1);
}

function envInt(key, fallback) {
  const val = Number(env(key, String(fallback)));
  if (!Number.isFinite(val) || val < 0) {
    console.error(`[fatal] Invalid numeric value for ${key}: "${env(key, String(fallback))}"`);
    process.exit(1);
  }
  return val;
}

function log(level, msg) {
  const ts = new Date().toISOString();
  const fn = level === 'error' ? console.error : console.log;
  fn(`[${ts}] [${level}] ${msg}`);
}

class HttpError extends Error {
  constructor(status, body) {
    super(`HTTP ${status}: ${body}`);
    this.status = status;
  }
}

// ---------------------------------------------------------------------------
// State persistence (tmpfs — survives between timer ticks, lost on reboot)
// ---------------------------------------------------------------------------

function statePath() {
  return resolve(CONFIG.stateDir, 'state.json');
}

function loadState() {
  try {
    return JSON.parse(readFileSync(statePath(), 'utf-8'));
  } catch {
    return { ip: null, updatedAt: 0, tokenData: null };
  }
}

function saveState(state) {
  try {
    mkdirSync(CONFIG.stateDir, { recursive: true });
    writeFileSync(statePath(), JSON.stringify(state));
  } catch (err) {
    log('warn', `Could not persist state: ${err.message}`);
  }
}

// ---------------------------------------------------------------------------
// OAuth2 token acquisition & caching
// ---------------------------------------------------------------------------

const TOKEN_URL = `https://login.microsoftonline.com/${CONFIG.tenantId}/oauth2/v2.0/token`;

async function acquireToken(state) {
  // Return cached token if still valid (with 5-min buffer)
  if (state.tokenData) {
    const { token, expiresAt } = state.tokenData;
    if (Date.now() < expiresAt - 300_000) return token;
  }

  log('info', 'Acquiring new Azure AD token');

  const res = await fetchWithTimeout(TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type:    'client_credentials',
      client_id:     CONFIG.clientId,
      client_secret: CONFIG.clientSecret,
      scope:         'https://management.azure.com/.default',
    }),
  });

  if (!res.ok) {
    const body = await res.text();
    throw new HttpError(res.status, body);
  }

  const data = await res.json();
  const tokenData = {
    token:     data.access_token,
    expiresAt: Date.now() + data.expires_in * 1000,
  };

  state.tokenData = tokenData;
  return tokenData.token;
}

// ---------------------------------------------------------------------------
// Public IP detection with failover
// ---------------------------------------------------------------------------

async function detectPublicIp() {
  for (const url of IP_SERVICES) {
    try {
      const res = await fetchWithTimeout(url);
      if (!res.ok) continue;

      const ip = (await res.text()).trim();
      if (isValidIPv4(ip)) return { ip, source: url };

      log('warn', `Invalid IP response from ${url}: "${ip}"`);
    } catch (err) {
      log('warn', `IP service ${url} failed: ${err.message}`);
    }
  }
  return null;
}

async function detectAndConfirmIp(currentIp) {
  const result = await detectPublicIp();
  if (!result) return null;

  const { ip, source } = result;

  // If IP hasn't changed, no confirmation needed
  if (ip === currentIp) return ip;

  // IP changed — confirm with a *different* service
  log('info', `IP change detected (${currentIp || 'none'} -> ${ip}), confirming...`);

  for (const url of IP_SERVICES) {
    if (url === source) continue; // skip the original source
    try {
      const res = await fetchWithTimeout(url);
      if (!res.ok) continue;
      const confirmIp = (await res.text()).trim();
      if (confirmIp === ip) {
        log('info', `IP change confirmed by ${url}`);
        return ip;
      }
    } catch {
      continue;
    }
  }

  log('warn', 'Could not confirm IP change with a second service');
  return null;
}

// ---------------------------------------------------------------------------
// Azure DNS update
// ---------------------------------------------------------------------------

function dnsApiUrl() {
  const e = encodeURIComponent;
  const { subscriptionId, resourceGroup, dnsZone, dnsRecord } = CONFIG;
  return (
    `https://management.azure.com/subscriptions/${e(subscriptionId)}` +
    `/resourceGroups/${e(resourceGroup)}` +
    `/providers/Microsoft.Network/dnsZones/${e(dnsZone)}` +
    `/A/${e(dnsRecord)}?api-version=2018-05-01`
  );
}

async function updateDnsRecord(token, ip) {
  const url = dnsApiUrl();

  const res = await fetchWithTimeout(url, {
    method: 'PUT',
    headers: {
      Authorization:  `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      properties: {
        TTL: CONFIG.ttl,
        ARecords: [{ ipv4Address: ip }],
      },
    }),
  });

  if (!res.ok) {
    const body = await res.text();
    throw new HttpError(res.status, body);
  }

  const data = await res.json();
  return data;
}

// ---------------------------------------------------------------------------
// Fetch with timeout helper
// ---------------------------------------------------------------------------

async function fetchWithTimeout(url, options = {}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), CONFIG.requestTimeout);
  try {
    return await fetch(url, { ...options, signal: controller.signal });
  } finally {
    clearTimeout(timer);
  }
}

// ---------------------------------------------------------------------------
// Retry with exponential backoff
// ---------------------------------------------------------------------------

async function withRetry(fn, { retries = 3, baseDelay = 5000, label = 'operation' } = {}) {
  for (let attempt = 1; attempt <= retries; attempt++) {
    try {
      return await fn();
    } catch (err) {
      // Don't retry auth errors
      if (err instanceof HttpError && (err.status === 401 || err.status === 403)) throw err;

      if (attempt === retries) throw err;

      const delay = baseDelay * Math.pow(2, attempt - 1) * (0.8 + Math.random() * 0.4);
      log('warn', `${label} attempt ${attempt}/${retries} failed: ${err.message} — retrying in ${Math.round(delay / 1000)}s`);
      await sleep(delay);
    }
  }
}

function sleep(ms) {
  return new Promise(r => setTimeout(r, ms));
}

// ---------------------------------------------------------------------------
// Main update cycle
// ---------------------------------------------------------------------------

async function runOnce() {
  const state = loadState();

  // 1. Detect public IP
  const ip = await detectAndConfirmIp(state.ip);
  if (!ip) {
    log('error', 'Could not detect public IP from any service');
    return false;
  }

  // 2. Determine if update is needed
  const ipChanged = ip !== state.ip;
  const forceRefresh = Date.now() - state.updatedAt > CONFIG.forceInterval;

  if (!ipChanged && !forceRefresh) {
    log('info', `IP unchanged (${ip}), no update needed`);
    return true;
  }

  // 3. Acquire token & update DNS
  const reason = ipChanged ? `IP changed: ${state.ip || 'none'} -> ${ip}` : 'forced refresh (24h)';
  log('info', `Updating DNS: ${reason}`);

  const token = await withRetry(
    () => acquireToken(state),
    { label: 'token acquisition' },
  );

  await withRetry(
    () => updateDnsRecord(token, ip),
    { label: 'DNS update' },
  );

  // 4. Save state
  state.ip = ip;
  state.updatedAt = Date.now();
  saveState(state);

  log('info', `DNS updated successfully: ${CONFIG.dnsRecord}.${CONFIG.dnsZone} -> ${ip} (TTL ${CONFIG.ttl}s)`);
  return true;
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

async function main() {
  log('info', `ns4j starting — zone=${CONFIG.dnsZone} record=${CONFIG.dnsRecord} mode=${CONFIG.daemon ? 'daemon' : 'oneshot'}`);

  if (!CONFIG.daemon) {
    // Oneshot mode: run once and exit (for systemd timer)
    try {
      const ok = await runOnce();
      process.exit(ok ? 0 : 1);
    } catch (err) {
      log('error', `Fatal: ${err.message}`);
      process.exit(1);
    }
  }

  // Daemon mode: run on interval
  const tick = async () => {
    try {
      await runOnce();
    } catch (err) {
      log('error', `Cycle failed: ${err.message}`);
    }
  };

  await tick(); // immediate first run
  setInterval(tick, CONFIG.checkInterval);
  log('info', `Daemon running — checking every ${CONFIG.checkInterval / 1000}s`);
}

main();
