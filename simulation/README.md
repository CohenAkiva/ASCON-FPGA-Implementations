# Simulation and Functional Verification — ASCON Basic

## 1. Overview

This directory contains the VHDL testbenches and ModelSim automation scripts used to verify the ASCON Basic implementation.

The verification environment covers three main levels:

- Cryptographic core verification.
- External wrapper verification.
- Authentication and negative testing.

All five simulation suites were successfully executed on November 24, 2026, using ModelSim Intel FPGA Edition 2020.1.

## 2. Directory Structure

```text
simulation/
├── encryption/
│   ├── run_v2_full.do
│   └── tb_wrapper_v2_full.vhd
├── decryption/
│   ├── run_decrypt.do
│   ├── run_decrypt_negative.do
│   ├── run_wrapper_decrypt.do
│   ├── run_wrapper_decrypt_extra.do
│   ├── tb_ascon_decrypt_top_level.vhd
│   ├── tb_ascon_decrypt_negative.vhd
│   ├── tb_wrapper_decrypt.vhd
│   └── tb_wrapper_decrypt_extra.vhd
└── README.md
```

## 3. Simulation Requirements

- ModelSim with VHDL-2008 support.
- All RTL source files included in the Basic branch.
- ASCON Known Answer Test vector file.
- Execution from the repository root directory.

The KAT file is located at:

`verification/KAT/LWC_AEAD_KAT_128_128.txt`

No physical FPGA board or Raspberry Pi is required for these simulations.

## 4. Encryption Verification

**Testbench:** `encryption/tb_wrapper_v2_full.vhd`

**Execution script:** `encryption/run_v2_full.do`

This testbench verifies the complete encryption implementation through its external wrapper.

The verification covers:

- Key and nonce loading.
- Associated data processing.
- Plaintext encryption.
- Multi-block messages.
- Partial and full data blocks.
- Ciphertext generation.
- Authentication tag generation.
- Byte-oriented wrapper communication.

### Execution

```tcl
do simulation/encryption/run_v2_full.do
```

### Expected Result

```text
ALL 1089 V2 KAT CASES PASSED
```

## 5. Decryption Core Verification

**Testbench:** `decryption/tb_ascon_decrypt_top_level.vhd`

**Execution script:** `decryption/run_decrypt.do`

This testbench communicates directly with the authenticated decryption core, independently of the external wrapper.

It verifies:

- Associated data processing.
- Ciphertext decryption.
- Multi-block ciphertext processing.
- Partial and full data blocks.
- Plaintext correctness.
- Authentication tag verification.

The default test range includes all 1089 KAT vectors.

### Execution

```tcl
do simulation/decryption/run_decrypt.do
```

### Expected Result

```text
ALL SELECTED TEST VECTORS PASSED.
```

The selected KAT range can be modified using the following variables in the execution script:

```tcl
set FIRST_COUNT 1
set LAST_COUNT 1089
```

## 6. Authentication and Negative Testing

**Testbench:** `decryption/tb_ascon_decrypt_negative.vhd`

**Execution script:** `decryption/run_decrypt_negative.do`

This testbench verifies authentication behavior under valid and deliberately corrupted input conditions.

The execution script runs four independent fault modes, covering valid input and modifications to authentication tags, ciphertext, and associated data.

Cases requiring modification of an empty input are not applicable.

### Execution

```tcl
do simulation/decryption/run_decrypt_negative.do
```

### Expected Results

Each applicable test vector must satisfy the expected authentication behavior.

The script concludes with:

```text
All four fault-mode simulations finished.
```

The individual test results must also be inspected to confirm successful verification of every fault mode.

## 7. Decryption Wrapper Integration Tests

**Testbench:** `decryption/tb_wrapper_decrypt.vhd`

**Execution script:** `decryption/run_wrapper_decrypt.do`

This testbench verifies the interaction between the external communication interface and the decryption core.

| Test | Description |
|---|---|
| 1 | Empty ciphertext with a valid authentication tag. |
| 2 | Associated data with empty ciphertext. |
| 3 | One-byte ciphertext. |
| 4 | Full associated data block and one-byte ciphertext. |
| 5 | Full 16-byte ciphertext block. |
| 6 | Corrupted authentication tag rejected; plaintext hidden. |
| 7 | Corrupted ciphertext rejected. |
| 8 | Corrupted associated data rejected. |

### Execution

```tcl
do simulation/decryption/run_wrapper_decrypt.do
```

### Expected Result

```text
ALL 8 WRAPPER DECRYPTION TESTS COMPLETED
```

## 8. Additional Decryption Wrapper Tests

**Testbench:** `decryption/tb_wrapper_decrypt_extra.vhd`

**Execution script:** `decryption/run_wrapper_decrypt_extra.do`

This testbench focuses on boundary conditions, consecutive transactions, reset behavior, and invalid input handling.

| Test | Description |
|---|---|
| 1 | Empty message. |
| 2 | Valid 16-byte message without an intervening reset. |
| 3 | Invalid authentication tag following a valid message without reset. |
| 4 | Valid 15-byte message following an authentication failure. |
| 5 | Reset clears plaintext and status information. |
| 6 | Invalid 17-byte block is rejected. |

### Execution

```tcl
do simulation/decryption/run_wrapper_decrypt_extra.do
```

### Expected Result

```text
ALL 6 ADDITIONAL DECRYPT WRAPPER TESTS COMPLETED
```

## 9. Complete Simulation Procedure

Open ModelSim and navigate to the repository root using the Transcript console.

For example:

```tcl
cd "C:/FPGA_Projects/ASCON-FPGA-Implementations"
```

Execute the following scripts individually:

```tcl
do simulation/encryption/run_v2_full.do
do simulation/decryption/run_decrypt.do
do simulation/decryption/run_decrypt_negative.do
do simulation/decryption/run_wrapper_decrypt.do
do simulation/decryption/run_wrapper_decrypt_extra.do
```

Inspect the Transcript output after each simulation.

Before switching between encryption and decryption implementations, close the active simulation and use a clean work library or an independent simulation environment.

Both wrapper source files declare an entity named `wrapper` and must not be compiled together into the same active design.

The scripts compile the required VHDL source files in dependency order using VHDL-2008.

## 10. Verification Results

Verification date: November 24, 2026.

| Simulation Suite | Result |
|---|---|
| Encryption KAT verification | PASS — 1089 vectors |
| Decryption core KAT verification | PASS — 1089 vectors |
| Authentication and negative tests | PASS |
| Decryption wrapper integration | PASS — 8 tests |
| Additional decryption wrapper tests | PASS — 6 tests |

Overall functional simulation status: **5/5 simulation suites passed.**

These results are based on the completed ModelSim runs reported by the project author.

## 11. Verification Scope and Limitations

The decryption core supports multi-block ciphertext processing and is verified directly against the full KAT dataset.

The Basic decryption wrapper intentionally limits ciphertext messages to a maximum of 16 bytes per transaction.

Therefore, successful multi-block decryption at the core level does not imply multi-block authenticated plaintext release through the Basic wrapper.

Functional simulation does not replace:

- FPGA synthesis.
- Post-implementation timing verification.
- Clock-domain crossing analysis.
- Physical GPIO communication testing.
- Raspberry Pi integration testing.
- Comprehensive security and side-channel analysis.

The current simulation results establish functional verification of the Basic implementation within the scope of the executed testbenches.