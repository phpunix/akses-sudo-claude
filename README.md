# akses-sudo-claude

Akses root yang **aman dan cepat** untuk Claude Code di VPS Linux: setiap perintah `sudo` harus kamu setujui, dan password cukup diketik sekali untuk jendela 15 menit. Dipasang dengan satu script, aman dijalankan ulang, dan bisa dilepas bersih.

```
Kamu:   sudo-on         ──►  jendela sudo terbuka 15 menit (global, lintas terminal)
                                   │
Claude: sudo -n <cmd>   ──►  Claude Code minta persetujuan ──► Yes ──► jalan tanpa password
                                   │
Kamu:   sudo-off        ──►  jendela ditutup (atau habis sendiri 15 menit setelah sudo terakhir dipakai)
```

## Daftar isi

- [Kompatibilitas](#kompatibilitas)
- [Isi repo](#isi-repo)
- [Mulai cepat: VPS fresh](#mulai-cepat-vps-fresh)
- [Apa yang dipasang](#apa-yang-dipasang)
- [Verifikasi](#verifikasi)
- [Pemakaian sehari-hari](#pemakaian-sehari-hari)
- [Catatan keamanan](#catatan-keamanan)
- [Uninstall](#uninstall)
- [Dokumen lain](#dokumen-lain)

## Kompatibilitas

Setup ini butuh **GNU sudo ≥ 1.8.21**, karena memakai `timestamp_type=global`. `install.sh` mengecek ini otomatis.

| Distro | sudo bawaan | Status |
|---|---|---|
| Ubuntu 24.04 LTS | GNU sudo 1.9.15 | ✅ Dites |
| Debian 13 (trixie) | GNU sudo 1.9.16 | ✅ Dites |
| Ubuntu 22.04 / Debian 12 | GNU sudo 1.9.x | ⚠️ Seharusnya jalan, belum dites |
| Ubuntu 25.10 / 26.04 | **sudo-rs** | ❌ Tidak jalan tanpa ganti ke GNU sudo, lihat [docs/distro.md](docs/distro.md) |

Cek cepat: `sudo -V | head -1` harus menampilkan `Sudo version 1.x`, bukan `sudo-rs`.

## Isi repo

```
akses-sudo-claude/
├── install.sh                          # pasang semuanya (aman dijalankan ulang)
├── check.sh                            # cek status tanpa mengubah apa pun
├── uninstall.sh                        # lepas semuanya, dengan backup
├── lib/common.sh                       # fungsi bersama ketiga script
├── files/
│   ├── sudoers-claude-window.template  # → /etc/sudoers.d/<user>-sudo-window
│   ├── bashrc-snippet.sh               # → ditambahkan ke ~/.bashrc
│   ├── settings-permissions.json       # → digabung ke ~/.claude/settings.json
│   └── CLAUDE.md                       # → ~/.claude/CLAUDE.md (atau bagian "## sudo" ditambahkan)
└── docs/
    ├── instalasi-manual.md             # langkah yang sama tanpa script
    ├── distro.md                       # catatan Ubuntu, Debian, sudo-rs
    └── troubleshooting.md
```

## Mulai cepat: VPS fresh

Semua langkah dijalankan **di terminal SSH kamu sendiri** sebagai user biasa, bukan sebagai root dan bukan lewat Claude.

### 0. Pastikan user kamu bisa sudo

```bash
groups                 # harus ada "sudo"
sudo -V | head -1      # harus "Sudo version 1.x"
```

Kalau `sudo` belum ada atau user belum di grup `sudo` (sering terjadi di Debian), lihat [docs/distro.md](docs/distro.md#debian).

### 1. Pasang Claude Code dan login

```bash
which curl || sudo apt install -y curl
curl -fsSL https://claude.ai/install.sh | bash
export PATH="$HOME/.local/bin:$PATH"   # sesi ini saja; login berikutnya otomatis
claude                                 # login lewat URL yang ditampilkan, lalu /exit
claude auth status --text              # pastikan sudah login
```

Langkah ini wajib. `install.sh` akan memintamu mengetik `yes` sebagai konfirmasi bahwa Claude Code sudah terpasang dan sudah login.

### 2. Bawa repo ini ke VPS

Pilih salah satu:

```bash
# a) dari VPS/PC lain yang punya repo ini
scp -r ~/akses-sudo-claude <user>@<ip-vps-baru>:~/

# b) kalau repo ini sudah kamu push ke Git hosting pribadi
sudo apt install -y git && git clone <url-repo-pribadi> ~/akses-sudo-claude
```

### 3. Jalankan installer

```bash
cd ~/akses-sudo-claude
./install.sh
```

Installer akan:
1. Minta konfirmasi `yes` bahwa Claude Code sudah terpasang dan sudah login (`./install.sh -y` untuk melewatinya). Jawaban lain membatalkan instalasi sebelum ada yang diubah
2. Cek jenis sudo (berhenti kalau sudo-rs)
3. Minta password sudo sekali, cek tidak ada `NOPASSWD`, dan cek `/etc/sudoers.d/` dibaca
4. Pasang `jq` kalau belum ada
5. Validasi lalu pasang file sudoers. Kalau `visudo -c` gagal, file langsung dihapus lagi
6. Tambahkan alias `sudo-on` / `sudo-off` ke `~/.bashrc`
7. Gabungkan aturan izin ke `~/.claude/settings.json` (dengan backup) dan pasang `CLAUDE.md`

Username diambil otomatis dari user yang menjalankan script, jadi tidak ada file yang perlu diedit.

### 4. Aktifkan dan cek

```bash
source ~/.bashrc
sudo-on          # minta password lagi; normal, cache sudo baru pindah ke mode global
./check.sh       # harus "Semua cek lolos."
```

Lanjut ke [Verifikasi](#verifikasi).

## Apa yang dipasang

| Bagian | Lokasi | Fungsi |
|---|---|---|
| Jendela sudo global | `/etc/sudoers.d/<user>-sudo-window` | `timestamp_type=global` membuat cache password berlaku di semua terminal, termasuk perintah Claude yang tanpa TTY. `timestamp_timeout=15` menutupnya 15 menit setelah sudo **terakhir dipakai**. |
| Alias | `~/.bashrc` | `sudo-on` = `sudo -v` (buka jendela). `sudo-off` = `sudo -k` (tutup sekarang). Sengaja tanpa loop keep-alive. |
| Izin Claude Code | `~/.claude/settings.json` | `ask: Bash(sudo:*)`: setiap perintah sudo memunculkan prompt persetujuan. `deny`: `rm -rf` dan `ufw disable/reset` lewat sudo langsung ditolak. |
| Aturan Claude | `~/.claude/CLAUDE.md` | Claude selalu memakai `sudo -n` (tidak pernah menunggu password). Kalau jendela tertutup, Claude berhenti dan memintamu menjalankan `sudo-on`. |

Aturan `deny` mencocokkan **awalan** perintah, jadi setiap pola ditulis dalam beberapa variasi (`sudo rm -rf`, `sudo -n rm -rf`, `-fr`, `-r -f`).

## Verifikasi

**Di terminal (dua sesi SSH atau dua panel tmux):**

```bash
# Terminal A
sudo -k; sudo -n true; echo "exit=$?"   # → "a password is required", exit=1
sudo-on                                  # → minta password, "sudo aktif 15 menit"

# Terminal B
sudo -n true && echo OK                  # → OK (bukti jendelanya global)
```

**Di Claude Code** (jalankan `claude`; mode default maupun auto sama-sama memunculkan prompt untuk sudo, asalkan bukan `bypassPermissions`):

| Minta Claude | Yang diharapkan |
|---|---|
| *"tes sudo -n true"* | Muncul prompt persetujuan. Setelah **Yes**, hasilnya exit 0 |
| *"jalankan sudo -n rm -rf /tmp/tes-deny-claude"* | **Langsung ditolak tanpa prompt** (aturan `deny`) |
| Jalankan `sudo-off` di terminal, lalu *"tes sudo -n true lagi"* | Prompt muncul, `sudo -n` gagal, lalu Claude berhenti dan meminta `sudo-on` |

## Pemakaian sehari-hari

| Situasi | Yang kamu lakukan |
|---|---|
| Mau Claude mengerjakan sesuatu yang butuh root | Jalankan `sudo-on` di panel tmux atau terminal lain, lalu beri tugas ke Claude |
| Claude bilang *"jalankan `sudo-on`"* | Jalankan `sudo-on`, lalu balas *"udah"* |
| Muncul prompt `sudo ...` di Claude Code | Baca perintahnya. **Yes** kalau sesuai, **No** kalau ragu |
| Selesai kerja admin | Jalankan `sudo-off` |
| Ragu setup masih benar | `./check.sh` |

> [!TIP]
> `sudo-on` harus dijalankan di terminal sungguhan. `! sudo-on` di dalam Claude Code tidak bisa, karena tidak ada TTY untuk mengetik password dan alias tidak dikenali di shell non-interaktif.

## Catatan keamanan

> [!CAUTION]
> Selama jendela terbuka, **proses apa pun milik user kamu** bisa memakai `sudo` tanpa password, bukan hanya Claude. Jaga jendelanya tetap singkat dan biasakan `sudo-off` setelah selesai.

- **Aturan `ask` tetap berlaku di auto mode.** Sudah dites: dengan auto mode sebagai mode default Claude Code, setiap perintah `sudo` tetap memunculkan prompt persetujuan. Pengecualiannya `bypassPermissions` (`--dangerously-skip-permissions`), mode yang dirancang untuk melewati prompt persetujuan. Jangan pakai mode itu bersama setup ini. `check.sh` memberi peringatan kalau `defaultMode` di `settings.json` bernilai `bypassPermissions`.
- **Aturan `ask`/`deny` hanya melihat perintah yang diketik Claude.** Script yang memanggil `sudo` di dalamnya (misalnya `./deploy.sh`) tidak memicu prompt sudo, jadi baca juga isi script yang mau dijalankan Claude.
- **Perintah `!` di Claude Code dijalankan atas namamu** dan melewati `ask` maupun `deny`. Baca dulu perintah yang disarankan Claude sebelum kamu ketik dengan `!`.
- **`deny` hanya pengaman tambahan.** Bentuk lain seperti `sudo -n rm --recursive --force` tetap lolos ke prompt `ask`. Pengaman utamanya adalah kamu membaca setiap prompt.
- **Jangan tambahkan loop keep-alive** (`while sudo -n -v; do sleep 120; done &`). Dengan jendela global, loop itu membuat root terbuka tanpa batas waktu.
- **Jangan pakai `NOPASSWD`** untuk user yang sama. `install.sh` menolak jalan kalau menemukannya.
- Jangan pernah mengetik password sudo ke dalam chat Claude.
- Service yang jalan sebagai user kamu sebaiknya memakai `NoNewPrivileges=yes` di unit systemd-nya, supaya tidak bisa memakai jendela sudo.

## Uninstall

```bash
cd ~/akses-sudo-claude
./uninstall.sh      # tambahkan -y untuk melewati konfirmasi
```

Yang dihapus: file sudoers, alias di `~/.bashrc`, aturan sudo di `settings.json`, dan bagian `## sudo` di `CLAUDE.md`. Isi lain di file-file itu tetap, dan setiap file yang diubah di-backup ke `<file>.bak-<waktu>`. Restart Claude Code setelahnya.

## Dokumen lain

- [docs/instalasi-manual.md](docs/instalasi-manual.md): langkah yang sama tanpa script, untuk memahami atau memasang sebagian saja
- [docs/distro.md](docs/distro.md): Debian (sudo belum terpasang, `visudo` tidak di PATH), Ubuntu 25.10+ (sudo-rs), image cloud dengan NOPASSWD
- [docs/troubleshooting.md](docs/troubleshooting.md): masalah yang pernah ditemui dan solusinya

---

<sub>Dites di Ubuntu 24.04 dan Debian 13, Oktober 2026.</sub>
