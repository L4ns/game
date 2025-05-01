#!/bin/bash

# Menghentikan skrip jika ada error
set -e

# Fungsi untuk meminta input pengguna dengan validasi
function prompt_input() {
    local variable_name=$1
    local prompt_message=$2
    local input_value=""
    while [[ -z "$input_value" ]]; do
        read -p "$prompt_message: " input_value
        if [[ -z "$input_value" ]]; then
            echo "❌ $variable_name tidak boleh kosong. Silakan coba lagi."
        fi
    done
    echo "$input_value"
}

# Meminta API Token dan Private Key dari pengguna
echo "⚙️  Konfigurasi Deployment"
API_TOKEN=$(prompt_input "API Token" "Masukkan API Token JWT Anda")
PRIVATE_KEY=$(prompt_input "Private Key" "Masukkan Private Key Anda (format 0x...)")

# Menggunakan nilai default untuk RPC URL dan Chain ID
RPC_URL="https://sepolia.optimism.io"
CHAIN_ID=11155111

# Menampilkan konfigurasi yang digunakan
echo "✅ Konfigurasi berhasil diterima:"
echo "API Token: $API_TOKEN"
echo "Private Key: $PRIVATE_KEY"
echo "RPC URL: $RPC_URL (Default)"
echo "Chain ID: $CHAIN_ID (Default)"

# 1. Inisialisasi Proyek Foundry
if [ ! -f "foundry.toml" ]; then
    echo "📂 Menginisialisasi proyek Foundry..."
    forge init --force || { echo "❌ Error: Gagal menginisialisasi proyek Foundry."; exit 1; }
    echo "✅ Proyek Foundry berhasil diinisialisasi."
else
    echo "🔄 Proyek Foundry sudah ada. Melewatkan langkah inisialisasi."
fi

# 2. Kompilasi Kontrak
echo "🔨 Membuild kontrak pintar..."
forge build || { echo "❌ Error: Gagal membuild kontrak pintar."; exit 1; }
echo "✅ Build kontrak selesai."

# 3. Buat atau Perbarui File .env untuk Konfigurasi Jaringan
echo "⚙️ Mengkonfigurasi jaringan..."
cat <<EOT > .env
PRIVATE_KEY=$PRIVATE_KEY
RPC_URL=$RPC_URL
CHAIN_ID=$CHAIN_ID
EOT
echo "✅ File .env berhasil dibuat atau diperbarui."

# 4. Tambahkan Skrip Deployment (Jika Belum Ada)
if [ ! -f "script/Deploy.s.sol" ]; then
    echo "📜 Menambahkan skrip deployment ke folder script/..."
    mkdir -p script
    cat <<EOF > script/Deploy.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/MyContract.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        new MyContract("Hello, Foundry!");
        vm.stopBroadcast();
    }
}
EOF
    echo "✅ Skrip deployment berhasil dibuat."
fi

# 5. Deploy ke Testnet
echo "🚀 Deploying kontrak ke jaringan..."
forge script script/Deploy.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --chain-id $CHAIN_ID --broadcast || { echo "❌ Error: Gagal mendepoloy kontrak."; exit 1; }
echo "✅ Kontrak berhasil dideploy ke jaringan."

# 6. Verifikasi Kontrak (Opsional)
echo "⚠️  Apakah Anda ingin memverifikasi kontrak di explorer? (y/n)"
read -p "Pilihan: " VERIFY_CHOICE
if [[ "$VERIFY_CHOICE" == "y" || "$VERIFY_CHOICE" == "Y" ]]; then
    CONTRACT_ADDRESS=$(prompt_input "Contract Address" "Masukkan alamat kontrak yang telah dideploy")
    COMPILER_VERSION=$(prompt_input "Compiler Version" "Masukkan versi compiler (contoh: v0.8.20+commit.a1b79de6)")
    forge verify-contract --chain-id $CHAIN_ID --compiler-version $COMPILER_VERSION $CONTRACT_ADDRESS script/Deploy.s.sol || {
        echo "❌ Error: Gagal memverifikasi kontrak.";
        exit 1;
    }
    echo "✅ Kontrak berhasil diverifikasi."
else
    echo "⏩ Melewatkan verifikasi kontrak."
fi

echo "🎉 Deployment selesai!"
