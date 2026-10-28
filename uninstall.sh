#!/usr/bin/env bash
# Lepas setup: hapus file sudoers, alias, aturan izin Claude Code, dan bagian "## sudo" di CLAUDE.md.
# File yang diubah di-backup dulu ke <file>.bak-<waktu>. Pakai -y untuk melewati konfirmasi.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$REPO_DIR/lib/common.sh"

[ "$(id -u)" -ne 0 ] || die "Jangan jalankan sebagai root. Jalankan sebagai user yang memakai Claude Code."

if [ "${1:-}" != "-y" ]; then
  cat <<EOF
Yang akan dihapus untuk user $TARGET_USER:
  - $SUDOERS_FILE (cache sudo kembali per terminal)
  - alias sudo-on / sudo-off di $BASHRC
  - aturan ask/deny sudo di $SETTINGS_FILE
  - bagian "## sudo" di $CLAUDE_MD
EOF
  read -rp "Lanjut? [y/N] " answer
  [[ "$answer" =~ ^[yY]$ ]] || { echo "Dibatalkan."; exit 0; }
fi

step "1/4 Jendela sudo global"
sudo -v
if sudo test -e "$SUDOERS_FILE"; then
  sudo sh -c 'rm -f "$1" && visudo -c -q' sh "$SUDOERS_FILE" || die "visudo -c gagal setelah menghapus $SUDOERS_FILE. Cek: sudo visudo -c"
  ok "dihapus"
else
  ok "tidak terpasang"
fi

step "2/4 Alias ($BASHRC)"
if [ -f "$BASHRC" ] && strip_bashrc < "$BASHRC" | replace_if_changed "$BASHRC"; then
  ok "dihapus (buka terminal baru supaya alias hilang)"
else
  ok "tidak ada"
fi

step "3/4 Izin Claude Code ($SETTINGS_FILE)"
if [ ! -s "$SETTINGS_FILE" ]; then
  ok "tidak ada"
else
  command -v jq >/dev/null || die "jq dibutuhkan untuk mengubah $SETTINGS_FILE."
  jq empty "$SETTINGS_FILE" 2>/dev/null || die "$SETTINGS_FILE bukan JSON valid. Perbaiki dulu."
  if remove_permissions < "$SETTINGS_FILE" | replace_if_changed "$SETTINGS_FILE" json; then
    ok "aturan sudo dihapus"
  else
    ok "tidak ada aturan dari repo ini"
  fi
fi

step "4/4 CLAUDE.md ($CLAUDE_MD)"
if [ ! -f "$CLAUDE_MD" ]; then
  ok "tidak ada"
elif cmp -s "$CLAUDE_MD" "$FILES_DIR/CLAUDE.md"; then
  mv "$CLAUDE_MD" "$CLAUDE_MD.bak-$(date +%Y%m%d-%H%M%S)"
  ok "dihapus (isinya hanya dari repo ini, backup disimpan)"
elif strip_claude_md < "$CLAUDE_MD" | replace_if_changed "$CLAUDE_MD"; then
  ok "bagian ## sudo dihapus"
else
  ok "tidak ada bagian ## sudo"
fi

echo
ok "Selesai. Restart Claude Code supaya settings.json dan CLAUDE.md yang baru terbaca."
