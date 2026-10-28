# Konstanta dan fungsi bersama untuk install.sh, uninstall.sh, dan check.sh.
# File ini di-source, bukan dijalankan. REPO_DIR harus sudah di-set oleh pemanggil.

FILES_DIR="$REPO_DIR/files"
TARGET_USER="$(id -un)"
# Nama file di /etc/sudoers.d/ tidak boleh mengandung titik atau diakhiri "~", karena diabaikan sudo
SUDOERS_FILE="/etc/sudoers.d/${TARGET_USER//./_}-sudo-window"
CLAUDE_DIR="$HOME/.claude"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
BASHRC="$HOME/.bashrc"
MARK_BEGIN="# >>> akses-sudo-claude >>>"
MARK_END="# <<< akses-sudo-claude <<<"
MIN_SUDO_VERSION="1.8.21"   # versi pertama yang mendukung timestamp_type

if [ -t 1 ]; then
  C_OK=$'\e[32m'; C_WARN=$'\e[33m'; C_ERR=$'\e[31m'; C_DIM=$'\e[2m'; C_BOLD=$'\e[1m'; C_OFF=$'\e[0m'
else
  C_OK=; C_WARN=; C_ERR=; C_DIM=; C_BOLD=; C_OFF=
fi

step() { printf '\n%s== %s%s\n' "$C_BOLD" "$*" "$C_OFF"; }
ok()   { printf '%s✔%s %s\n' "$C_OK" "$C_OFF" "$*"; }
info() { printf '%s  %s%s\n' "$C_DIM" "$*" "$C_OFF"; }
warn() { printf '%s!%s %s\n' "$C_WARN" "$C_OFF" "$*"; }
fail() { printf '%s✘%s %s\n' "$C_ERR" "$C_OFF" "$*" >&2; }
die()  { fail "$*"; exit 1; }

# Cetak "gnu <versi>", "sudo-rs <versi>", atau "unknown <baris pertama sudo -V>"
sudo_flavor() {
  local line
  line="$(sudo -V 2>/dev/null | head -1 || true)"
  case "$line" in
    "Sudo version "*) echo "gnu ${line#Sudo version }" ;;
    sudo-rs*)         echo "sudo-rs ${line#sudo-rs }" ;;
    *)                echo "unknown ${line:-tidak-terbaca}" ;;
  esac
}

# version_ge A B: sukses kalau versi A >= B (akhiran seperti "p5" aman untuk sort -V)
version_ge() { [ "$(printf '%s\n' "$2" "$1" | sort -V | head -1)" = "$2" ]; }

# Path claude dari PATH, atau dari ~/.local/bin (di Debian baru masuk PATH setelah login ulang)
claude_bin() {
  command -v claude 2>/dev/null && return
  [ -x "$HOME/.local/bin/claude" ] && echo "$HOME/.local/bin/claude"
}

render_sudoers() { sed "s/__USER__/$TARGET_USER/g" "$FILES_DIR/sudoers-claude-window.template"; }

# Transformasi stdin -> stdout. Urutan entri yang sudah ada dipertahankan, tanpa duplikat.
merge_permissions() {
  jq --slurpfile p "$FILES_DIR/settings-permissions.json" '
    def uniq_keep: reduce .[] as $x ([]; if index([$x]) then . else . + [$x] end);
      .permissions.ask  = ((.permissions.ask  // []) + $p[0].permissions.ask  | uniq_keep)
    | .permissions.deny = ((.permissions.deny // []) + $p[0].permissions.deny | uniq_keep)'
}

remove_permissions() {
  jq --slurpfile p "$FILES_DIR/settings-permissions.json" '
    def prune(k): if (.permissions[k] // []) == [] then del(.permissions[k]) else . end;
    if .permissions == null then . else
        .permissions.ask  = ((.permissions.ask  // []) - $p[0].permissions.ask)
      | .permissions.deny = ((.permissions.deny // []) - $p[0].permissions.deny)
      | prune("ask") | prune("deny")
      | if .permissions == {} then del(.permissions) else . end
    end'
}

# Buang blok bertanda, plus sisa alias versi lama yang tidak bertanda
strip_bashrc() {
  awk -v b="$MARK_BEGIN" -v e="$MARK_END" '
    $0 == b { skip = 1; next }
    $0 == e { skip = 0; next }
    skip { next }
    /^alias sudo-(on|off)=/ || /^# sudo: buka jendela 15 menit/ { next }
    { print }'
}

# Buang bagian "## sudo" sampai heading level 1/2 berikutnya
strip_claude_md() {
  awk '
    /^## sudo[[:space:]]*$/ { skip = 1; next }
    skip && /^(#|##) / { skip = 0 }
    !skip { print }'
}

# replace_if_changed FILE [json]: tulis stdin ke FILE hanya kalau isinya berbeda.
# Membuat backup FILE.bak-<waktu> dulu. Mode json membandingkan isi, bukan format.
# Return 0 kalau FILE diubah, 1 kalau tidak ada perubahan.
replace_if_changed() {
  local file="$1" mode="${2:-text}" tmp backup same=1
  tmp="$(mktemp)"
  cat > "$tmp"
  if [ ! -f "$file" ]; then
    same=0
  elif [ "$mode" = json ]; then
    cmp -s <(jq -S . "$file" 2>/dev/null) <(jq -S . "$tmp") || same=0
  else
    cmp -s "$tmp" "$file" || same=0
  fi
  if [ "$same" = 1 ]; then rm -f "$tmp"; return 1; fi
  if [ -f "$file" ]; then
    backup="$file.bak-$(date +%Y%m%d-%H%M%S)"
    cp -p "$file" "$backup"
    info "backup: $backup"
  fi
  cat "$tmp" > "$file"   # tulis ulang isinya supaya permission file asli tetap
  rm -f "$tmp"
}
