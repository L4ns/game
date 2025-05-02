#!/bin/bash
set -e

echo "🚀 Setup Game Klik On-Chain dengan VLayer (Non-Interaktif Friendly)"

# 1. Cek dan install prasyarat
echo "🔍 Memeriksa prasyarat..."
if ! command -v git &> /dev/null; then
    echo "❌ Git tidak ditemukan. Menginstal Git..."
    sudo apt-get update && sudo apt-get install -y git
fi
if ! command -v curl &> /dev/null; then
    echo "❌ Curl tidak ditemukan. Menginstal Curl..."
    sudo apt-get install -y curl
fi
if ! command -v bun &> /dev/null; then
    echo "❌ Bun tidak ditemukan. Menginstal Bun..."
    curl -fsSL https://bun.sh/install | bash
    source ~/.bashrc || true
fi
if ! command -v forge &> /dev/null; then
    echo "❌ Forge tidak ditemukan. Menginstal Forge..."
    curl -L https://foundry.paradigm.xyz | bash
    source ~/.bashrc || true
    foundryup
fi
if ! command -v vlayer &> /dev/null; then
    echo "❌ VLayer CLI tidak ditemukan. Menginstal VLayer CLI..."
    curl -SL https://install.vlayer.xyz | bash
    source ~/.bashrc || true
    if command -v vlayerup &> /dev/null; then
        vlayerup
    else
        echo "❌ Error: vlayerup tidak ditemukan setelah instalasi."
        exit 1
    fi
fi

# 2. Ambil ENV, wajib ada
if [ -z "$VLAYER_API_TOKEN" ]; then
    echo "❌ VLAYER_API_TOKEN belum diisi."
    echo "Jalankan dengan:"
    echo "  curl -sSL https://raw.githubusercontent.com/namamu/file.sh | \\"
    echo "    VLAYER_API_TOKEN=isi_tokenmu EXAMPLES_TEST_PRIVATE_KEY=isi_privkeymu bash"
    exit 1
fi
if [ -z "$EXAMPLES_TEST_PRIVATE_KEY" ]; then
    echo "❌ EXAMPLES_TEST_PRIVATE_KEY belum diisi."
    echo "Jalankan dengan:"
    echo "  curl -sSL https://raw.githubusercontent.com/namamu/file.sh | \\"
    echo "    VLAYER_API_TOKEN=isi_tokenmu EXAMPLES_TEST_PRIVATE_KEY=isi_privkeymu bash"
    exit 1
fi

DEFAULT_CHAIN_NAME="optimismSepolia"
DEFAULT_RPC_URL="https://sepolia.optimism.io"
CHAIN_NAME="${CHAIN_NAME:-$DEFAULT_CHAIN_NAME}"
JSON_RPC_URL="${JSON_RPC_URL:-$DEFAULT_RPC_URL}"

echo "📦 Data konfigurasi yang digunakan:"
echo "  VLAYER_API_TOKEN          = (disembunyikan)"
echo "  EXAMPLES_TEST_PRIVATE_KEY = (disembunyikan)"
echo "  CHAIN_NAME                = $CHAIN_NAME"
echo "  JSON_RPC_URL              = $JSON_RPC_URL"

# 3. Setup proyek
echo "📂 Menginisialisasi project Foundry dan VLayer..."
mkdir -p game-click-onchain && cd game-click-onchain

if [ ! -f "foundry.toml" ]; then
    echo "🔧 File foundry.toml tidak ditemukan. Menjalankan forge init..."
    forge init || { echo "❌ Error: Gagal inisialisasi Foundry."; exit 1; }
fi
vlayer init --existing || { echo "❌ Error: Gagal inisialisasi VLayer."; exit 1; }

echo "🔨 Membuild kontrak pintar..."
forge build || { echo "❌ Error: Gagal membuild kontrak."; exit 1; }

# 4. Buat file env
mkdir -p vlayer
cat <<EOT > vlayer/.env.testnet.local
VLAYER_API_TOKEN=$VLAYER_API_TOKEN
EXAMPLES_TEST_PRIVATE_KEY=$EXAMPLES_TEST_PRIVATE_KEY
CHAIN_NAME=$CHAIN_NAME
JSON_RPC_URL=$JSON_RPC_URL
EOT
echo "✅ File konfigurasi vlayer/.env.testnet.local selesai dibuat!"

# 5. (Opsional) Setup Frontend
echo "🌍 Menyiapkan aplikasi frontend sederhana..."
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
echo "✅ Aplikasi frontend sederhana sudah disiapkan."

# 6. Instruksi lanjut
echo
echo "✅ SEMUA BERHASIL!"
echo "Selanjutnya, dari dalam folder game-click-onchain/vlayer jalankan:"
echo "    bun install"
echo "    bun run prove:testnet"
echo
echo "Untuk frontend:"
echo "    cd game-click-onchain/vlayer"
echo "    bun run web:dev"
echo
echo "Jika ingin ganti network, tambahkan CHAIN_NAME dan JSON_RPC_URL pada perintah."
