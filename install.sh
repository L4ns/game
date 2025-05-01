#!/bin/bash

# Script untuk instalasi lengkap Game Klik On-Chain dengan satu klik

echo "🚀 Memulai instalasi Game Klik On-Chain..."

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
fi

# 2. Instal Foundry
echo "🔧 Menginstal Foundry..."
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc
foundryup

# 3. Instal VLayer
echo "🔧 Menginstal VLayer..."
curl -SL https://install.vlayer.xyz | bash
vlayerup

# 4. Buat Direktori Proyek
echo "📂 Membuat direktori proyek..."
mkdir -p game-click-onchain && cd game-click-onchain

# 5. Tambahkan Kontrak Pintar
echo "📜 Menambahkan file kontrak pintar..."
mkdir -p contracts
cat <<EOT > contracts/ClickGameProver.sol
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

cat <<EOT > contracts/ClickGameVerifier.sol
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

# 6. Tambahkan File Frontend
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
      margin: 10px;
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
import { createVlayerClient } from "@vlayer/sdk";
import { createWalletClient } from "viem";

const vlayer = createVlayerClient();

const client = createWalletClient({
  // Tambahkan konfigurasi klien wallet Anda
});

const proverContractAddress = "ALAMAT_PROVER_CONTRACT"; // Ganti dengan alamat Prover
const verifierContractAddress = "ALAMAT_VERIFIER_CONTRACT"; // Ganti dengan alamat Verifier

let clickCount = 0;

document.getElementById("clickButton").addEventListener("click", async () => {
  try {
    clickCount++;

    const provingHash = await vlayer.prove({
      address: proverContractAddress,
      proverAbi: [], // Tambahkan ABI dari Prover
      functionName: "main",
      args: [await client.getAddress(), clickCount],
      chainId: 1,
    });

    const provingResult = await vlayer.waitForProvingResult({ hash: provingHash });

    const txHash = await client.writeContract({
      address: verifierContractAddress,
      abi: [], // Tambahkan ABI dari Verifier
      functionName: "verify",
      args: [provingResult, await client.getAddress(), clickCount],
      chain: { id: 1 },
      account: await client.getAddress(),
    });

    alert(`Click ${clickCount} verified and recorded on-chain!`);
  } catch (error) {
    console.error("Error during proving or verification:", error);
    alert("Error during proving or verification.");
  }
});

document.getElementById("connectWallet").addEventListener("click", async () => {
  try {
    const address = await client.getAddress();
    alert(`Wallet connected: ${address}`);
  } catch (error) {
    console.error("Failed to connect wallet:", error);
    alert("Failed to connect wallet.");
  }
});
EOT

# 7. Konfigurasi Testnet
echo "⚙️ Konfigurasi Testnet"
read -p "Masukkan JWT Token Anda: " JWT_TOKEN
read -p "Masukkan Private Key Anda (contoh: 0x...): " PRIVATE_KEY

mkdir -p vlayer
cat <<EOT > vlayer/.env.testnet.local
VLAYER_API_TOKEN=$JWT_TOKEN
EXAMPLES_TEST_PRIVATE_KEY=$PRIVATE_KEY
CHAIN_NAME=optimismSepolia
JSON_RPC_URL=https://sepolia.optimism.io
EOT

# 8. Jalankan Aplikasi
echo "✅ Instalasi selesai! Menjalankan aplikasi..."
cd frontend
npx live-server
