#!/usr/bin/env bash
# Pasang akses sudo untuk Claude Code: jendela sudo global 15 menit + persetujuan per perintah.
# Jalankan sebagai user biasa dari terminal sendiri (bukan lewat Claude), karena butuh password sudo.
# Aman dijalankan ulang: bagian yang sudah terpasang dilewati.
# Pemakaian: ./install.sh [-y]   (-y melewati konfirmasi Claude Code sudah terpasang dan login)
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$REPO_DIR/lib/common.sh"

[ "$(id -u)" -ne 0 ] || die "Jangan jalankan sebagai root. Jalankan sebagai user yang memakai Claude Code."
step "1/7 Claude Code terpasang dan sudah login"
if [ "${1:-}" = "-y" ]; then
  ok "dikonfirmasi lewat -y"
else
  warn "Pastikan Claude Code sudah terpasang dan sudah login sebelum lanjut."
  info "pasang : curl -fsSL https://claude.ai/install.sh | bash"
  info "login  : claude   (buka URL yang ditampilkan, lalu /exit)"
  info "cek    : claude auth status --text"
  read -rp "Ketik yes kalau Claude Code sudah terpasang dan sudah login: " answer || answer=""
  [ "${answer,,}" = yes ] || die "Dibatalkan, tidak ada yang diubah. Pasang dan login Claude Code dulu, lalu ulangi ./install.sh"
  ok "dikonfirmasi"
fi

command -v sudo >/dev/null || die "sudo belum terpasang. Lihat docs/distro.md bagian Debian."

step "2/7 Jenis sudo"
read -r flavor version <<<"$(sudo_flavor)"
[ "$flavor" = gnu ] || die "Butuh GNU sudo, terdeteksi: $flavor $version. Ubuntu 25.10+ memakai sudo-rs, lihat docs/distro.md."
version_ge "$version" "$MIN_SUDO_VERSION" || die "GNU sudo $version terlalu lama, butuh >= $MIN_SUDO_VERSION."
ok "GNU sudo $version"

step "3/7 Hak sudo (password diminta sekali)"
sudo -v || die "User $TARGET_USER tidak bisa memakai sudo. Tambahkan ke grup sudo, lihat docs/distro.md."
rules="$(sudo -l)"
if grep -Eq 'NOPASSWD|!authenticate' <<<"$rules"; then
  die "User $TARGET_USER punya aturan NOPASSWD, jadi jendela sudo tidak ada artinya. Hapus aturan itu dulu (cek: sudo -l)."
fi
ok "tidak ada NOPASSWD untuk $TARGET_USER"
sudo grep -Eq '^[@#]includedir[[:space:]]+/etc/sudoers\.d/?[[:space:]]*$' /etc/sudoers \
  || die "/etc/sudoers tidak membaca /etc/sudoers.d/ (baris @includedir tidak ada)."
ok "/etc/sudoers membaca /etc/sudoers.d/"

step "4/7 Paket pendukung"
if ! command -v jq >/dev/null; then
  command -v apt-get >/dev/null || die "jq belum terpasang. Pasang dulu lewat package manager distro."
  sudo apt-get update -qq
  sudo apt-get install -y -qq jq
fi
ok "$(jq --version)"

step "5/7 Jendela sudo global ($SUDOERS_FILE)"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
render_sudoers > "$tmp"
sudo visudo -c -f "$tmp" >/dev/null || die "Template sudoers tidak valid, tidak dipasang."
# Bandingkan tanpa komentar, supaya instalasi lama dengan komentar berbeda tidak ditulis ulang
if [ "$(sudo grep -v '^#' "$SUDOERS_FILE" 2>/dev/null)" = "$(grep -v '^#' "$tmp")" ]; then
  ok "sudah terpasang"
else
  # Pasang lalu validasi seluruh sudoers dalam satu proses root; kalau gagal, file langsung dihapus lagi
  sudo sh -c 'install -m 0440 -o root -g root "$1" "$2" && visudo -c -q || { rm -f "$2"; exit 1; }' sh "$tmp" "$SUDOERS_FILE" \
    || die "Validasi sudoers gagal. $SUDOERS_FILE dihapus lagi, tidak ada yang berubah."
  ok "terpasang: timestamp_type=global, timestamp_timeout=15"
fi

step "6/7 Alias sudo-on / sudo-off ($BASHRC)"
if [ -f "$BASHRC" ] && grep -q '^alias sudo-on=' "$BASHRC"; then
  ok "sudah ada"
else
  {
    if [ -s "$BASHRC" ] && [ -n "$(tail -c1 "$BASHRC")" ]; then echo; fi
    echo "$MARK_BEGIN"
    cat "$FILES_DIR/bashrc-snippet.sh"
    echo "$MARK_END"
  } >> "$BASHRC"
  ok "ditambahkan"
fi
if grep -q '^export SUDO_ASKPASS=' "$BASHRC"; then
  warn "$BASHRC masih meng-export SUDO_ASKPASS dari setup lama. Sebaiknya hapus baris itu."
fi

step "7/7 Konfigurasi Claude Code ($CLAUDE_DIR)"
mkdir -p "$CLAUDE_DIR"
if [ -s "$SETTINGS_FILE" ]; then
  jq empty "$SETTINGS_FILE" 2>/dev/null || die "$SETTINGS_FILE bukan JSON valid. Perbaiki dulu (cek: jq . $SETTINGS_FILE)."
  current="$(cat "$SETTINGS_FILE")"
else
  current='{}'
fi
if printf '%s\n' "$current" | merge_permissions | replace_if_changed "$SETTINGS_FILE" json; then
  ok "settings.json: aturan ask/deny ditambahkan"
else
  ok "settings.json: aturan ask/deny sudah ada"
fi
allow_sudo="$(jq -r '(.permissions.allow // [])[] | select(test("sudo"))' "$SETTINGS_FILE")"
[ -z "$allow_sudo" ] || warn "Ada aturan allow yang melewati prompt sudo, sebaiknya dihapus: $allow_sudo"

if [ ! -f "$CLAUDE_MD" ]; then
  cp "$FILES_DIR/CLAUDE.md" "$CLAUDE_MD"
  ok "CLAUDE.md: dibuat"
elif grep -q '^## sudo[[:space:]]*$' "$CLAUDE_MD"; then
  ok "CLAUDE.md: bagian ## sudo sudah ada"
else
  { echo; sed -n '/^## sudo/,$p' "$FILES_DIR/CLAUDE.md"; } >> "$CLAUDE_MD"
  ok "CLAUDE.md: bagian ## sudo ditambahkan"
fi

cat <<EOF

${C_OK}Selesai.${C_OFF} Langkah berikutnya:
  1. source ~/.bashrc   # muat alias sudo-on / sudo-off
  2. sudo-on            # minta password lagi; normal, cache sudo baru pindah ke mode global
  3. ./check.sh         # semua cek harus lolos
  4. Restart Claude Code, lalu ikuti README bagian "Verifikasi"
EOF
