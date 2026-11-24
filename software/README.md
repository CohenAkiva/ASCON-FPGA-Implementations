# Raspberry Pi Software — ASCON Basic

## 1. Overview

This directory contains the Python software used to communicate with the ASCON Basic FPGA implementations through the Raspberry Pi GPIO interface.

The software provides:

- Byte-oriented communication with the FPGA.
- Encryption verification against ASCON Known Answer Test vectors.
- Authenticated decryption verification.
- Negative authentication testing.
- Hardware verification report generation.

The software is designed for Raspberry Pi 5 connected to the Digilent Basys3 FPGA development board.

The Basic implementation does not include dedicated FPGA clock-cycle counters.

## 2. Directory Structure

```text
software/
├── encryption/
│   └── ascon_kat_v2.py
├── decryption/
│   ├── test_ascon_decrypt_pi.py
│   └── test_ascon_decrypt_report.py
└── README.md
```

## 3. Hardware Requirements

- Raspberry Pi 5.
- Digilent Basys3 development board.
- GPIO-to-PMOD connection wires.
- Common ground connection.
- Corresponding encryption or decryption FPGA bitstream.
- Independent power supplies for both boards.

The communication interface operates at 3.3 V logic levels.

The FPGA uses its onboard 100 MHz clock. No external clock signal is required from the Raspberry Pi.

The FPGA reset signal is controlled using the Basys3 center push button.

## 4. Software Requirements

- Raspberry Pi OS.
- Python 3.
- gpiozero.
- lgpio.

Install the required packages on the Raspberry Pi:

```bash
sudo apt update
sudo apt install python3-gpiozero python3-lgpio
```

The GPIO interface uses the `LGPIOFactory` backend.

All GPIO numbers in the Python scripts use BCM numbering rather than physical header pin numbering.

## 5. Communication Architecture

```text
Raspberry Pi 5
      │
      │ GPIO
      ▼
Basys3 PMOD Interface
      │
      ▼
ASCON Wrapper
      │
      ▼
ASCON Cryptographic Core
      │
      ▼
ASCON Permutation Engine
```

The external communication interface consists of:

| Signal | Width | Direction |
|---|---:|---|
| DATA_IN | 8 bits | Raspberry Pi → FPGA |
| DATA_OUT | 8 bits | FPGA → Raspberry Pi |
| ADDRESS | 6 bits | Raspberry Pi → FPGA |
| TO_WRITE | 1 bit | Raspberry Pi → FPGA |
| TO_READ | 1 bit | Raspberry Pi → FPGA |

Total communication signals: 24, excluding ground.

The encryption and decryption implementations use the same physical GPIO and PMOD pin assignments.

## 6. GPIO and PMOD Pin Mapping

### PMOD JA — DATA_IN

| Signal | Basys3 PMOD | FPGA Pin | BCM GPIO | Raspberry Pi Physical Pin |
|---|---|---|---:|---:|
| DATA_IN[0] | JA1 | J1 | 5 | 29 |
| DATA_IN[1] | JA2 | L2 | 6 | 31 |
| DATA_IN[2] | JA3 | J2 | 13 | 33 |
| DATA_IN[3] | JA4 | G2 | 19 | 35 |
| DATA_IN[4] | JA7 | H1 | 26 | 37 |
| DATA_IN[5] | JA8 | K2 | 12 | 32 |
| DATA_IN[6] | JA9 | H2 | 16 | 36 |
| DATA_IN[7] | JA10 | G3 | 20 | 38 |

### PMOD JB — DATA_OUT

| Signal | Basys3 PMOD | FPGA Pin | BCM GPIO | Raspberry Pi Physical Pin |
|---|---|---|---:|---:|
| DATA_OUT[0] | JB1 | A14 | 21 | 40 |
| DATA_OUT[1] | JB2 | A16 | 4 | 7 |
| DATA_OUT[2] | JB3 | B15 | 18 | 12 |
| DATA_OUT[3] | JB4 | B16 | 14 | 8 |
| DATA_OUT[4] | JB7 | A15 | 15 | 10 |
| DATA_OUT[5] | JB8 | A17 | 7 | 26 |
| DATA_OUT[6] | JB9 | C15 | 8 | 24 |
| DATA_OUT[7] | JB10 | C16 | 9 | 21 |

### PMOD JC — Address and Control

