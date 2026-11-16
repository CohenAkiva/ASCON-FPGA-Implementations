# ASCON RTL Architecture

This directory contains the synthesizable VHDL for the project's **ASCON-AEAD128 encryption and authenticated-decryption implementations**, plus the byte-oriented FPGA interface wrappers. The implementations are intended for the Digilent Basys3 FPGA platform. Verification instructions and observed simulation results are documented separately in [`../simulation/README.md`](../simulation/README.md).

## Directory layout

```text
rtl/
├── README.md
├── common/
│   ├── ascon_pack.vhd
│   ├── ASCON_ROUND.vhd
│   └── ASCON_PERMUTATION.vhd
├── encryption/
│   └── ASCON_TOP_LEVEL.vhd
├── decryption/
│   └── ASCON_DECRYPT_TOP_LEVEL.vhd
└── interfaces/
    ├── wrapper_encrypt.vhd
    └── wrapper_decrypt.vhd
```

## Architectural hierarchy

```text
                   Raspberry Pi / external byte interface
                                 |
                  +--------------+--------------+
                  |                             |
          wrapper_encrypt.vhd            wrapper_decrypt.vhd
                  |                             |
          ASCON_TOP_LEVEL              ASCON_DECRYPT_TOP_LEVEL
                  |                             |
                  +------- ASCON_PERMUTATION ---+
                                   |
                              ASCON_ROUND
                                   |
                         functions in ascon_pack
```

The diagram represents two **alternative build configurations**, not two wrappers instantiated together. The common permutation and round source files are shared by both builds.

## Shared permutation datapath (`common/`)

| File | Responsibility |
| --- | --- |
| `ascon_pack.vhd` | Shared package containing Ascon-related functions and definitions used by the RTL. |
| `ASCON_ROUND.vhd` | Combinational implementation of one permutation round, including the round-constant addition, substitution layer and linear diffusion layer. |
| `ASCON_PERMUTATION.vhd` | Clocked controller that repeatedly applies the round function to a 320-bit state. |

`ASCON_PERMUTATION` accepts `STATE_IN(319 downto 0)`, produces `STATE_OUT(319 downto 0)` and exposes `START`/`DONE` control signals. Its `ROUND_SEL` input selects **8 rounds when `0`** and **12 rounds when `1`**. A single round datapath is reused across successive clock cycles rather than instantiating all rounds in parallel.

## Encryption core (`encryption/`)

`ASCON_TOP_LEVEL.vhd` implements the AEAD encryption sequence using the shared permutation engine. Its interface includes:

| Signal | Direction | Meaning |
| --- | --- | --- |
| `CLK`, `RESET`, `START` | Input | Clock, active-high reset and transaction/block control. |
| `KEY(127:0)`, `NONCE(127:0)` | Input | 128-bit key and nonce. |
| `DATA_IN(127:0)` | Input | Up to 16 bytes of associated data or plaintext. |
| `DATA_BYTES(4:0)` | Input | Number of valid input bytes, 0–16. |
| `PROCESS_AD`, `IS_LAST` | Input | Block type and final-block indication. |
| `DATA_OUT(127:0)` | Output | Produced ciphertext block. |
| `TAG(127:0)` | Output | Authentication tag. |
| `READY`, `DONE` | Output | Interface handshake/status. |

The core processes associated data (AD), plaintext blocks and finalization according to its state machine. See the source and simulation testbenches for the precise block-transfer protocol.

## Authenticated-decryption core (`decryption/`)

`ASCON_DECRYPT_TOP_LEVEL.vhd` uses the same shared permutation engine to process AD and ciphertext, recover plaintext and verify the supplied authentication tag.

Its principal interface is analogous to the encryption core, except that it accepts `TAG_IN(127:0)` and reports `TAG_VALID` rather than producing a `TAG` output. **A decryption result must not be treated as authenticated until `TAG_VALID` indicates success.** The wrapper implements an additional output-release policy described below.

## FPGA interface wrappers (`interfaces/`)

Both wrappers expose the same external byte-oriented interface:

```vhdl
CLK, RESET, TO_READ, TO_WRITE : std_logic;
ADDRESS                       : std_logic_vector(5 downto 0);
DATA_IN, DATA_OUT             : std_logic_vector(7 downto 0);
```

The wrappers assemble 128-bit values from individual bytes, manage command/status registers, initiate core operations and make results readable through the 8-bit output bus. They include two-stage synchronizers for the asynchronous `TO_READ` and `TO_WRITE` control inputs, rising-edge detection, and `ASYNC_REG` attributes for the synchronizer stages.

### Common address conventions

| Address (decimal) | Purpose |
| --- | --- |
| `0–15` | Write key bytes; read result bytes. |
| `16–31` | Write nonce bytes; read tag bytes. |
| `32–47` | Write data-block bytes (AD/plaintext/ciphertext as applicable). |
| `48` | Command register (write). |
| `49` | Status register (read). |
| `50` | Valid byte count for the next block (write). |
| `51` | Block flags (write): AD and last-block bits. |
| `52` | AD-presence indication for initialization (write). |
| `53` | Result byte count (read). |
| `54–57` | Last-command cycle counter (read, little-endian byte order). |
| `58–61` | Cumulative active-cycle counter (read, little-endian byte order). |

The decryption wrapper additionally uses **address `62`** to select the write bank: data-block bytes or expected-tag bytes at addresses `32–47`. Its status byte includes authentication-related bits. Consult the relevant wrapper source before writing host software, because read and write meanings differ and some registers are configuration-specific.

### Authentication and output release

The decryption wrapper checks `TAG_VALID` before copying recovered plaintext into its readable result register. When authentication fails, it clears the readable result instead of exposing the unauthenticated plaintext. This behavior is exercised by the wrapper integration testbench; the core's `TAG_VALID` checks are exercised separately by the negative KAT tests.

### Build warning: duplicate entity names

**Both `wrapper_encrypt.vhd` and `wrapper_decrypt.vhd` declare an entity named `wrapper`.** They are alternative top-level implementations. Compile only the selected wrapper into a given VHDL library/build, or use separate libraries/projects. Compiling both into the same `work` library can replace the previously compiled `wrapper` design unit.

## Compilation order

For either core, compile the shared files first:

1. `rtl/common/ascon_pack.vhd`
2. `rtl/common/ASCON_ROUND.vhd`
3. `rtl/common/ASCON_PERMUTATION.vhd`
4. `rtl/encryption/ASCON_TOP_LEVEL.vhd` **or** `rtl/decryption/ASCON_DECRYPT_TOP_LEVEL.vhd`
5. The matching `rtl/interfaces/wrapper_encrypt.vhd` **or** `rtl/interfaces/wrapper_decrypt.vhd`, if the wrapper is part of the build.

For reproducible simulation runs, use the checked-in `.do` scripts from the repository root; see [`../simulation/README.md`](../simulation/README.md). FPGA pin mappings and timing constraints belong in [`../constraints/`](../constraints/), not in the RTL.

## Verification scope and reproducibility

The project has recorded passing ModelSim KAT tests for encryption and decryption, plus wrapper and negative-authentication tests. These are **simulation results**, not proof of hardware timing closure or completed board-level verification. Preserve the matching source revision, constraints, tool versions, synthesis/implementation settings and Vivado reports when creating a baseline release.

For changes to the shared round or permutation engine, rerun **both** encryption and decryption test suites because both implementations depend on the shared files.
