#!/usr/bin/env bash
# One-time host setup for a staging/pilot Droplet (Ubuntu 24.04 LTS). Run as root from a checkout of
# infra/deploy:  sudo ./install-host.sh   (runbook: docs/ops/deploy.md §Host setup)
# Installs Docker, age, rclone, unattended upgrades; copies the stack to /opt/saarthee; installs timers.
# Secrets are NOT handled here: create /etc/saarthee/{api.env,backup.env,deploy.env} and certs by hand.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "run as root" >&2; exit 1; }
here="$(cd "$(dirname "$0")" && pwd)"

apt-get update
apt-get install -y --no-install-recommends ca-certificates curl age rclone unattended-upgrades jq
dpkg-reconfigure -f noninteractive unattended-upgrades
if ! command -v docker >/dev/null; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    >/etc/apt/sources.list.d/docker.list
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
fi

# SSH: keys only (DigitalOcean cloud firewall limits port 22 to admin IPs).
sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl reload ssh || systemctl reload sshd || true

install -d -m 0755 /opt/saarthee /var/lib/saarthee
install -d -m 0700 /etc/saarthee /etc/saarthee/certs
cp "$here"/compose.yml /opt/saarthee/
install -m 0750 "$here"/{deploy,backup,restore,photo-mirror,retention}.sh /opt/saarthee/
for f in api.env backup.env deploy.env; do
  [[ -f /etc/saarthee/$f ]] || echo "TODO: create /etc/saarthee/$f (mode 600) — see docs/ops/environments.md"
done
chmod 600 /etc/saarthee/*.env 2>/dev/null || true

install -d /etc/systemd/journald.conf.d
cp "$here"/systemd/journald-saarthee.conf /etc/systemd/journald.conf.d/saarthee.conf
systemctl restart systemd-journald
cp "$here"/systemd/saarthee-*.{service,timer} /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now saarthee-backup.timer saarthee-photo-mirror.timer saarthee-retention.timer
systemctl list-timers 'saarthee-*' --no-pager
echo "host ready: add secrets, then /opt/saarthee/deploy.sh <tag>"
