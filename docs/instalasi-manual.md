# Instalasi manual

Langkah yang sama dengan `install.sh`, tanpa script. Berguna untuk memahami apa yang dipasang, atau memasang sebagian saja. Jalankan dari folder repo, sebagai user biasa, di terminal sendiri.

```bash
cd ~/akses-sudo-claude
```

## 1. Cek prasyarat

```bash
claude auth status --text        # Claude Code harus terpasang dan sudah login
sudo -V | head -1                # harus "Sudo version 1.x" (≥ 1.8.21), bukan sudo-rs
sudo -l                          # tidak boleh ada NOPASSWD di bagian "may run"
sudo grep includedir /etc/sudoers   # harus ada "@includedir /etc/sudoers.d"
which jq || sudo apt install -y jq
```

## 2. Pasang jendela sudo global

```bash
f=$(mktemp)
sed "s/__USER__/$(id -un)/g" files/sudoers-claude-window.template > "$f"
cat "$f"                                       # pastikan username benar

sudo visudo -c -f "$f"                         # harus "parsed OK"
sudo install -m 0440 -o root -g root "$f" /etc/sudoers.d/$(id -un)-sudo-window
sudo visudo -c                                 # semua file harus "parsed OK"
rm -f "$f"
```

> [!NOTE]
> Pakai `sudo visudo`, bukan `visudo`. Di Debian, `/usr/sbin` tidak masuk PATH user biasa, sehingga `visudo` saja menghasilkan `command not found`.

> [!WARNING]
> Jangan tutup terminal kalau `sudo visudo -c` menampilkan error. Hapus file itu dari terminal yang sama: `sudo rm /etc/sudoers.d/$(id -un)-sudo-window`.

Setelah file terpasang, perintah sudo berikutnya akan **meminta password lagi**. Itu normal: cache lama tercatat per terminal, sedangkan sekarang sudo memakai cache global yang masih kosong.

```bash
sudo -l | grep -i timestamp      # harus ada timestamp_type=global, timestamp_timeout=15
```

## 3. Tambahkan alias

```bash
grep -q '^alias sudo-on=' ~/.bashrc || {
  echo '# >>> akses-sudo-claude >>>'
  cat files/bashrc-snippet.sh
  echo '# <<< akses-sudo-claude <<<'
} >> ~/.bashrc
source ~/.bashrc
type sudo-on sudo-off
```

## 4. Gabungkan izin ke `~/.claude/settings.json`

Isi yang sudah ada tetap dipertahankan, dan entri tidak diduplikasi:

```bash
mkdir -p ~/.claude
f=~/.claude/settings.json
[ -s "$f" ] || echo '{}' > "$f"
cp -p "$f" "$f.bak-$(date +%Y%m%d-%H%M%S)"
jq --slurpfile p files/settings-permissions.json '
  def uniq_keep: reduce .[] as $x ([]; if index([$x]) then . else . + [$x] end);
    .permissions.ask  = ((.permissions.ask  // []) + $p[0].permissions.ask  | uniq_keep)
  | .permissions.deny = ((.permissions.deny // []) + $p[0].permissions.deny | uniq_keep)' \
  "$f" > "$f.tmp" && mv "$f.tmp" "$f"
cat "$f"
```

## 5. Pasang aturan untuk Claude

```bash
if [ ! -f ~/.claude/CLAUDE.md ]; then
  cp files/CLAUDE.md ~/.claude/CLAUDE.md
elif ! grep -q '^## sudo' ~/.claude/CLAUDE.md; then
  { echo; sed -n '/^## sudo/,$p' files/CLAUDE.md; } >> ~/.claude/CLAUDE.md
fi
cat ~/.claude/CLAUDE.md
```

## 6. Restart Claude Code dan verifikasi

Keluar dari Claude Code (`/exit`), jalankan `claude` lagi, lalu ikuti bagian [Verifikasi](../README.md#verifikasi) di README.
