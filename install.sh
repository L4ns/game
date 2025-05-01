#!/bin/bash

# Menghentikan skrip jika terjadi error
set -e

echo "🚀 Memulai instalasi, konfigurasi, dan menjalankan proyek Foundry dengan VLayer..."

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
else
    echo "✅ Forge sudah terinstal."
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
else
    echo "✅ VLayer CLI sudah terinstal."
fi

# 2. Inisialisasi Proyek Foundry
echo "📂 Menginisialisasi proyek Foundry..."
PROJECT_NAME="game-click-onchain"
if [ ! -d "$PROJECT_NAME" ]; then
    mkdir -p $PROJECT_NAME && cd $PROJECT_NAME
    forge init || { echo "❌ Error: Gagal menginisialisasi proyek Foundry."; exit 1; }
    echo "✅ Proyek Foundry berhasil diinisialisasi."
else
    echo "⚠️  Direktori '$PROJECT_NAME' sudah ada. Menggunakan direktori yang ada."
    cd $PROJECT_NAME
fi

# 3. Membuat Struktur Direktori
echo "📁 Membuat struktur direktori yang sesuai..."
mkdir -p src/vlayer          # Untuk kontrak VLayer
mkdir -p vlayer              # Untuk konfigurasi dan skrip deployment
echo "✅ Struktur direktori berhasil dibuat."

# 4. Menambahkan File Kontrak Pintar
echo "📜 Menambahkan file kontrak pintar..."
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
echo "✅ File kontrak pintar berhasil ditambahkan."

# 5. Menambahkan Remappings dan Menginstal Dependensi
echo "🔗 Menambahkan remappings dan menginstal dependensi Solidity..."
echo "vlayer-0.1.0/=lib/vlayer-0.1.0/src/" > remappings.txt
forge install vlayer/vlayer-0.1.0 || { echo "❌ Error: Gagal mengunduh dependensi vlayer-0.1.0."; exit 1; }
echo "✅ Remappings ditambahkan dan dependensi berhasil diunduh."

# 6. Membuat File Konfigurasi Deployment
echo "⚙️ Membuat file konfigurasi deployment..."
cat <<EOT > vlayer/.env.testnet.local
VLAYER_API_TOKEN=<MASUKKAN_JWT_TOKEN_ANDA>
EXAMPLES_TEST_PRIVATE_KEY=<MASUKKAN_PRIVATE_KEY_ANDA>
CHAIN_NAME=optimismSepolia
JSON_RPC_URL=https://sepolia.optimism.io
EOT
echo "✅ File konfigurasi deployment berhasil dibuat. Pastikan untuk mengganti <MASUKKAN_JWT_TOKEN_ANDA> dan <MASUKKAN_PRIVATE_KEY_ANDA> dengan nilai yang valid."

# 7. Build Kontrak Pintar
echo "🔨 Membuild kontrak pintar..."
forge build || { echo "❌ Error: Gagal membuild kontrak pintar."; exit 1; }

# 8. Install Dependensi Typescript
echo "📦 Menginstal dependensi Typescript di folder VLayer..."
cd vlayer
bun install || { echo "❌ Error: Gagal menginstal dependensi Typescript."; exit 1; }
cd ..

# 9. Deploy Kontrak ke Testnet
echo "🚀 Deploying kontrak ke testnet..."
cd vlayer
bun run deploy:testnet || { echo "❌ Error: Gagal mendepoloy kontrak."; exit 1; }
cd ..
echo "✅ Kontrak berhasil dideploy ke testnet."

# 10. Menjalankan Frontend
echo "🌍 Menjalankan aplikasi frontend..."
cd vlayer
bun run web:dev || { echo "❌ Error: Gagal menjalankan aplikasi frontend."; exit 1; }