| Signal | Basys3 PMOD | FPGA Pin | BCM GPIO | Raspberry Pi Physical Pin |
|---|---|---|---:|---:|
| TO_READ | JC1 | K17 | 11 | 23 |
| TO_WRITE | JC2 | M18 | 10 | 19 |
| ADDRESS[0] | JC3 | N17 | 17 | 11 |
| ADDRESS[1] | JC4 | P18 | 27 | 13 |
| ADDRESS[2] | JC7 | L17 | 22 | 15 |
| ADDRESS[3] | JC8 | M19 | 23 | 16 |
| ADDRESS[4] | JC9 | P17 | 24 | 18 |
| ADDRESS[5] | JC10 | R18 | 25 | 22 |

### Electrical and Wiring Precautions

- Disconnect power before changing the wiring.
- Connect a common ground between both boards.
- Do not connect the 3.3 V power rails together.
- Never apply 5 V to the GPIO or PMOD signals.
- Verify connector orientation and pin numbering before applying power.
- Ensure that SPI, UART, or other alternate GPIO functions do not conflict with the selected pins.
- Program the FPGA with the correct bitstream before running the corresponding Python script.

## 7. Register Address Map

The wrapper uses a 6-bit address bus, providing 64 address locations.

### Write Operations

| Address | Register / Function |
|---|---|
| 0–15 | KEY bytes |
| 16–31 | NONCE bytes |
| 32–47 | Input data bytes or expected TAG bytes in decryption TAG-bank mode |
| 48 | COMMAND |
| 50 | BLOCK_BYTES |
| 51 | BLOCK_FLAGS |
| 52 | INIT_HAS_AD |
| 62 | TAG_BANK — decryption only |

### Read Operations

| Address | Register / Function |
|---|---|
| 0–15 | Ciphertext or authenticated plaintext |
| 16–31 | Generated authentication TAG — encryption |
| 49 | STATUS |
| 53 | RESULT_LENGTH |
| 54–61 | Unused performance-counter addresses in Basic |

### COMMAND Register — Address 48

| Value | Function |
|---|---|
| 0x01 | Initialize a new transaction |
| 0x02 | Process the current input block |

### BLOCK_FLAGS Register — Address 51

| Bit | Function |
|---|---|
| 0 | PROCESS_AD |
| 1 | IS_LAST |

### STATUS Register — Address 49

| Bit | Function |
|---|---|
| 0 | READY |
| 1 | RESULT_VALID |
| 2 | TRANSACTION_DONE |
| 3 | ERROR |
| 4 | AUTH_VALID — decryption only |
| 5 | TAG_BANK — decryption only |

### TAG_BANK Register — Address 62

Used by the decryption wrapper to select the destination of writes to addresses 32–47.

| Value | Destination |
|---|---|
| 0 | Ciphertext or associated data register |
| 1 | Expected authentication tag register |

## 8. GPIO Communication Procedure

### Write Operation

1. Set the address bus.
2. Set the input data bus.
3. Allow the signals to settle.
4. Assert TO_WRITE.
5. Deassert TO_WRITE.
6. Allow sufficient time before the next operation.

### Read Operation

1. Set the address bus.
2. Allow the address signals to settle.
3. Assert TO_READ.
4. Wait for the FPGA output to become stable.
5. Sample the output data bus.
6. Deassert TO_READ.

The FPGA wrapper synchronizes the external read and write control signals to its internal clock.

The Python scripts introduce GPIO settling and strobe delays to support reliable communication. These delays are not measurements of FPGA processing latency.

## 9. Encryption Verification

**Script:** `encryption/ascon_kat_v2.py`

This script sends ASCON KAT inputs to the encryption wrapper and compares the returned ciphertext and authentication tag with the expected values.

It supports:

- Empty plaintext.
- Multi-block plaintext.
- Multi-block associated data.
- Partial and full data blocks.
- Repeated encryption transactions.
- Individual or multiple KAT cases.

Run all commands from the repository root.

### Single KAT Vector

```bash
python3 software/encryption/ascon_kat_v2.py verification/KAT/LWC_AEAD_KAT_128_128.txt --count 529
```

### First 10 KAT Vectors

```bash
python3 software/encryption/ascon_kat_v2.py verification/KAT/LWC_AEAD_KAT_128_128.txt --limit 10
```

