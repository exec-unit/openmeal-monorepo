#!/bin/bash
# Script to configure APT repositories for WSL/devcontainer environment
echo "Configuring APT repositories..."

# Backup original sources
if [ ! -f /etc/apt/sources.list.bak ]; then
  cp /etc/apt/sources.list /etc/apt/sources.list.bak 2>/dev/null || true
  echo "Backup created"
fi

# Remove conflicting sources.list.d files to avoid duplication warnings
if [ -d /etc/apt/sources.list.d ]; then
  rm -f /etc/apt/sources.list.d/debian.sources 2>/dev/null || true
  rm -f /etc/apt/sources.list.d/*.list 2>/dev/null || true
fi

# Configure reliable mirrors for WSL/container environment
cat <<'EOF' >/etc/apt/sources.list
# Debian repositories optimized for containers
deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware
deb http://deb.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
EOF

echo "APT sources configured with reliable mirrors"

# Update package lists with new repositories
apt-get update -qq 2>/dev/null || apt-get update
echo "APT repositories setup complete"