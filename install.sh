#!/bin/bash

# Menghentikan skrip jika terjadi error
set -e

echo "🚀 Memulai instalasi, inisiasi, deploy, dan menjalankan Game Klik On-Chain dengan VLayer..."

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
echo "📂 Menginisialisasi proyek VLayer..."
mkdir -p game-click-onchain && cd game-click-onchain
if [ ! -f "foundry.toml" ]; then
    echo "🔧 File foundry.toml tidak ditemukan. Menjalankan forge init..."
    forge init || { echo "❌ Error: Gagal menginisialisasi proyek Foundry."; exit 1; }
fi
vlayer init --existing || { echo "❌ Error: Gagal menginisialisasi proyek VLayer."; exit 1; }
echo "✅ Inisialisasi proyek VLayer selesai."

# 3. Build Kontrak Pintar
echo "🔨 Membuild kontrak pintar..."
forge build || { echo "❌ Error: Gagal membuild kontrak pintar."; exit 1; }
echo "✅ Build kontrak selesai."

# 4. Konfigurasi Testnet
echo "⚙️ Mengkonfigurasi Testnet..."

# Meminta pengguna untuk memasukkan Private Key dan API Token hingga valid
while true; do
    read -p "Masukkan API Token JWT Anda: " API_TOKEN
    if [[ -z "$API_TOKEN" ]]; then
        echo "❌ API Token tidak boleh kosong. Silakan coba lagi."
    else
        break
    fi
done

while true; do
    read -p "Masukkan Private Key Anda (format 0x...): " PRIVATE_KEY
    if [[ -z "$PRIVATE_KEY" ]]; then
        echo "❌ Private Key tidak boleh kosong. Silakan coba lagi."
    else
        break
    fi
done

mkdir -p vlayer
cat <<EOT > vlayer/.env.testnet.local
VLAYER_API_TOKEN=$API_TOKEN
EXAMPLES_TEST_PRIVATE_KEY=$PRIVATE_KEY
CHAIN_NAME=optimismSepolia
JSON_RPC_URL=https://sepolia.optimism.io
EOT
echo "✅ Konfigurasi testnet selesai dengan API Token dan Private Key yang dimasukkan."

# 5. Install Dependensi Typescript
echo "📦 Menginstal dependensi Typescript di folder VLayer..."
cd vlayer
bun install || { echo "❌ Error: Gagal menginstal dependensi Typescript."; exit 1; }
cd ..

# 6. Deploy Kontrak ke Testnet
echo "🚀 Deploying kontrak ke testnet..."
cd vlayer
if ! bun run deploy:testnet; then
    echo "❌ Error: Gagal mendepoloy kontrak ke testnet."
    exit 1
fi
cd ..
echo "✅ Kontrak berhasil dideploy ke testnet."

# 7. Menyiapkan Frontend
echo "🌍 Menyiapkan aplikasi frontend..."
mkdir -p vlayer/frontend
cat <<EOF > vlayer/frontend/index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Game Klik On-Chain</title>
</head>
<body>
    <h1>Game Klik On-Chain</h1>
    <button id="connectWallet">Connect Wallet</button>
    <div id="walletInfo"></div>
    <script type="module" src="./script.js"></script>
</body>
</html>
EOF

cat <<EOF > vlayer/frontend/script.js
import { ethers } from "ethers";

async function connectWallet() {
    if (typeof window.ethereum !== "undefined") {
        try {
            const provider = new ethers.providers.Web3Provider(window.ethereum);
            await provider.send("eth_requestAccounts", []); // Meminta akses ke wallet
            const signer = provider.getSigner();
            console.log("Wallet connected:", await signer.getAddress());
            document.getElementById("walletInfo").innerText = "Wallet: " + await signer.getAddress();
        } catch (error) {
            console.error("Error connecting to wallet:", error);
        }
    } else {
        alert("MetaMask is not installed. Please install it to use this app.");
    }
}

document.getElementById("connectWallet").addEventListener("click", connectWallet);
EOF
echo "✅ Aplikasi frontend berhasil disiapkan."

# 8. Menjalankan Aplikasi Frontend
echo "🌍 Menjalankan aplikasi frontend..."
cd vlayer
bun run web:dev || { echo "❌ Error: Gagal menjalankan aplikasi frontend."; exit 1; }
