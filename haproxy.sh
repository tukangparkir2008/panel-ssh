#!/bin/bash

# ===============================================
# SCRIPT UNTUK MENGINSTAL DAN MENGKONFIGURASI HAPROXY DI UBUNTU 22.04 LTS
# Menggunakan PPA HAProxy 2.8 untuk versi yang lebih baru
# Termasuk konfigurasi dasar dan dashboard statistik
# ===============================================

# Warna untuk output terminal
Green="\e[92;1m"
RED="\033[31m"
YELLOW="\033[33m"
BLUE="\033[36m"
FONT="\033[0m"
OK="${Green}--->${FONT}"
ERROR="${RED}[ERROR]${FONT}"
NC='\e[0m'

# URL Repositori untuk file konfigurasi HAProxy
# GANTI INI JIKA URL FILE CONFIGURASI ANDA BERBEDA
REPO="https://raw.githubusercontent.com/tukangparkir2008/panel-ssh/main/" 

# Fungsi untuk mencetak pesan proses instalasi
function print_install() {
    echo -e "${GREEN}===============================${FONT}"
    echo -e "${YELLOW}# $1${FONT}"
    echo -e "${GREEN}===============================${FONT}"
    sleep 1
}

# Fungsi untuk mencetak pesan sukses
function print_success() {
    if [[ 0 -eq $? ]]; then
        echo -e "${GREEN}===============================${FONT}"
        echo -e "${Green}# $1 berhasil dipasang/dikofigurasi.${FONT}"
        echo -e "${GREEN}===============================${FONT}"
        sleep 2
    fi
}

# Fungsi untuk mencetak pesan error
function print_error() {
    echo -e "${ERROR}${RED} $1${FONT}"
}

# Fungsi untuk memeriksa apakah script dijalankan sebagai root
function check_root() {
    if [[ 0 -ne "$UID" ]]; then
        print_error "Anda harus menjalankan skrip ini sebagai root. Gunakan 'sudo su' atau 'sudo ./install_haproxy.sh'."
        exit 1
    fi
}

# Panggil fungsi cek root
check_root

clear
print_install "Memulai Instalasi dan Konfigurasi HAProxy..."

# Langkah 1: Perbarui Sistem dan Instal Dependensi
print_install "Memperbarui daftar paket dan menginstal dependensi dasar..."
sudo apt update -y || { print_error "Gagal memperbarui daftar paket."; exit 1; }
sudo apt upgrade -y || { print_error "Gagal mengupgrade paket."; exit 1; }
sudo apt install -y software-properties-common curl gnupg2 || { print_error "Gagal menginstal dependensi dasar."; exit 1; }
print_success "Sistem diperbarui dan dependensi dasar terinstal."

# Langkah 2: Hapus PPA HAProxy Lama (jika ada) dan Tambahkan PPA HAProxy 2.8
# Ini akan menangani PPA 2.0 yang usang jika pernah ditambahkan.
print_install "Menghapus PPA HAProxy 2.0 (jika ada) dan menambahkan PPA HAProxy 2.8..."
sudo add-apt-repository --remove ppa:vbernat/haproxy-2.0 -y || true
sudo add-apt-repository ppa:vbernat/haproxy-2.8 -y || { print_error "Gagal menambahkan PPA HAProxy 2.8."; exit 1; }
print_success "PPA HAProxy 2.8 berhasil ditambahkan."

# Langkah 3: Perbarui Daftar Paket Setelah Menambahkan PPA Baru
print_install "Memperbarui daftar paket setelah menambahkan PPA baru..."
sudo apt update -y || { print_error "Gagal memperbarui daftar paket setelah PPA baru."; exit 1; }
print_success "Daftar paket diperbarui."

# Langkah 4: Instal HAProxy
print_install "Menginstal HAProxy..."
sudo apt install haproxy -y || { print_error "Gagal menginstal HAProxy. Periksa pesan error di atas."; exit 1; }
print_success "HAProxy berhasil diinstal."

# Langkah 5: Cadangkan Konfigurasi Asli HAProxy
print_install "Mencadangkan file konfigurasi HAProxy asli..."
sudo cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.bak || { print_error "Gagal mencadangkan konfigurasi HAProxy."; exit 1; }
print_success "Konfigurasi HAProxy asli dicadangkan ke /etc/haproxy/haproxy.cfg.bak."

