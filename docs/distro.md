# Catatan per distro

## Ringkasan

| Distro | sudo bawaan | Yang perlu diperhatikan |
|---|---|---|
| Ubuntu 24.04 LTS | GNU sudo 1.9.15 | Tidak ada. Jalan langsung (dites) |
| Debian 13 (trixie) | GNU sudo 1.9.16p2 | Kadang sudo belum terpasang atau user belum di grup `sudo`; `visudo` tidak di PATH user (dites) |
| Ubuntu 22.04 / Debian 12 | GNU sudo 1.9.x | Seharusnya sama dengan di atas, belum dites |
| Ubuntu 25.10 / 26.04 | sudo-rs | Jendela global tidak didukung, lihat [sudo-rs](#ubuntu-2510--2604-sudo-rs) |

## Debian

### sudo belum terpasang atau user belum di grup `sudo`

Kalau saat instalasi Debian kamu mengisi password root, Debian tidak memasukkan user ke grup `sudo`, dan pada instalasi minimal paket `sudo` kadang belum ada. Perbaiki dari akun root:

```bash
su -                       # pakai "su -" (dengan strip), supaya /usr/sbin masuk PATH
apt update && apt install -y sudo
usermod -aG sudo <username>
exit
```

Lalu **logout dari SSH dan login lagi** supaya grup `sudo` aktif. Cek dengan `groups`.

### `visudo: command not found`

`visudo` ada di `/usr/sbin`, dan di Debian folder itu tidak masuk PATH user biasa. Selalu jalankan lewat sudo (`sudo visudo -c ...`), karena `secure_path` milik sudo menyertakan `/usr/sbin`. `install.sh` sudah melakukannya.

### `claude` tidak ditemukan setelah dipasang

Installer Claude Code menaruh `claude` di `~/.local/bin`. Di Debian, folder itu baru masuk PATH setelah login ulang (lewat `~/.profile`). Untuk sesi yang sedang berjalan:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

### `jq` dan `curl` belum ada

Instalasi minimal Debian sering belum menyertakan keduanya. `install.sh` memasang `jq` otomatis. `curl` dibutuhkan untuk installer Claude Code: `sudo apt install -y curl`.

## Image cloud dengan NOPASSWD

Banyak penyedia VPS dan image cloud membuat user bawaan (`ubuntu`, `debian`, `admin`) dengan `NOPASSWD:ALL` di `/etc/sudoers.d/90-cloud-init-users`. Dengan NOPASSWD, sudo tidak pernah meminta password, jadi jendela 15 menit dan `sudo-on`/`sudo-off` tidak ada artinya.

```bash
sudo -l      # bagian "may run" untuk user kamu tidak boleh berisi NOPASSWD
```

`install.sh` berhenti kalau menemukan NOPASSWD. Solusinya, buat user sendiri tanpa NOPASSWD dan pakai user itu untuk Claude Code:

```bash
sudo adduser <username>
sudo usermod -aG sudo <username>
```

Aturan `root ALL=(ALL) NOPASSWD:ALL` di file cloud-init tidak masalah, karena hanya berlaku untuk root.

## Ubuntu 25.10 / 26.04 (sudo-rs)

Mulai Ubuntu 25.10, perintah `sudo` bawaan adalah **sudo-rs** (sudo versi Rust). sudo-rs tidak mendukung `timestamp_type=global`, dan cache password-nya selalu per terminal, sehingga `sudo-on` di terminalmu tidak berlaku untuk perintah Claude. Ciri-cirinya:

```bash
sudo -V | head -1      # → "sudo-rs 0.x.y", bukan "Sudo version 1.x"
```

Pilihan:

1. **Pakai Ubuntu 24.04 LTS** (didukung sampai 2029). Paling sederhana dan sudah dites.
2. **Ganti ke GNU sudo** yang masih tersedia sebagai `sudo.ws` (belum dites di 26.04):
   ```bash
   sudo update-alternatives --config sudo   # pilih sudo.ws
   sudo -V | head -1                        # harus "Sudo version 1.9.x"
   ```
   Lalu jalankan `./install.sh` seperti biasa. Setelah upgrade distro, cek lagi apakah default-nya masih GNU sudo.

Jangan mengganti jendela global dengan `NOPASSWD`, walaupun hanya untuk perintah tertentu. Aturan NOPASSWD untuk `systemctl`, `apt`, editor, atau `cp` bisa dipakai untuk naik ke root penuh.
