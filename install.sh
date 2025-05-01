#!/bin/bash

# Menghentikan skrip jika terjadi error
set -e

echo "🚀 Memulai instalasi, deploy, dan menjalankan Game Klik On-Chain dengan VLayer..."

# 1. Cek dan Instal Prasyarat
echo "🔍 Memeriksa prasyarat..."
if ! command -v git &> /dev/null; then
    echo "❌ Git tidak ditemukan. Menginstal Git..."
    sudo apt-get update
    sudo apt-get install -y git
fi

if ! command -v curl &> /dev/null; then
    echo "❌ Curl tidak ditemukan. Menginstal Curl..."
    sudo apt-get install -y curl
fi

if ! command -v bun &> /dev/null; then
    echo "❌ Bun tidak ditemukan. Menginstal Bun..."
    curl -fsSL https://bun.sh/install | bash
    source ~/.bashrc
    echo "✅ Bun berhasil diinstal."
fi

if ! command -v forge &> /dev/null; then
    echo "❌ Forge tidak ditemukan. Menginstal Forge..."
    curl -L https://foundry.paradigm.xyz | bash
    source ~/.bashrc
    foundryup
    echo "✅ Forge berhasil diinstal."
fi

if ! command -v vlayer &> /dev/null; then
    echo "❌ VLayer CLI tidak ditemukan. Menginstal VLayer CLI..."
    curl -SL https://install.vlayer.xyz | bash

    # Muat ulang shell agar PATH diperbarui
    echo "🔄 Memuat ulang konfigurasi shell..."
    source ~/.bashrc

    # Jalankan vlayerup untuk memasang vlayer
    if command -v vlayerup &> /dev/null; then
        echo "✅ vlayerup ditemukan. Menjalankan instalasi VLayer..."
        vlayerup
    else
        echo "❌ Error: vlayerup tidak ditemukan setelah instalasi. Periksa kembali instalasi VLayer CLI."
        exit 1
    fi

    echo "✅ VLayer CLI berhasil diinstal."
fi

# 2. Inisialisasi Proyek VLayer
echo "📂 Memeriksa atau menginisialisasi proyek VLayer..."
if [ ! -f "foundry.toml" ]; then
    echo "⚠️  File 'foundry.toml' tidak ditemukan. Menjalankan 'vlayer init --existing'..."
    vlayer init --existing || { echo "❌ Error: Gagal menginisialisasi proyek VLayer."; exit 1; }
    echo "✅ Inisialisasi proyek VLayer selesai."
else
    echo "✅ File 'foundry.toml' ditemukan. Melewatkan inisialisasi proyek."
fi

# 3. Build Kontrak Pintar
echo "🔨 Membuild kontrak pintar..."
forge build || { echo "❌ Error: Gagal membuild kontrak pintar."; exit 1; }

# 4. Konfigurasi Testnet
echo "⚙️ Mengkonfigurasi Testnet..."

# Meminta input pengguna untuk token JWT dan private key
read -p "Masukkan JWT Token Anda: " JWT_TOKEN
while [[ -z "$JWT_TOKEN" ]]; do
    echo "❌ JWT Token tidak boleh kosong."
    read -p "Masukkan JWT Token Anda: " JWT_TOKEN
done

read -p "Masukkan Private Key Anda (format 0x...): " PRIVATE_KEY
while [[ -z "$PRIVATE_KEY" ]]; do
    echo "❌ Private Key tidak boleh kosong."
    read -p "Masukkan Private Key Anda (format 0x...): " PRIVATE_KEY
done

mkdir -p vlayer
cat <<EOT > vlayer/.env.testnet.local
VLAYER_API_TOKEN=$JWT_TOKEN
EXAMPLES_TEST_PRIVATE_KEY=$PRIVATE_KEY
CHAIN_NAME=optimismSepolia
JSON_RPC_URL=https://sepolia.optimism.io
EOT
echo "✅ Konfigurasi testnet selesai."

# 5. Install Dependensi Typescript
echo "📦 Menginstal dependensi Typescript di folder VLayer..."
cd vlayer
bun install || { echo "❌ Error: Gagal menginstal dependensi Typescript."; exit 1; }
cd ..

# 6. Deploy Kontrak ke Testnet
echo "🚀 Deploying kontrak ke testnet..."
cd vlayer
bun run deploy:testnet || { echo "❌ Error: Gagal mendepoloy kontrak."; exit 1; }
cd ..
echo "✅ Kontrak berhasil dideploy ke testnet."

# 7. Menjalankan Aplikasi Frontend
echo "🌍 Menjalankan aplikasi frontend..."
cd vlayer
bun run web:dev || { echo "❌ Error: Gagal menjalankan aplikasi frontend."; exit 1; }
