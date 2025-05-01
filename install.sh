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

# 2. Inisialisasi Proyek Foundry dengan Flag --force
echo "📂 Memeriksa keberadaan file 'foundry.toml'..."
if [ ! -f "foundry.toml" ]; then
    echo "⚠️  File 'foundry.toml' tidak ditemukan. Menginisialisasi proyek Foundry..."
    forge init --force || { echo "❌ Error: Gagal menginisialisasi proyek Foundry."; exit 1; }
    echo "✅ Inisialisasi proyek Foundry berhasil (dengan --force)."
else
    echo "✅ File 'foundry.toml' ditemukan. Melewatkan inisialisasi proyek Foundry."
fi

# 3. Tambahkan Kontrak Pintar
echo "📜 Menambahkan file kontrak pintar..."
mkdir -p src/vlayer
cat <<'EOT' > src/vlayer/ClickGameProver.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Proof} from "vlayer-0.1.0/Proof.sol";
import {Prover} from "vlayer-0.1.0/Prover.sol";

contract ClickGameProver is Prover {
    mapping(address => uint256) public clicks;

    event ClickVerified(address indexed user, uint256 totalClicks);

    function main(address user, uint256 clickCount) external view returns (Proof memory, uint256) {
        uint256 recordedClicks = clicks[user];
        require(clickCount >= recordedClicks, "Invalid click count");
        return (proof(), clickCount);
    }

    function recordClick(address user, uint256 clickCount) external {
        require(clickCount > clicks[user], "New click count must be greater");
        clicks[user] = clickCount;
        emit ClickVerified(user, clickCount);
    }
}
EOT

cat <<'EOT' > src/vlayer/ClickGameVerifier.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Verifier} from "vlayer-0.1.0/Verifier.sol";

contract ClickGameVerifier is Verifier {
    address public prover;

    constructor(address _prover) {
        prover = _prover;
    }

    function verify(Proof calldata proof, address user, uint256 clickCount)
        public
        onlyVerified(prover, ClickGameProver.main.selector)
    {
        require(clickCount > 0, "Click count must be greater than zero");
    }
}
EOT

# 4. Build Kontrak Pintar
echo "🔨 Membuild kontrak pintar..."
forge build || { echo "❌ Error: Gagal membuild kontrak pintar."; exit 1; }

# 5. Konfigurasi Testnet
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

# 6. Install Dependensi Typescript
echo "📦 Menginstal dependensi Typescript di folder VLayer..."
cd vlayer
bun install || { echo "❌ Error: Gagal menginstal dependensi Typescript."; exit 1; }
cd ..

# 7. Deploy Kontrak ke Testnet
echo "🚀 Deploying kontrak ke testnet..."
cd vlayer
bun run deploy:testnet || { echo "❌ Error: Gagal mendepoloy kontrak."; exit 1; }
cd ..
echo "✅ Kontrak berhasil dideploy ke testnet."

# 8. Jalankan Frontend
echo "🌍 Menjalankan aplikasi frontend..."
cd vlayer
bun run web:dev
