#!/usr/bin/env bash
# build.sh — assemble the Lailaba OS amd64 live+install ISO.
# Run on an amd64 Debian/Ubuntu host (root or passwordless sudo).
# This script is portable; it does NOT run on Termux/ARM.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$HERE/out"
WORK="$HERE/build"
mkdir -p "$OUT" "$WORK"

echo "=== Lailaba OS ISO builder ==="
if [ "$(uname -m)" != "x86_64" ]; then
  echo "FATAL: builder must run on amd64 (x86_64), not $(uname -m)." >&2
  echo "Use an amd64 VM / GitHub Actions. See README." >&2
  exit 1
fi

# 1) Install build tooling
echo "[*] Installing live-build + tools..."
if command -v apt-get >/dev/null 2>&1; then
  sudo apt-get update -y
  sudo apt-get install -y --no-install-recommends \
    live-build debootstrap xorriso squashfs-tools \
    isolinux syslinux-utils grub-pc-bin grub-efi-amd64-bin \
    mtools dosfstools curl git ca-certificates
else
  echo "FATAL: need apt-based host (Debian/Ubuntu)." >&2
  exit 1
fi

# 2) Configure live-build
echo "[*] Configuring live-build..."
lb config \
  --architectures amd64 \
  --distribution bookworm \
  --debian-installer live \
  --debian-installer-gui true \
  --bootappend-live "boot=live components quiet splash" \
  --bootappend-install "quiet" \
  --binary-images iso-hybrid \
  --iso-application "Lailaba OS" \
  --iso-publisher "abstryaproject" \
  --iso-volume "LailabaOS" \
  --mirror-bootstrap "http://deb.debian.org/debian" \
  --mirror-binary "http://deb.debian.org/debian" \
  --archive-areas "main contrib non-free non-free-firmware"

# 3) Package list (what the ISO ships)
echo "[*] Writing package list..."
mkdir -p "$HERE/config/package-lists"
cat > "$HERE/config/package-lists/lailaba.list.chroot" <<'EOF'
# Base
systemd systemd-sysv
sudo curl wget git ca-certificates gnupg
python3 python3-venv python3-pip python3-dev build-essential
net-tools iproute2 ufw
# Desktop (lightweight, optional but nice for laptop/VM)
task-xfce-desktop xfce4-terminal
# Services support
nginx
EOF

# 4) Hooks: bake the Lailaba stack into the image
echo "[*] Writing build hooks..."
mkdir -p "$HERE/config/hooks/live"
cp "$HERE/hooks/0000-prep-env.chroot"        "$HERE/config/hooks/live/"
cp "$HERE/hooks/0050-ingest-state.chroot"   "$HERE/config/hooks/live/"
cp "$HERE/hooks/0100-install-lailaba.chroot" "$HERE/config/hooks/live/"
cp "$HERE/hooks/0200-install-agent.chroot"   "$HERE/config/hooks/live/"
cp "$HERE/hooks/0300-install-gateway.chroot"  "$HERE/config/hooks/live/"
cp "$HERE/hooks/0350-gateway-watch.chroot"   "$HERE/config/hooks/live/"
cp "$HERE/hooks/0400-install-cloudflared.chroot" "$HERE/config/hooks/live/"
cp "$HERE/hooks/0450-smtp.chroot"            "$HERE/config/hooks/live/"
cp "$HERE/hooks/0500-install-guard.chroot"   "$HERE/config/hooks/live/"
cp "$HERE/hooks/0550-lab.chroot"             "$HERE/config/hooks/live/"
cp "$HERE/hooks/0600-enable-services.chroot" "$HERE/config/hooks/live/"
cp "$HERE/hooks/0650-cron-timers.chroot"     "$HERE/config/hooks/live/"
cp "$HERE/hooks/0700-lailaba-cli.chroot"     "$HERE/config/hooks/live/"
cp "$HERE/hooks/0800-firstboot.chroot"       "$HERE/config/hooks/live/"
chmod +x "$HERE"/config/hooks/live/*.chroot

# 4b) Bundle the captured state tarball into the image (if present)
mkdir -p "$HERE/config/includes.chroot/opt/lailaba-state"
if [ -f "$HERE/state/lailaba-state.tar.zst" ]; then
  echo "[*] Bundling captured state tarball into ISO"
  cp "$HERE/state/lailaba-state.tar.zst" "$HERE/config/includes.chroot/opt/lailaba-state/"
else
  echo "[!] No state/lailaba-state.tar.zst found — ISO will install fresh (no your data)."
  echo "    Run ./capture-state.sh on the source device first, then rebuild."
fi

# 5) Build
echo "[*] Running lb build (this takes a while, ~10-30 min)..."
cd "$HERE"
sudo lb build 2>&1 | tee "$WORK/build.log"

# 6) Move artifact
if [ -f "$HERE/live-image-amd64.hybrid.iso" ]; then
  mv "$HERE/live-image-amd64.hybrid.iso" "$OUT/lailaba-os-amd64.iso"
  echo ""
  echo "=== BUILD OK ==="
  ls -lh "$OUT/lailaba-os-amd64.iso"
  echo "Flash to USB: dd if=$OUT/lailaba-os-amd64.iso of=/dev/sdX bs=4M status=progress"
else
  echo "FATAL: ISO not produced. Last 40 lines of build log:" >&2
  tail -40 "$WORK/build.log" >&2
  exit 1
fi
