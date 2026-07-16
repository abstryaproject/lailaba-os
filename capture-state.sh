#!/usr/bin/env bash
# capture-state.sh — PHASE 1 (run on the SOURCE device: Termux/ARM is fine).
#
# Packages your LIVE Lailaba runtime into a single tarball that the ISO
# builder (Phase 2, amd64) expands onto the target system 1:1.
#
# CAPTURES (your full operating state / settings):
#   lailaba-ai/       server code + configs + .env.example (secrets opt-in) + db
#   .lailaba/         config.yaml, SOUL.md, memories, skills, cron jobs.json,
#                     guard state, gateway state, auth.json, platforms, kanban
#   .local/bin/       ALL service scripts (guard, watchdog, tunnel, smtp,
#                     rebrand, status, service-manager, fubk_reaudit ...)
#   bin/              lailaba CLI, hausa_tts, tunnel-watch, host script
#   lailaba-lab/      Live Range training server code + requirements
#   lailaba_cfg_files.txt   rebrand record (Lailaba, not Hermes)
#
# EXCLUDED (regenerable / not "your settings" / too heavy for ARM tar):
#   - venv dirs (ARM binaries; rebuilt for amd64 at firstboot)
#   - *.db-wal / *.db-shm temp files
#   - caches (__pycache__, .cache, image_cache, audio_cache, models_dev_cache)
#   - .bash_history, logs, large 170MB state.db (regenerated per session)
#   - binary toolkits (tools/, aircrack-ng/, sec-lab binaries) — reinstalled
#     via ~/tools/toolkit.sh on the target if needed
#   - API keys in .lailaba/.env  (use --with-secrets to include)
#
# USAGE:
#   ./capture-state.sh                 # safe: no secrets
#   ./capture-state.sh --with-secrets  # include .lailaba/.env + auth.json
# OUTPUT: state/lailaba-state.tar.zst  (copy into lailaba-os-iso/state/)

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$HERE/state"
WITH_SECRETS=0
[ "${1:-}" = "--with-secrets" ] && WITH_SECRETS=1

HOME_DIR="$HOME"
TS="$(date +%Y%m%d-%H%M%S)"
OUT="$HERE/state/lailaba-state.tar.zst"

echo "=== Lailaba state capture (Phase 1) ==="
echo "[*] HOME=$HOME_DIR  with-secrets=$WITH_SECRETS"

# Build an exclude list. GNU tar --exclude matches a path COMPONENT at any
# depth, so bare "venv" excludes lailaba-ai/venv, lailaba-lab/venv, etc.
EXCL="$HERE/state/.excludes"
{
  echo "__pycache__"
  echo "*.pyc"
  echo "*.db-wal"
  echo "*.db-shm"
  echo ".cache"
  echo "image_cache"
  echo "audio_cache"
  echo "models_dev_cache.json"
  echo "provider_models_cache.json"
  echo "ollama_cloud_models_cache.json"
  echo "response_store.db"
  echo "verification_evidence.db"
  echo "state.db"
  echo "lailaba.db"
  echo ".bash_history"
  echo "tmux.log"
  echo "uvicorn.log"
  echo "*.log"
  echo ".env.bak.*"
  echo "build"
  echo "venv"
} > "$EXCL"

# Secrets exclusion (unless requested)
if [ "$WITH_SECRETS" != 1 ]; then
  echo ".lailaba/.env" >> "$EXCL"
  echo "lailaba-ai/.env" >> "$EXCL"
  echo ".lailaba/auth.json" >> "$EXCL"
fi

# Tar the relevant trees directly (fast, single pass). Paths stored relative
# to $HOME_DIR so they unpack into /root on the target.
echo "[*] Packing (zstd -3 for speed on ARM) ..."
( cd "$HOME_DIR" && tar \
    --exclude-from="$EXCL" \
    -cf - \
    lailaba-ai \
    .lailaba/config.yaml .lailaba/SOUL.md .lailaba/skins .lailaba/skills \
    .lailaba/cron/jobs.json .lailaba/scripts .lailaba/memories \
    .lailaba/gateway_state.json .lailaba/gateway.pid .lailaba/gateway.lock \
    .lailaba/auth.json .lailaba/channel_directory.json \
    .lailaba/platforms .lailaba/pairing .lailaba/pastes .lailaba/portal_files \
    .lailaba/kanban .lailaba/hooks .lailaba/lsp .lailaba/sandboxes \
    .local/bin bin lailaba-lab lailaba_cfg_files.txt \
  ) | zstd -3 -o "$OUT"

rm -f "$EXCL"

# Manifest (separate, so it doesn't need to be inside the tar)
cat > "$HERE/state/MANIFEST.txt" <<EOF
Lailaba OS state capture
captured_at: $TS
source_arch: $(uname -m)
with_secrets: $WITH_SECRETS
home: $HOME_DIR
components: lailaba-ai, .lailaba, .local/bin, bin, lailaba-lab, rebrand-record
NOTE: venvs excluded (rebuilt amd64 at firstboot); state.db excluded (regenerated).
EOF

echo ""
echo "=== CAPTURE COMPLETE ==="
ls -lh "$OUT"
echo "Next: copy $OUT into lailaba-os-iso/state/ and run build on amd64."