### Full KAT Dataset

```bash
python3 software/encryption/ascon_kat_v2.py verification/KAT/LWC_AEAD_KAT_128_128.txt --limit 1089
```

Expected successful completion:

```text
ALL 1089 KAT CASES PASSED
```

## 10. Initial Decryption Verification

**Script:** `decryption/test_ascon_decrypt_pi.py`

This script performs an initial hardware verification using a predefined KAT vector.

It checks:

- Correct plaintext recovery.
- Authentication status.
- Result length.
- Rejection of an invalid authentication tag.
- Plaintext suppression when authentication fails.

### Valid Authentication Test

```bash
python3 software/decryption/test_ascon_decrypt_pi.py
```

### Invalid Authentication Test

```bash
python3 software/decryption/test_ascon_decrypt_pi.py --negative
```

Reset the FPGA before starting each independent test.

### GPIO Timing Adjustment

```bash
python3 software/decryption/test_ascon_decrypt_pi.py --hold-ms 10
```

The default GPIO phase duration is 5 milliseconds.

## 11. Decryption KAT Report

**Script:** `decryption/test_ascon_decrypt_report.py`

This script performs hardware decryption verification using the KAT dataset and generates a detailed text report.

It imports the GPIO communication interface from `test_ascon_decrypt_pi.py`. Both files must remain in the same directory.

The report includes:

- KAT case number.
- Key and nonce.
- Associated data.
- Ciphertext.
- Authentication tag.
- Recovered plaintext.
- Authentication and status flags.
- Expected results.
- PASS or FAIL for each executed test.
- Final verification summary.

Only KAT records containing ciphertext messages of up to 16 bytes are selected.

### Initial Verification

```bash
python3 software/decryption/test_ascon_decrypt_report.py verification/KAT/LWC_AEAD_KAT_128_128.txt --max-cases 10
```

### Positive and Negative Authentication Tests

```bash
python3 software/decryption/test_ascon_decrypt_report.py verification/KAT/LWC_AEAD_KAT_128_128.txt --max-cases 10 --negative
```

### Full Supported KAT Dataset

```bash
python3 software/decryption/test_ascon_decrypt_report.py verification/KAT/LWC_AEAD_KAT_128_128.txt --max-cases 561 --negative
```

The complete dataset contains 561 eligible vectors with plaintext lengths from 0 to 16 bytes.

When negative testing is enabled, each selected vector is tested with both a valid and a corrupted authentication tag.

The expected total is 1122 successful test executions if all selected cases pass.

### Custom Report Filename

```bash
python3 software/decryption/test_ascon_decrypt_report.py verification/KAT/LWC_AEAD_KAT_128_128.txt --max-cases 561 --negative --output basic_decryption_results.txt
```

The generated report is saved to the specified output path.

The default report filename is:

`ascon_decrypt_hardware_results.txt`

## 12. Implementation Limitations

The Basic encryption wrapper supports multi-block plaintext messages.

The Basic decryption wrapper supports ciphertext messages of up to 16 bytes per transaction. Multi-block associated data is supported.

The underlying decryption core supports multi-block ciphertext processing, but the Basic external wrapper intentionally restricts ciphertext length to ensure authentication-dependent plaintext release.

The Basic implementation does not provide dedicated clock-cycle counters.

GPIO communication delays and Python execution times must not be interpreted as cryptographic core latency or FPGA throughput.

The test scripts and reports are intended for verification using public KAT data, not production cryptographic key management.

## 13. Verification Status

| Verification Activity | Status |
|---|---|
| Python syntax verification | Completed |
| Static register-map compatibility review | Completed |
| GPIO pin mapping review | Completed |
| Encryption and decryption XDC comparison | Completed |
| Raspberry Pi 5 software execution | Pending |
| Physical GPIO communication verification | Pending |
| Encryption hardware KAT verification | Pending |
| Decryption hardware KAT verification | Pending |
| Negative authentication hardware verification | Pending |

The Python scripts have been adapted to the Basic hardware architecture.

Physical verification of the current Basic branch must be completed before the software is considered hardware-validated.

## 14. Related Documentation

- [Project Overview](../README.md)
- [RTL Architecture](../rtl/README.md)
- [Simulation and Functional Verification](../simulation/README.md)
- [FPGA Constraints](../constraints/)

