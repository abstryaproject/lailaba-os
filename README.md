# Lailaba OS — custom amd64 ISO builder (FULL-STATE CLONE)

Builds a bootable Debian-amd64 live + install ISO that ships YOUR COMPLETE
Lailaba runtime — pre-installed and auto-starting on first boot:

  - Lailaba AI server (FastAPI, :8000)   systemd: lailaba-ai
  - Lailaba agent core (:7000)           systemd: lailaba-agent
  - Messaging gateway + watchdog         systemd: lailaba-gateway[-watch]
  - Cloudflare tunnel (opt-in)           systemd: lailaba-tunnel
  - Lailaba Guard watchdog               systemd: lailaba-guard
  - Local SMTP MTA (:8025)               systemd: lailaba-smtp
  - Live Range training server (:8080)   systemd: lailaba-lab
  - IP watchdog (every 2m)               systemd timer: lailaba-ipwatchdog
  - FUBK re-audit (hourly, off)          systemd timer: lailaba-fubk-reaudit
  - ALL your configs, memories, skills, cron jobs, guards, rebrand, db

## Why not "convert Termux"?
Termux is Android/ARM userspace — it cannot boot on amd64 hardware/VM. This
builder assembles a REAL Debian-amd64 system that reproduces your stack 1:1.
Your lailaba-ai code already ships a systemd unit; we map every Termux tmux
session to a systemd unit.

## Two-phase build
Phase 1 (run on the SOURCE device — Termux/ARM is fine, it only tars):
  ./capture-state.sh                 # safe: configs + data, NO secrets
  ./capture-state.sh --with-secrets  # ALSO include API keys (.lailaba/.env)
  -> produces state/lailaba-state.tar.zst

Phase 2 (run on amd64 Debian/Ubuntu host OR GitHub Actions):
  - copy state/lailaba-state.tar.zst into lailaba-os-iso/state/
  - ./build.sh   ->  out/lailaba-os-amd64.iso
  (GitHub Actions: push repo, run "Build Lailaba OS ISO" workflow, download .iso)

## Install / boot
  VirtualBox: New VM (Linux/Debian 64-bit, 2GB RAM, 20GB disk) -> mount ISO ->
    boot -> "Install" or run live.
  Laptop/Server USB:
    dd if=lailaba-os-amd64.iso of=/dev/sdX bs=4M status=progress
  First boot: lailaba-firstboot.service rebuilds the ARM venvs for amd64,
  restores your cron jobs, then all services auto-start.
    Check:  sudo lailaba status
    Web UI: http://<host-ip>:8000   Admin: /admin

## Security note
The ISO bundles whatever capture-state.sh collected. With --with-secrets, your
API keys are INSIDE the .iso. Treat that image as a secret. For a distributable
image, capture WITHOUT secrets and set keys post-install via /root/lailaba-ai/.env.
