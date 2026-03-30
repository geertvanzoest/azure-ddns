#!/usr/bin/env bash
set -euo pipefail

# ns4j installer — sets up the DDNS client as a systemd timer on a Raspberry Pi.

INSTALL_DIR="/opt/ns4j"
CONFIG_DIR="/etc/ns4j"
SYSTEMD_DIR="/etc/systemd/system"

echo "==> Installing ns4j Azure DDNS client"

# Check Node.js version
NODE_VERSION=$(node -v 2>/dev/null | sed 's/v//' | cut -d. -f1)
if [ -z "$NODE_VERSION" ] || [ "$NODE_VERSION" -lt 18 ]; then
  echo "[error] Node.js >= 18 is required (found: $(node -v 2>/dev/null || echo 'none'))"
  exit 1
fi
echo "    Node.js $(node -v) detected"

# Create system user (no login, no home)
if ! id ns4j &>/dev/null; then
  echo "==> Creating system user 'ns4j'"
  sudo useradd --system --no-create-home --shell /usr/sbin/nologin ns4j
fi

# Install application
echo "==> Copying files to ${INSTALL_DIR}"
sudo mkdir -p "$INSTALL_DIR"
sudo cp index.mjs package.json "$INSTALL_DIR/"
sudo chown -R root:ns4j "$INSTALL_DIR"
sudo chmod 750 "$INSTALL_DIR"
sudo chmod 640 "$INSTALL_DIR/index.mjs" "$INSTALL_DIR/package.json"

# Configuration
if [ ! -f "${CONFIG_DIR}/.env" ]; then
  echo "==> Creating config directory ${CONFIG_DIR}"
  sudo mkdir -p "$CONFIG_DIR"
  sudo cp .env.example "${CONFIG_DIR}/.env"
  sudo chown -R root:ns4j "$CONFIG_DIR"
  sudo chmod 750 "$CONFIG_DIR"
  sudo chmod 640 "${CONFIG_DIR}/.env"
  echo "    [!] Edit ${CONFIG_DIR}/.env with your Azure credentials"
else
  echo "    Config already exists at ${CONFIG_DIR}/.env (skipping)"
fi

# Install systemd units
echo "==> Installing systemd units"
sudo cp systemd/ns4j.service "$SYSTEMD_DIR/"
sudo cp systemd/ns4j.timer "$SYSTEMD_DIR/"
sudo systemctl daemon-reload

echo "==> Enabling and starting timer"
sudo systemctl enable ns4j.timer
sudo systemctl start ns4j.timer

echo ""
echo "Installation complete!"
echo ""
echo "Next steps:"
echo "  1. Edit ${CONFIG_DIR}/.env with your Azure credentials"
echo "  2. Test manually:  sudo systemctl start ns4j.service"
echo "  3. Check logs:     journalctl -u ns4j.service -f"
echo "  4. Timer status:   systemctl list-timers ns4j.timer"
