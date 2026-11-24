# Basic FPGA Bitstreams

## Target and Reference Builds

These bitstreams target the Digilent Basys3 board, Artix-7 `xc7a35tcpg236-1`, using Vivado 2024.1 and a 100 MHz board clock. Encryption and authenticated decryption are separate FPGA configurations.

| Direction | Reference Bitstream Path | Status |
|---|---|---|
| Encryption | `encryption/20261124_163808/ascon_basic_encrypt.bit` | Confirmed in repository; hardware test pending |
| Decryption | `decryption/20261124_165115/ascon_basic_decrypt.bit` | Confirmed in repository; hardware test pending |

### Bitstream File Verification

| Parameter | Encryption | Decryption |
|---|---|---|
| Build ID | 20261124_163808 | 20261124_165115 |
| File size | 2,192,115 bytes | 2,192,115 bytes |
| GitHub availability | Confirmed | Confirmed |
| Physical programming test | Pending | Pending |
| Hardware functional verification | Pending | Pending |

Both bitstream files have been verified to exist in the GitHub repository and are non-empty.

The corresponding reports are in [reports](../reports/README.md).

Both builds record the following RTL source commit:

`15328f4e1cbe695037201f577145071b68a59101`

Use `build_info.txt` and local source snapshots to establish exact build provenance.

## Programming the Basys3

1. Verify that the selected bitstream matches the board, branch, and intended operation.
2. Connect the Basys3 via its programming USB connection and power it on.
3. In Vivado, open Hardware Manager, select Open Target > Auto Connect, then select the FPGA device and Program Device.
4. Choose the corresponding `.bit` file and program the FPGA.
5. Confirm programming success, reset the design using the center pushbutton, and run the matching Raspberry Pi test script.

JTAG programming configures volatile FPGA memory; configuration is lost when power is removed. This workflow does not program configuration flash.

## GPIO and Functional Verification

Use the pin assignments documented in [constraints](../constraints/README.md) and [software](../software/README.md).

Power down before changing wiring, connect a common ground, use 3.3 V-compatible GPIO signals, and do not tie the two boards' power rails together.

Ensure Raspberry Pi peripheral functions do not conflict with the selected GPIO pins.

Run from the repository root on the Raspberry Pi:

```bash
python3 software/encryption/ascon_kat_v2.py verification/KAT/LWC_AEAD_KAT_128_128.txt --count 529

python3 software/decryption/test_ascon_decrypt_pi.py

python3 software/decryption/test_ascon_decrypt_pi.py --negative
```

Program the encryption bitstream for the first command and the decryption bitstream for the latter two.

The Basic decryption wrapper supports ciphertext lengths of 0–16 bytes. Do not use it for longer ciphertext messages.

After smoke tests, run the larger KAT suites described in the software README.

Record actual results, including rejection of invalid tags and absence of readable unauthenticated plaintext.

## Versioning and Release Policy

Preserve each reference bitstream alongside its matching report directory and build identifier.

Do not overwrite a reference artifact when rebuilding.

Verify that Git tracks the intended `.bit` and `.rpt` files. Check `.gitignore` if needed.

Do not commit Vivado caches or temporary files.

For additional artifact integrity verification, record a SHA-256 hash of each binary using PowerShell:

```powershell
Get-FileHash -Algorithm SHA256 "bitstreams
