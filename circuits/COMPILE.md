# BeTrueCore — ZK Identity: Compile & Deploy Guide

**Circuit version:** 0.1 — MVP  
**Author:** Farman Guliyev (Safarnur) · github.com/Dede-Qorqud/BeTrueCore

---

## Структура файлов

```
betruecore-zk/
├── circuits/
│   ├── NINCommitment.circom       — Registration: NIN → commitment
│   ├── NINIdentityProof.circom    — Voting:       membership + nullifier
│   └── lib/
│       └── BinaryMerkleTree.circom — Merkle tree helper
└── contracts/
    └── NINNullifierRegistry.sol   — On-chain registry + verifier interface
```

---

## Шаг 1 — Установка зависимостей

```bash
# Node.js 20 LTS required
npm init -y
npm install circomlib snarkjs
npm install --save-dev hardhat @nomicfoundation/hardhat-toolbox
```

---

## Шаг 2 — Компиляция схемы NINIdentityProof

```bash
# Компилируем схему → R1CS + WASM + SYM
# -l node_modules: указываем путь к circomlib
circom circuits/NINIdentityProof.circom \
  --r1cs \
  --wasm \
  --sym \
  -l node_modules \
  -o build/

# Проверяем количество ограничений (constraints)
# Ожидаемо: ~5,000–8,000 для LEVELS=20
snarkjs r1cs info build/NINIdentityProof.r1cs
```

**Для пилота (50–100 участников)** — заменить в `NINIdentityProof.circom`:
```circom
// Строка в конце файла:
component main {public [merkle_root, external_nullifier]} = NINIdentityProof(7);
//                                                                             ↑
//                                                               LEVELS=7 для пилота
```
Это сократит количество constraints и ускорит proof generation на клиенте.

---

## Шаг 3 — Trusted Setup (Powers of Tau)

Groth16 требует доверенной настройки. Для тестнета/пилота используем
готовые файлы от Hermez (публичная церемония, ~100M участников).

```bash
# Скачать готовый ptau файл (Hermez BN254, достаточно для пилота)
curl -L https://hermez.s3-eu-west-1.amazonaws.com/powersOfTau28_hez_final_15.ptau \
     -o pot15_final.ptau

# Phase 2 setup — специфично для нашей схемы
snarkjs groth16 setup \
  build/NINIdentityProof.r1cs \
  pot15_final.ptau \
  keys/NINIdentityProof_0000.zkey

# Добавить contribution (обязательно — иначе setup небезопасен)
snarkjs zkey contribute \
  keys/NINIdentityProof_0000.zkey \
  keys/NINIdentityProof_0001.zkey \
  --name="BeTrueCore MVP contribution" \
  -v

# Экспорт финального ключа верификации
snarkjs zkey export verificationkey \
  keys/NINIdentityProof_0001.zkey \
  keys/verification_key.json
```

> **Важно для продакшна:** Phase 2 ceremony должна быть публичной с несколькими
> участниками. Для MVP/тестнета одного contribution достаточно.

---

## Шаг 4 — Генерация Verifier.sol

```bash
# snarkjs генерирует Solidity-контракт верификатора автоматически
snarkjs zkey export solidityverifier \
  keys/NINIdentityProof_0001.zkey \
  contracts/Verifier.sol
```

Этот файл — `contracts/Verifier.sol` — реализует `IGroth16Verifier`
из `NINNullifierRegistry.sol`. Деплоить первым.

---

## Шаг 5 — Тестовое доказательство (локально)

```javascript
// test/identity_proof_test.js
const { groth16 } = require("snarkjs");
const { poseidon } = require("circomlib");

async function testProof() {
  // Тестовые данные (не реальный NIN)
  const nin_preimage    = BigInt("1234567");         // encode("AZE1234") → BigInt
  const registration_salt = BigInt("0x" + require("crypto").randomBytes(31).toString("hex"));
  const identity_secret   = BigInt("0x" + require("crypto").randomBytes(31).toString("hex"));

  // Вычислить commitment
  const nin_key    = poseidon([nin_preimage, registration_salt]);
  const commitment = poseidon([nin_key, identity_secret]);

  // Merkle tree (для теста: дерево из одного листа)
  const path_elements = new Array(20).fill(BigInt(0));
  const path_indices  = new Array(20).fill(0);
  const merkle_root   = commitment; // дерево из 1 участника

  const session_id    = BigInt(1); // external_nullifier

  const input = {
    nin_preimage:      nin_preimage.toString(),
    registration_salt: registration_salt.toString(),
    identity_secret:   identity_secret.toString(),
    path_elements:     path_elements.map(x => x.toString()),
    path_indices:      path_indices,
    merkle_root:       merkle_root.toString(),
    external_nullifier: session_id.toString(),
  };

  const { proof, publicSignals } = await groth16.fullProve(
    input,
    "build/NINIdentityProof_js/NINIdentityProof.wasm",
    "keys/NINIdentityProof_0001.zkey"
  );

  console.log("✓ Nullifier:", publicSignals[2]);

  const vKey = require("../keys/verification_key.json");
  const isValid = await groth16.verify(vKey, publicSignals, proof);
  console.log("✓ Proof valid:", isValid); // должно быть true
}

testProof();
```

---

## Шаг 6 — Деплой (Sepolia testnet)

```bash
# 1. Деплой Verifier.sol
npx hardhat run scripts/deploy_verifier.js --network sepolia

# 2. Деплой NINNullifierRegistry.sol
# (передать адрес Verifier.sol в конструктор)
npx hardhat run scripts/deploy_registry.js --network sepolia
```

---

## Структура ключевых сигналов

| Сигнал | Тип | Кто знает | Где хранится |
|--------|-----|-----------|-------------|
| `nin_preimage` | private | только гражданин | только устройство |
| `registration_salt` | private | только гражданин | кошелёк/localStorage |
| `identity_secret` | private | только гражданин | кошелёк/localStorage |
| `identity_commitment` | public | контракт, все | Merkle дерево |
| `nullifier` | public | контракт, все | `nullifiers[sessionId]` |
| `merkle_root` | public | все | `NINNullifierRegistry.merkleRoot` |

---

## Архитектурная связь (L0 → L1)

```
[УСТРОЙСТВО ГРАЖДАНИНА]
  NIN (raw)
    ↓ Poseidon(NIN, salt)    ← только на устройстве
  nin_key
    ↓ Poseidon(nin_key, secret)
  identity_commitment ─────────────────────→ [MERKLE TREE ON-CHAIN]
                                                      ↓
[УСТРОЙСТВО, SESSION]                         merkle_root (public)
  NINIdentityProof.circom
    ↓ Groth16 proof
  (nullifier, merkle_root, session_id) ──→ NINNullifierRegistry.sol
                                                      ↓
                                             verifyAndRegister()
                                                      ↓
                                             emit IdentityVerified
                                                      ↓
                                             Poll.sol → vote counted
```

---

*THE MIRROR REFLECTS • THE NOTARY BEARS WITNESS • THE MATRIX MEASURES*
