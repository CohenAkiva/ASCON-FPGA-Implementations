# Raspberry Pi Software for ASCON FPGA Verification

This directory contains Python programs that communicate with the ASCON encryption and decryption wrappers implemented on the Digilent Basys3 FPGA board. The programs use Raspberry Pi 5 GPIO to transfer bytes, issue commands, read status registers, and compare hardware outputs with the `LWC_AEAD_KAT_128_128.txt` known-answer test (KAT) vectors.

> **Verification scope:** These are **hardware test utilities**, not ModelSim testbenches. Passing RTL simulations does not establish that these programs have passed on a physical board. Record actual board-test results separately.

## Directory layout

```text
software/
├── README.md
├── encryption/
│   └── ascon_kat_v2.py
└── decryption/
    ├── test_ascon_decrypt_pi.py
    └── test_ascon_decrypt_report.py
```

The KAT input file is expected at `verification/KAT/LWC_AEAD_KAT_128_128.txt` relative to the repository root.

## Requirements

- Raspberry Pi 5 running a compatible Raspberry Pi OS and Python 3.
- `gpiozero` for GPIO access; the decryption utility explicitly imports `LGPIOFactory` from `gpiozero.pins.lgpio` and therefore requires the `lgpio` backend.
- A programmed Basys3 board with the matching **encryption or decryption** bitstream and matching XDC constraints.
- GPIO wiring matching the pin lists in the scripts and the FPGA wrapper interface. See [`../constraints/README.md`](../constraints/README.md).
- A **common GND** between Raspberry Pi and Basys3. Both sides use **3.3 V logic**. Do **not** connect their 3.3 V supply rails together.
- Basys3's onboard 100 MHz clock, with the corresponding clock constraint. This is a configured clock frequency, not proof of timing closure.

**GPIO numbering:** All pin numbers in the scripts are **BCM GPIO numbers**, not Raspberry Pi physical header pin numbers. Bit index 0 corresponds to the first GPIO listed in each bus array.

| Signal | BCM GPIO pins (bit 0 first) |
|---|---|
| `ADDRESS[5:0]` | `17, 27, 22, 23, 24, 25` |
| `DATA_IN[7:0]` (Pi → FPGA) | `5, 6, 13, 19, 26, 12, 16, 20` |
| `DATA_OUT[7:0]` (FPGA → Pi) | `21, 4, 18, 14, 15, 7, 8, 9` |
| `TO_WRITE` | `10` |
| `TO_READ` | `11` |

The GPIO mapping is consistent across the three supplied Python files. **Verify the physical pin-to-PMOD wiring against the actual XDC and wrapper before energizing the connection.**

## Encryption hardware KAT runner

**File:** `encryption/ascon_kat_v2.py`

This utility reads KAT records, sends `KEY`, `NONCE`, associated data (AD), and plaintext to the encryption wrapper, and compares the resulting ciphertext and authentication tag with the KAT. It also reads command and total active-cycle counters from the FPGA.

Run from the **repository root** on the Raspberry Pi:

```bash
python3 software/encryption/ascon_kat_v2.py verification/KAT/LWC_AEAD_KAT_128_128.txt --count 529
```

Or run a limited number of records:

```bash
python3 software/encryption/ascon_kat_v2.py verification/KAT/LWC_AEAD_KAT_128_128.txt --limit 10
```

Options: `--count` selects a particular KAT Count; `--limit` controls the number of cases when `--count` is not supplied (default: 10). The program asks the operator to reset Basys3 before the first case. It reports `PASS`/`FAIL` and stops on a mismatch.

**Implementation notes:** The script uses `gpiozero.OutputDevice` and `gpiozero.InputDevice`, with a fixed 1 ms delay between GPIO phases. It supports multiple transactions within a run and processes AD and plaintext in blocks of up to 16 bytes.

## Decryption single-case hardware test

**File:** `decryption/test_ascon_decrypt_pi.py`

This program uses one built-in KAT example. It writes the key, nonce, expected tag, and ciphertext to the decryption wrapper; issues initialization and processing commands; then checks the authentication status and plaintext output.

Positive test:

```bash
python3 software/decryption/test_ascon_decrypt_pi.py
```

Negative test (corrupts one bit of the tag):

```bash
python3 software/decryption/test_ascon_decrypt_pi.py --negative
```

