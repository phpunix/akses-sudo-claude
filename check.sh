#!/usr/bin/env bash
# Cek status setup tanpa mengubah apa pun.
# Bagian yang butuh root hanya dicek kalau jendela sudo sedang terbuka (sudo-on), jadi aman dijalankan Claude.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$REPO_DIR/lib/common.sh"

problems=0
bad() { fail "$*"; problems=$((problems + 1)); }

step "sudo"
if ! command -v sudo >/dev/null; then
  bad "sudo belum terpasang"
else
  read -r flavor version <<<"$(sudo_flavor)"
  if [ "$flavor" = gnu ] && version_ge "$version" "$MIN_SUDO_VERSION"; then
    ok "GNU sudo $version"
  else
    bad "butuh GNU sudo >= $MIN_SUDO_VERSION, terdeteksi: $flavor $version (lihat docs/distro.md)"
  fi

  if sudo -n true 2>/dev/null; then
    ok "jendela sudo: terbuka"
    if sudo -n test -f "$SUDOERS_FILE"; then ok "$SUDOERS_FILE terpasang"; else bad "$SUDOERS_FILE belum terpasang"; fi
    rules="$(sudo -n -l 2>/dev/null)"
    if grep -q 'timestamp_type=global' <<<"$rules"; then
      ok "timestamp_type=global aktif"
    else
      bad "timestamp_type=global tidak aktif (cek: sudo visudo -c)"
    fi
    if grep -Eq 'NOPASSWD|!authenticate' <<<"$rules"; then
      bad "ada aturan NOPASSWD untuk $TARGET_USER; jendela sudo jadi tidak ada artinya"
    else
      ok "tidak ada NOPASSWD untuk $TARGET_USER"
    fi
  else
    warn "jendela sudo: tertutup. Cek file sudoers dan NOPASSWD dilewati; jalankan sudo-on lalu ulangi ./check.sh"
  fi
fi

step "Alias ($BASHRC)"
if [ -f "$BASHRC" ] && grep -q '^alias sudo-on=' "$BASHRC" && grep -q '^alias sudo-off=' "$BASHRC"; then
  ok "sudo-on / sudo-off ada"
else
  bad "alias sudo-on / sudo-off belum ada"
fi

step "Claude Code ($CLAUDE_DIR)"
if claude_bin >/dev/null; then
  ok "Claude Code terpasang (status login cek manual: claude auth status --text)"
else
  bad "Claude Code belum terpasang"
fi

if ! command -v jq >/dev/null; then
  bad "jq belum terpasang, settings.json tidak bisa dicek"
elif [ ! -f "$SETTINGS_FILE" ]; then
  bad "$SETTINGS_FILE belum ada"
elif ! jq empty "$SETTINGS_FILE" 2>/dev/null; then
  bad "$SETTINGS_FILE bukan JSON valid"
else
  missing="$(jq -r --slurpfile p "$FILES_DIR/settings-permissions.json" '
    ($p[0].permissions.ask  - (.permissions.ask  // [])) + ($p[0].permissions.deny - (.permissions.deny // [])) | .[]' "$SETTINGS_FILE")"
  if [ -z "$missing" ]; then ok "settings.json: aturan ask/deny lengkap"; else bad "settings.json: aturan belum ada: $(echo $missing)"; fi

  allow_sudo="$(jq -r '(.permissions.allow // [])[] | select(test("sudo"))' "$SETTINGS_FILE")"
  [ -z "$allow_sudo" ] || warn "ada aturan allow yang melewati prompt sudo: $allow_sudo"

  mode="$(jq -r '.permissions.defaultMode // empty' "$SETTINGS_FILE")"
  [ "$mode" != bypassPermissions ] || warn "defaultMode=bypassPermissions: prompt persetujuan sudo dilewati"
fi

if [ -f "$CLAUDE_MD" ] && grep -q '^## sudo[[:space:]]*$' "$CLAUDE_MD"; then
  ok "CLAUDE.md: bagian ## sudo ada"
else
  bad "CLAUDE.md: bagian ## sudo belum ada"
fi

echo
if [ "$problems" -eq 0 ]; then
  ok "Semua cek lolos."
else
  fail "$problems masalah ditemukan. Jalankan ./install.sh atau lihat docs/troubleshooting.md."
  exit 1
fi
