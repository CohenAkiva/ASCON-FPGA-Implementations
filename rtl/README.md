# RTL Architecture — ASCON Basic

## 1. Overview

This directory contains the synthesizable VHDL source files of the ASCON Basic implementation.

The hardware architecture is divided into three main layers:

- External communication and transaction control.
- Authenticated encryption and decryption cores.
- Shared ASCON permutation and round logic.

The Basic implementation does not include dedicated hardware performance counters.

## 2. Directory Structure

```text
rtl/
├── common/
│   ├── ascon_pack.vhd
│   ├── ASCON_ROUND.vhd
│   └── ASCON_PERMUTATION.vhd
├── encryption/
│   └── ASCON_TOP_LEVEL.vhd
├── decryption/
│   └── ASCON_DECRYPT_TOP_LEVEL.vhd
├── interfaces/
│   ├── wrapper_encrypt.vhd
│   └── wrapper_decrypt.vhd
└── README.md
```

## 3. Hardware Hierarchy

### Encryption

```text
wrapper_encrypt.vhd
        │
        ▼
ASCON_TOP_LEVEL
        │
        ▼
ASCON_PERMUTATION
        │
        ▼
ASCON_ROUND
```

### Decryption

```text
wrapper_decrypt.vhd
        │
        ▼
ASCON_DECRYPT_TOP_LEVEL
        │
        ▼
ASCON_PERMUTATION
        │
        ▼
ASCON_ROUND
```

Both implementations reuse the common ASCON package, round logic, and permutation architecture.

## 4. Common Modules

### ascon_pack.vhd

Provides shared definitions and utility functions used by the ASCON hardware modules.

### ASCON_ROUND.vhd

Implements one combinational ASCON round, consisting of three transformations:

- Constant addition (pC).
- Nonlinear substitution (pS).
- Linear diffusion (pL).

The round operates on a 320-bit internal state consisting of five 64-bit words.

### ASCON_PERMUTATION.vhd

Implements the iterative ASCON permutation engine.

A single combinational round module is reused across multiple clock cycles, supporting:

- Ascon-p[12]: 12 rounds.
- Ascon-p[8]: 8 rounds.

The permutation is controlled by a finite state machine:

| State | Function |
|---|---|
| IDLE | Wait for a permutation request. |
| PROCESS_ROUND | Execute and register successive rounds. |
| FINISH | Publish the final state and signal completion. |

## 5. Encryption Core

**File:** `encryption/ASCON_TOP_LEVEL.vhd`

Implements the authenticated encryption procedure:

1. Initialization.
2. Associated data processing.
3. Domain separation.
4. Plaintext processing.
5. Finalization.
6. Authentication tag generation.

The core supports multi-block associated data and plaintext messages.

The data block size is 128 bits (16 bytes). Partial final blocks and the required padding are handled internally.

## 6. Decryption Core

**File:** `decryption/ASCON_DECRYPT_TOP_LEVEL.vhd`

Implements the authenticated decryption procedure:

1. Initialization.
2. Associated data processing.
3. Domain separation.
4. Ciphertext processing.
5. Finalization.
6. Authentication tag verification.

The core supports multi-block ciphertext processing.

However, the core alone does not guarantee that all intermediate plaintext remains inaccessible until final authentication. Secure plaintext release must therefore be managed by the surrounding interface architecture.

## 7. External Wrappers

### wrapper_encrypt.vhd

Provides the external communication interface for the encryption core.

Its responsibilities include:

- Byte-oriented GPIO communication.
- Key and nonce register management.
- Input and output data register management.
- Address decoding.
- Transaction and block control.
- Synchronization of external read and write control signals.
- Encryption result and authentication tag readback.

### wrapper_decrypt.vhd

Provides the external communication interface for the decryption core.

In addition to register management and transaction control, the wrapper implements authentication-dependent plaintext release.

The Basic decryption wrapper intentionally supports ciphertext messages of up to 16 bytes per transaction.

Plaintext is retained internally and released only after successful authentication.

Multi-block associated data is supported.

## 8. Core and Wrapper Capabilities

| Feature | Encryption | Decryption |
|---|---|---|
| Internal state size | 320 bits | 320 bits |
| Key size | 128 bits | 128 bits |
| Nonce size | 128 bits | 128 bits |
| Authentication tag size | 128 bits | 128 bits |
| Data block size | 128 bits | 128 bits |
| Multi-block associated data | Supported | Supported |
| Multi-block messages at core level | Supported | Supported |
| Multi-block messages through wrapper | Supported | Not supported |
| Dedicated performance counters | Not included | Not included |

## 9. Compilation Order

The common modules must be compiled before the selected cryptographic core and its wrapper.

### Encryption

1. `common/ascon_pack.vhd`
2. `common/ASCON_ROUND.vhd`
3. `common/ASCON_PERMUTATION.vhd`
4. `encryption/ASCON_TOP_LEVEL.vhd`
5. `interfaces/wrapper_encrypt.vhd`

### Decryption

1. `common/ascon_pack.vhd`
2. `common/ASCON_ROUND.vhd`
3. `common/ASCON_PERMUTATION.vhd`
4. `decryption/ASCON_DECRYPT_TOP_LEVEL.vhd`
5. `interfaces/wrapper_decrypt.vhd`

Both wrapper files declare an entity named `wrapper`.

Encryption and decryption must therefore be compiled in separate simulation libraries or independent Vivado projects.

## 10. Design Objectives

The Basic architecture serves as the functional reference for the other ASCON implementations in this repository.

Its main objectives are:

- Functional correctness.
- Modular hardware architecture.
- Reuse of common cryptographic components.
- Separation of cryptographic processing and external communication.
- Reproducible FPGA implementation.
- Hardware resource comparison without dedicated performance-monitoring logic.

## 11. Verification Status

Functional simulations have been successfully completed using ModelSim 2020.1.

Synthesis, implementation, timing analysis, resource utilization analysis, and physical hardware verification of the current Basic branch remain pending.

See the repository root README for the overall verification status.