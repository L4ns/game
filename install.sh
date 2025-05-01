#!/bin/bash

# Menghentikan skrip jika terjadi error
set -e

echo "🚀 Memulai instalasi dan deploy Game Klik On-Chain..."

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

# 2. Instal Foundry
echo "🔧 Menginstal Foundry..."
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc # Memuat ulang konfigurasi shell
if command -v foundryup &> /dev/null; then
    foundryup # Instalasi Foundry
    echo "✅ Foundry berhasil diinstal."
else
    echo "❌ Foundryup tidak ditemukan setelah instalasi. Memuat ulang shell dan mencoba lagi..."
    source ~/.bashrc
    if command -v foundryup &> /dev/null; then
        foundryup
        echo "✅ Foundry berhasil diinstal setelah memuat ulang shell."
    else
        echo "❌ Foundry masih tidak ditemukan. Pastikan PATH sudah diperbarui secara manual."
        exit 1
    fi
fi

# 3. Instal VLayer
echo "🔧 Menginstal VLayer..."
curl -SL https://install.vlayer.xyz | bash
source ~/.bashrc
if command -v vlayerup &> /dev/null; then
    vlayerup
    echo "✅ VLayer berhasil diinstal."
else
    echo "❌ VLayerup tidak ditemukan setelah instalasi. Pastikan PATH sudah diperbarui."
    exit 1
fi

# 4. Buat Direktori Proyek
echo "📂 Membuat direktori proyek..."
mkdir -p game-click-onchain && cd game-click-onchain

# 5. Tambahkan Kontrak Pintar
echo "📜 Menambahkan file kontrak pintar..."
mkdir -p contracts
cat <<'EOT' > contracts/ClickGameProver.sol
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

cat <<'EOT' > contracts/ClickGameVerifier.sol
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

# 6. Kompilasi dan Deploy Kontrak Menggunakan Foundry dan VLayer
echo "⚙️ Kompilasi dan deploy kontrak pintar..."
forge build

echo "🚀 Deploying ClickGameProver..."
CONTRACT_PROVER_ADDRESS=$(forge create contracts/ClickGameProver.sol:ClickGameProver --rpc-url $JSON_RPC_URL --private-key $EXAMPLES_TEST_PRIVATE_KEY | grep "Deployed to" | awk '{print $3}')
if [ -z "$CONTRACT_PROVER_ADDRESS" ]; then
    echo "❌ Gagal mendeply ClickGameProver."
    exit 1
fi
echo "✅ ClickGameProver berhasil dideploy di alamat: $CONTRACT_PROVER_ADDRESS"

echo "🚀 Deploying ClickGameVerifier..."
CONTRACT_VERIFIER_ADDRESS=$(forge create contracts/ClickGameVerifier.sol:ClickGameVerifier --rpc-url $JSON_RPC_URL --private-key $EXAMPLES_TEST_PRIVATE_KEY --constructor-args "$CONTRACT_PROVER_ADDRESS" | grep "Deployed to" | awk '{print $3}')
if [ -z "$CONTRACT_VERIFIER_ADDRESS" ]; then
    echo "❌ Gagal mendeply ClickGameVerifier."
    exit 1
fi
echo "✅ ClickGameVerifier berhasil dideploy di alamat: $CONTRACT_VERIFIER_ADDRESS"

# 7. Tambahkan File Frontend
echo "🌐 Menambahkan file frontend..."
mkdir -p frontend
cat <<EOT > frontend/index.html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>On-Chain Click Game</title>
  <script src="https://cdn.jsdelivr.net/npm/ethers@5.7.1/dist/ethers.umd.min.js"></script>
  <style>
    body {
      font-family: Arial, sans-serif;
      text-align: center;
      margin-top: 50px;
    }
    button {
      padding: 10px 20px;
      font-size: 1.2rem;
      cursor: pointer;
    }
    #counter {
      font-size: 2rem;
      margin: 20px;
    }
  </style>
</head>
<body>
  <h1>On-Chain Click Game</h1>
  <p>Connect your wallet and start clicking!</p>
  <button id="connectWallet">Connect Wallet</button>
  <div id="walletAddress"></div>
  <button id="clickButton" disabled>Click Me</button>
  <div id="counter">Total Clicks: 0</div>

  <script src="./script.js"></script>
</body>
</html>
EOT

cat <<EOT > frontend/script.js
const proverAddress = "$CONTRACT_PROVER_ADDRESS"; // Alamat ClickGameProver
const verifierAddress = "$CONTRACT_VERIFIER_ADDRESS"; // Alamat ClickGameVerifier
// Rest of the frontend logic remains the same
EOT

# 8. Deploy Aplikasi Frontend
echo "✅ Instalasi selesai! Menjalankan aplikasi..."
cd frontend
if command -v npx &> /dev/null; then
    npx live-server
else
    echo "❌ Live server tidak ditemukan. Pastikan Anda menginstalnya dengan 'npm install -g live-server'."
fi