To adjust the hold time of each GPIO phase (milliseconds):

```bash
python3 software/decryption/test_ascon_decrypt_pi.py --hold-ms 5
```

The program requests a **fresh FPGA reset** before starting. The positive test requires successful authentication and matching plaintext. The negative test requires authentication rejection, zero reported plaintext length, and a zeroed plaintext output register. The script also checks that plaintext is not exposed before completion.

The default GPIO phase hold time is 5 ms; the command-line parser requires at least 1 ms.

## Decryption multi-vector report

**File:** `decryption/test_ascon_decrypt_report.py`

This utility parses the KAT file, selects eligible cases, sends them through the decryption wrapper, and writes a text report with input/output data, authentication status, `PASS`/`FAIL`, per-command FPGA active cycles, and total active cycles.

Run from the repository root:

```bash
python3 software/decryption/test_ascon_decrypt_report.py verification/KAT/LWC_AEAD_KAT_128_128.txt --max-cases 20 --output ascon_decrypt_hardware_results.txt
```

To also test a corrupted authentication tag for each selected vector:

```bash
python3 software/decryption/test_ascon_decrypt_report.py verification/KAT/LWC_AEAD_KAT_128_128.txt --max-cases 20 --negative --output ascon_decrypt_hardware_results.txt
```

Supported options include `--max-cases` (default 20), `--start-count` (default 1), `--negative`, `--hold-ms` (default 5), and `--output`.

**Scope limitation:** The script selects only KAT records with plaintext length **at most 16 bytes**. It can send associated data across multiple 16-byte blocks. The reported cycle counts measure **FPGA active cycles**, not end-to-end Raspberry Pi GPIO execution time.

**Dependency:** `test_ascon_decrypt_report.py` imports `Interface` from `test_ascon_decrypt_pi.py`; keep both files in the same `software/decryption/` directory.

## Important implementation checks before hardware execution

1. **GPIO input configuration:** The report script's header says it requires a version of `test_ascon_decrypt_pi.py` with an `active_state=True` fix. In the supplied version, `Interface._in()` calls `DigitalInputDevice(pin, pull_up=None, pin_factory=self.factory)` without an explicit `active_state`. Confirm compatibility with the installed `gpiozero`/`lgpio` versions before running. Do not assume the current version has been hardware-validated.
2. **Reset between tests:** The single-case decryption test explicitly requests a fresh Basys3 reset. The report utility prompts for a reset at startup, then executes multiple vectors without an additional reset prompt. Verify the wrapper's transaction reinitialization behavior on hardware.
3. **Pin conflicts and electrical safety:** Verify BCM-to-physical-pin mapping, direction, shared ground, and 3.3 V levels before connecting the Pi to the FPGA. Do not drive an FPGA output from a Pi output.
4. **Matching FPGA image:** Load the encryption bitstream for the encryption script and the decryption bitstream for the decryption scripts. Both wrappers are separate builds.
5. **Test evidence:** Keep dated console logs or generated report files under `reports/` when hardware tests are actually performed. Do not label a simulation result as a hardware result.

## Register interface used by the scripts

The scripts communicate over a 6-bit address bus and an 8-bit data bus. Notable addresses include:

| Address | Use in scripts |
|---|---|
| `0–15` | Write KEY / read output data (operation-dependent) |
| `16–31` | Write NONCE / read authentication tag in encryption |
| `32–47` | Write input payload or expected TAG, selected by bank |
| `48` | Command (`1` = initialize, `2` = process block) |
| `49` | Status |
| `50` | Payload length |
| `51` | Block flags (AD and last-block bits) |
| `52` | Associated-data-present flag |
| `53` | Output length |
| `54–57` | Command active-cycle count (little-endian) |
| `58–61` | Total active-cycle count (little-endian) |
| `62` | Input bank selection (used by decryption) |

For the authoritative hardware behavior and any encryption/decryption differences, consult the corresponding VHDL wrapper source in `rtl/interfaces/`.

## Baseline reproducibility

When freezing a reference version, record the Git commit/tag, Python and package versions, Raspberry Pi OS version, FPGA bitstream identity, board wiring, XDC revision, test command, selected KAT counts, execution date, and actual hardware results. Preserve the original KAT file and avoid modifying source code after tagging without creating a new revision.
