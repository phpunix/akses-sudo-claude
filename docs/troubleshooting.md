# Troubleshooting

Mulai dari `./check.sh`. Script ini menunjukkan bagian mana yang belum benar. Jalankan `sudo-on` dulu supaya bagian root ikut dicek.

<details>
<summary><b><code>sudo -n</code> dari Claude tetap minta password padahal sudah <code>sudo-on</code></b></summary>

- Cek aturan aktif: `sudo -l | grep -i timestamp` harus berisi `timestamp_type=global`.
- `sudo visudo -c` harus menampilkan `<user>-sudo-window: parsed OK`.
- Nama file di `/etc/sudoers.d/` tidak boleh mengandung titik (`.`) atau diakhiri `~`.
- Jendela 15 menit mungkin sudah habis. Jalankan `sudo-on` lagi.
- Pastikan sudo-nya GNU sudo, bukan sudo-rs: `sudo -V | head -1`. Lihat [distro.md](distro.md#ubuntu-2510--2604-sudo-rs).

</details>

<details>
<summary><b>Langsung setelah instalasi, sudo minta password lagi</b></summary>

Normal. Cache password sebelumnya tercatat per terminal, sedangkan setelah file sudoers terpasang sudo memakai cache global yang masih kosong. Jalankan `sudo-on` sekali.

</details>

<details>
<summary><b>Claude tidak meminta persetujuan untuk <code>sudo</code></b></summary>

- Cek mode izin Claude Code di bagian bawah layar. Di auto mode atau `bypassPermissions`, prompt dilewati. Ganti ke mode default dengan Shift+Tab.
- `./check.sh` memberi peringatan kalau ada aturan `allow` untuk sudo atau `defaultMode` yang melewati prompt.
- Cek juga aturan `allow` di `.claude/settings.json` dan `.claude/settings.local.json` milik proyek yang sedang dibuka.
- Kalau Claude menjalankan script yang memanggil sudo di dalamnya, prompt yang muncul adalah untuk script itu, bukan untuk sudo.
- Restart Claude Code setelah mengubah `settings.json`.

</details>

<details>
<summary><b>Perintah yang seharusnya ditolak <code>deny</code> malah memunculkan prompt</b></summary>

- `deny` mencocokkan awalan perintah. Bentuk yang tidak ada di daftar (misalnya `sudo -n rm --recursive --force`) akan jatuh ke prompt `ask`. Pilih **No**.
- Restart Claude Code supaya daftar `deny` terbaru terbaca.

</details>

<details>
<summary><b>Claude masih memakai <code>sudo -A</code> atau askpass</b></summary>

- Cari instruksi lama: `grep -rn "sudo -A\|SUDO_ASKPASS" ~/.claude/CLAUDE.md ~/.claude/projects/*/memory/ $(find ~ -name CLAUDE.md 2>/dev/null)`
- Hapus `export SUDO_ASKPASS=...` dari `~/.bashrc` (`install.sh` memberi peringatan kalau masih ada), lalu `unset SUDO_ASKPASS`.
- Mulai sesi Claude baru.

</details>

<details>
<summary><b><code>sudo-on: command not found</code></b></summary>

- Alias belum dimuat: `source ~/.bashrc` atau buka terminal baru.
- `! sudo-on` di dalam Claude Code memang tidak bisa (tidak ada TTY, dan alias tidak dikenali di shell non-interaktif). Jalankan di terminal sungguhan.

</details>

<details>
<summary><b>Belum yakin Claude Code sudah terpasang dan login sebelum menjawab <code>yes</code></b></summary>

- **Cek:** `claude auth status --text`. Kalau `claude: command not found`, jalankan `export PATH="$HOME/.local/bin:$PATH"` lalu cek lagi.
- **Belum terpasang:** `curl -fsSL https://claude.ai/install.sh | bash`.
- **Belum login:** jalankan `claude`, buka URL yang ditampilkan di browser PC, login, tempel kodenya kembali ke terminal, lalu `/exit`.
- Kalau terlanjur menjawab selain `yes`, tidak ada yang berubah. Cukup jalankan `./install.sh` lagi.

</details>

<details>
<summary><b><code>install.sh</code> berhenti dengan "punya aturan NOPASSWD"</b></summary>

User kamu bisa sudo tanpa password, jadi jendela sudo tidak ada artinya. Lihat [distro.md](distro.md#image-cloud-dengan-nopasswd).

</details>

<details>
<summary><b><code>bad interpreter</code> atau <code>$'\r': command not found</code></b></summary>

File tersimpan dengan baris CRLF, biasanya setelah diedit atau disalin lewat Windows. Perbaiki dengan `sed -i 's/\r$//' *.sh lib/*.sh files/*`. Repo ini memakai `.gitattributes` untuk memaksa LF saat di-clone lewat git.

</details>
