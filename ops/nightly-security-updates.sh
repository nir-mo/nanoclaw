#!/usr/bin/env bash
# Nightly OS security updates for the NanoClaw host (Ubuntu).
#
# Security-only, via unattended-upgrades (Ubuntu's native mechanism — we don't
# hand-roll apt upgrade logic). Installed as a system-cron job by
# ops/install-cron.sh. This is the OPS layer: no agent, no model call, no tokens.
#
# Requires passwordless sudo (the default for the `ubuntu` user on EC2).
set -euo pipefail

echo "=== $(date -u +%Y-%m-%dT%H:%M:%SZ) nightly-security-updates ==="

# Ensure the native security-update runner is present (no-op if already there).
if ! command -v unattended-upgrade >/dev/null 2>&1; then
  sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y unattended-upgrades
fi

sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq
# unattended-upgrade applies the security pocket only by default.
sudo unattended-upgrade -v
sudo DEBIAN_FRONTEND=noninteractive apt-get -y autoremove --purge

# Kernel/security updates sometimes need a reboot. Don't surprise-reboot the bot
# mid-conversation — just flag it so you can reboot during a quiet window.
if [ -f /var/run/reboot-required ]; then
  echo "NOTE: reboot required (kernel/security). Not rebooting automatically."
  echo "      Reboot during a quiet window with: sudo reboot"
fi

echo "=== done ==="