# Langkah 6: Unduh dan Konfigurasi File HAProxy
print_install "Mengunduh dan mengkonfigurasi file HAProxy..."
# Mengambil nama domain dari /etc/xray/domain yang diasumsikan sudah ada dari skrip utama
if [ -f /etc/xray/domain ]; then
    domain=$(cat /etc/xray/domain)
    echo "Domain yang terdeteksi: $domain"
else
    print_error "File domain tidak ditemukan di /etc/xray/domain. Konfigurasi mungkin tidak lengkap."
    domain="your_domain.com" # Default jika tidak ditemukan, perlu diubah manual nanti
fi

# Mengunduh konfigurasi haproxy.cfg
wget -O /etc/haproxy/haproxy.cfg "${REPO}config/haproxy.cfg" || { print_error "Gagal mengunduh haproxy.cfg. Pastikan URL REPO benar."; exit 1; }

# Mengganti placeholder 'xxx' dengan nama domain
sed -i "s/xxx/${domain}/g" /etc/haproxy/haproxy.cfg || { print_error "Gagal mengganti placeholder domain di haproxy.cfg."; exit 1; }

# Menggabungkan sertifikat SSL menjadi file .pem untuk HAProxy
# Diasumsikan /etc/xray/xray.crt dan /etc/xray/xray.key sudah ada dari instalasi Xray
if [ -f /etc/xray/xray.crt ] && [ -f /etc/xray/xray.key ]; then
    cat /etc/xray/xray.crt /etc/xray/xray.key | sudo tee /etc/haproxy/hap.pem > /dev/null
    print_success "Sertifikat SSL digabungkan untuk HAProxy."
else
    print_error "Sertifikat SSL (/etc/xray/xray.crt atau /etc/xray/xray.key) tidak ditemukan. Konfigurasi HTTPS HAProxy mungkin gagal."
    echo "Silakan pastikan sertifikat SSL diinstal sebelum ini."
fi

print_success "HAProxy dikonfigurasi."

# Langkah 7: Validasi Konfigurasi HAProxy
print_install "Memvalidasi konfigurasi HAProxy..."
sudo haproxy -c -f /etc/haproxy/haproxy.cfg || { print_error "Konfigurasi HAProxy tidak valid. Periksa pesan error di atas."; exit 1; }
print_success "Konfigurasi HAProxy valid."

# Langkah 8: Aktifkan dan Mulai Ulang Layanan HAProxy
print_install "Mengaktifkan dan memulai ulang layanan HAProxy..."
sudo systemctl enable haproxy || { print_error "Gagal mengaktifkan layanan HAProxy."; exit 1; }
sudo systemctl restart haproxy || { print_error "Gagal memulai ulang layanan HAProxy."; exit 1; }
sudo systemctl status haproxy --no-pager || { print_error "HAProxy gagal berjalan. Periksa log: journalctl -u haproxy.service."; exit 1; }
print_success "HAProxy aktif dan berjalan."

# Langkah 9: Konfigurasi Firewall (UFW)
print_install "Mengatur firewall (UFW) untuk HAProxy..."
sudo apt install ufw -y # Pastikan UFW terinstal
sudo ufw enable || true # Aktifkan UFW jika belum aktif, abaikan error jika sudah aktif
sudo ufw allow 80/tcp # Izinkan HTTP
sudo ufw allow 443/tcp # Izinkan HTTPS
sudo ufw allow 8080/tcp # Izinkan port dashboard statistik HAProxy
sudo ufw reload || { print_error "Gagal memuat ulang aturan UFW."; exit 1; }
print_success "Aturan UFW untuk HAProxy diterapkan."

print_install "Instalasi dan Konfigurasi HAProxy Selesai!"
echo -e "${OK} Anda dapat memeriksa dashboard statistik HAProxy di http://${IP}:8080/haproxy_stats (sesuaikan dengan username/password di config)."
echo -e "${OK} Pastikan server backend Anda (misalnya Nginx) berjalan dengan baik."
echo -e "${OK} Untuk menguji, akses IP publik server Anda di browser: http://${IP}"
