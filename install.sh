#!/bin/bash

set -e

echo "🚀 Memulai instalasi, inisiasi, dan menjalankan Game Klik On-Chain dengan VLayer..."

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
    echo "🔄 Memuat ulang konfigurasi shell..."
    source ~/.bashrc
    if command -v vlayerup &> /dev/null; then
        echo "✅ vlayerup ditemukan. Menjalankan instalasi VLayer..."
        vlayerup
    else
        echo "❌ Error: vlayerup tidak ditemukan setelah instalasi. Periksa kembali instalasi VLayer CLI."
        exit 1
    fi
    echo "✅ VLayer CLI berhasil diinstal."
fi

# 2. Inisialisasi Proyek
echo "📂 Menginisialisasi proyek Foundry dan VLayer..."
mkdir -p game-click-onchain && cd game-click-onchain
if [ ! -f "foundry.toml" ]; then
    echo "🔧 File foundry.toml tidak ditemukan. Menjalankan forge init..."
    forge init || { echo "❌ Error: Gagal menginisialisasi proyek Foundry."; exit 1; }
fi
vlayer init --existing || { echo "❌ Error: Gagal menginisialisasi proyek VLayer."; exit 1; }
echo "✅ Inisialisasi proyek selesai."

# 3. Build Kontrak Pintar
echo "🔨 Membuild kontrak pintar..."
forge build || { echo "❌ Error: Gagal membuild kontrak pintar."; exit 1; }
echo "✅ Build kontrak selesai."

# 4. Konfigurasi Testnet (Mengikuti Dokumentasi VLayer)
echo "⚙️ Mengkonfigurasi Testnet dan menyimpan ke vlayer/.env.testnet.local ..."

VLAYER_API_TOKEN=""
EXAMPLES_TEST_PRIVATE_KEY=""

while [[ -z "$VLAYER_API_TOKEN" || -z "$EXAMPLES_TEST_PRIVATE_KEY" ]]; do
    echo ""
    echo "Silakan pilih input yang ingin Anda masukkan:"
    echo "  [1] Isi / ubah VLayer API Token"
    echo "  [2] Isi / ubah Private Key"
    echo "  [3] Lanjut jika sudah selesai"
    read -p "Masukkan pilihan [1/2/3]: " PILIHAN

    case $PILIHAN in
        1)
            read -p "Masukkan JWT API Token VLayer Anda (hanya valid 1 tahun): " VLAYER_API_TOKEN
            if [[ -z "$VLAYER_API_TOKEN" ]]; then
                echo "❌ API Token tidak boleh kosong!"
            fi
            ;;
        2)
            read -p "Masukkan Private Key (format 0x...): " EXAMPLES_TEST_PRIVATE_KEY
            if [[ -z "$EXAMPLES_TEST_PRIVATE_KEY" ]]; then
                echo "❌ Private Key tidak boleh kosong!"
            fi
            ;;
        3)
            if [[ -z "$VLAYER_API_TOKEN" ]]; then
                echo "❌ API Token masih kosong!"
            fi
            if [[ -z "$EXAMPLES_TEST_PRIVATE_KEY" ]]; then
                echo "❌ Private Key masih kosong!"
            fi
            ;;
        *)
            echo "Pilihan tidak valid. Silakan pilih 1, 2, atau 3."
            ;;
    esac

    # Jika user memilih lanjut (3) dan semua input sudah terisi, keluar loop
    if [[ $PILIHAN == 3 && -n "$VLAYER_API_TOKEN" && -n "$EXAMPLES_TEST_PRIVATE_KEY" ]]; then
        break
    fi
done

DEFAULT_CHAIN_NAME="optimismSepolia"
DEFAULT_RPC_URL="https://sepolia.optimism.io"

echo "Pengaturan jaringan default:"
echo "  CHAIN_NAME    : $DEFAULT_CHAIN_NAME"
echo "  JSON_RPC_URL  : $DEFAULT_RPC_URL"
read -p "Gunakan jaringan default di atas? [Y/n]: " JAWAB

if [[ "$JAWAB" =~ ^[Nn]$ ]]; then
    read -p "Masukkan CHAIN_NAME (misal: baseSepolia): " CHAIN_NAME
    read -p "Masukkan JSON_RPC_URL (misal: https://sepolia.base.org): " JSON_RPC_URL
else
    CHAIN_NAME="$DEFAULT_CHAIN_NAME"
    JSON_RPC_URL="$DEFAULT_RPC_URL"
fi

mkdir -p vlayer
cat <<EOT > vlayer/.env.testnet.local
VLAYER_API_TOKEN=$VLAYER_API_TOKEN
EXAMPLES_TEST_PRIVATE_KEY=$EXAMPLES_TEST_PRIVATE_KEY
CHAIN_NAME=$CHAIN_NAME
JSON_RPC_URL=$JSON_RPC_URL
EOT
echo "✅ Konfigurasi testnet selesai dengan API Token, Private Key, dan jaringan yang dipilih."

echo ""
echo "📢 Selanjutnya, dari dalam folder vlayer, jalankan:"
echo "    bun install"
echo "    bun run prove:testnet"
echo ""
echo "Catatan: JWT token berlaku 1 tahun, setelah itu Anda harus generate ulang token baru."
echo ""

# 5. (Opsional) Setup Frontend
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
            await provider.send("eth_requestAccounts", []);
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

echo ""
echo "🚀 Untuk mengembangkan frontend, jalankan:"
echo "    cd vlayer"
echo "    bun run web:dev"
