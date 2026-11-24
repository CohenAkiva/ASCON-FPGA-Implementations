# ASCON FPGA Implementations — Basic

## 1. Project Overview

This project presents a hardware implementation of the ASCON-AEAD128 authenticated encryption algorithm as part of a final-year engineering project.

The main objective is to design, implement, verify, and evaluate ASCON on different FPGA platforms, examining hardware resource utilization, timing performance, power consumption, and architectural trade-offs.

The Basic branch provides the reference implementation for subsequent development and comparison.

## 2. Project Objectives

- Implement ASCON authenticated encryption and decryption in VHDL.
- Verify algorithm correctness using official Known Answer Tests (KATs).
- Implement a reusable permutation engine supporting p8 and p12.
- Establish communication between an FPGA and a Raspberry Pi.
- Evaluate hardware resource utilization, timing, and estimated power consumption.
- Establish a reproducible baseline for future architectural improvements and FPGA platforms.

## 3. Basic Implementation

The Basic version includes:

- ASCON round transformation.
- Iterative permutation engine.
- Authenticated encryption core.
- Authenticated decryption core.
- Independent encryption and decryption wrappers.
- GPIO-based communication with Raspberry Pi 5.
- Functional and negative testbenches.
- Python hardware verification scripts.
- Automated Vivado build and reporting scripts.

This version does not include dedicated hardware performance counters.

The encryption wrapper supports multi-block messages. The Basic decryption wrapper supports multi-block associated data and ciphertext lengths of up to 16 bytes per authenticated transaction.

Plaintext is made available through the decryption wrapper only after successful authentication.

Extended authenticated decryption is developed separately in the `extended-decryption` branch.

## 4. Hardware and Development Environment

| Parameter | Configuration |
|---|---|
| FPGA board | Digilent Basys3 |
| FPGA family | Xilinx Artix-7 |
| FPGA device | xc7a35tcpg236-1 |
| Hardware description language | VHDL-2008 |
| Synthesis and implementation | Vivado 2024.1 |
| Simulation | ModelSim |
| Target clock frequency | 100 MHz |
| Clock period | 10 ns |
| External controller | Raspberry Pi 5 |
| Communication interface | GPIO through PMOD |
| Host programming language | Python 3 |

## 5. System Architecture

```text
Raspberry Pi 5
      |
      | GPIO / PMOD
      |
FPGA Wrapper
      |
      +-- Register Interface
      +-- Communication Control
      +-- Input / Output Registers
      +-- Transaction Control
      |
ASCON AEAD Core
      |
ASCON_PERMUTATION
      |
ASCON_ROUND
```

The encryption and decryption implementations share the same round transformation, permutation engine, and common VHDL package.

Each implementation uses a dedicated AEAD core and wrapper.

Encryption and decryption must be built separately because both wrappers use the entity name `wrapper`.

## 6. Repository Structure

```text
ASCON-FPGA-Implementations/
|
|-- README.md
|
|-- rtl/
|   |-- README.md
|   |-- common/
|   |-- encryption/
|   |-- decryption/
|   +-- interfaces/
|
|-- simulation/
|   |-- README.md
|   |-- encryption/
|   +-- decryption/
|
|-- software/
|   |-- README.md
|   |-- encryption/
|   +-- decryption/
|
|-- constraints/
|   |-- README.md
|   |-- basys3_encrypt.xdc
|   +-- basys3_decrypt.xdc
|
|-- scripts/
|   |-- README.md
|   |-- build_encrypt.tcl
|   +-- build_decrypt.tcl
|
|-- reports/
|   |-- README.md
|   |-- encryption/
|   +-- decryption/
|
|-- bitstreams/
|   |-- README.md
|   |-- encryption/
|   +-- decryption/
|
|-- verification/
|   +-- KAT/
|
+-- docs/
```

## 7. Functional Verification

The Basic implementation has been verified using five simulation suites.

| Simulation | Status |
|---|---|
| Encryption wrapper — full KAT verification | PASS |
| Decryption core — KAT verification | PASS |
| Decryption core — negative verification | PASS |
| Decryption wrapper — integration tests | PASS |
| Decryption wrapper — additional tests | PASS |

The verification environment covers:

- Official Known Answer Tests.
- Empty messages.
- Partial and full data blocks.
- Associated data processing.
- Authentication tag verification.
- Invalid authentication tags.
- Modified ciphertext and associated data.
- Consecutive transactions.
- Reset behavior.
- Invalid block length handling.

The decryption core and wrapper are verified separately because the Basic wrapper imposes additional message-length restrictions.

See [Simulation Documentation](simulation/README.md) for testbench descriptions and execution instructions.

## 8. FPGA Implementation Results

Both implementations were synthesized and routed using Vivado 2024.1 on the Basys3 target device.

Reference build date: November 24, 2026.

### Resource Utilization

The following values are taken from the post-implementation utilization reports.

| Resource | Encryption | Decryption |
|---|---:|---:|
| Slice LUTs | 1,899 | 2,069 |
| LUT utilization | 9.13% | 9.95% |
| Slice registers | 2,425 | 2,444 |
| Register utilization | 5.83% | 5.88% |
| Occupied slices | 667 | 684 |
| SLICEL | 553 | 567 |
| SLICEM | 114 | 117 |
| Unique control sets | 67 | 82 |
| DSP blocks | 0 | 0 |
| BRAM tiles | 0 | 0 |
| Bonded IOBs | 26 | 26 |

The complete decryption implementation requires approximately 8.95% more LUTs and 0.78% more registers than the encryption implementation.

### Timing Performance

| Metric | Encryption | Decryption |
|---|---:|---:|
| Target frequency | 100 MHz | 100 MHz |
| WNS | 2.052 ns | 2.868 ns |
| TNS | 0.000 ns | 0.000 ns |
| WHS | 0.021 ns | 0.034 ns |
| THS | 0.000 ns | 0.000 ns |
| Setup failing endpoints | 0 | 0 |
| Hold failing endpoints | 0 | 0 |
| Estimated maximum frequency | 125.82 MHz | 140.21 MHz |

Both implementations meet the specified internal timing constraints at 100 MHz.

The maximum frequency values are approximate extrapolations from the post-route setup slack. They are not independently validated operating frequencies.

### Estimated Power Consumption

| Metric | Encryption | Decryption |
|---|---:|---:|
| Total on-chip power | 112 mW | 119 mW |
| Static power | 72 mW | 72 mW |
| Dynamic power | 40 mW | 48 mW |
| Estimation confidence | Low | Low |

Power values are Vivado estimates rather than physical measurements. Representative switching activity and hardware measurements are required for more accurate evaluation.

### Design Rule and Methodology Checks

| Metric | Encryption | Decryption |
|---|---:|---:|
| DRC violations | 0 | 0 |
| Methodology warnings | 25 | 25 |

The methodology warnings concern missing external input and output delay constraints.

The asynchronous Raspberry Pi interface requires additional timing and CDC review. Internal timing closure does not independently establish external communication reliability.

For detailed resource analysis, critical paths, power estimates, and build provenance, see [Implementation Reports](reports/README.md).

## 9. Automated FPGA Build

Two Tcl scripts are provided:

- `scripts/build_encrypt.tcl`
- `scripts/build_decrypt.tcl`

The automated build process includes:

1. Git branch and FPGA device validation.
2. RTL and constraint file loading.
3. Build metadata recording.
4. Synthesis.
5. Placement and routing.
6. Resource, timing, power, DRC, and CDC report generation.
7. Local checkpoint generation.
8. Bitstream generation.

Create a separate empty Vivado RTL project for each implementation.

From the Vivado Tcl Console, execute the corresponding script:

```tcl
source "C:/FPGA_Projects/ASCON-FPGA-Implementations/scripts/build_encrypt.tcl"
```

```tcl
source "C:/FPGA_Projects/ASCON-FPGA-Implementations/scripts/build_decrypt.tcl"
```

Adjust the repository path when necessary.

See [Build Automation Documentation](scripts/README.md) for complete instructions.

## 10. Raspberry Pi Hardware Verification

Python scripts are provided for GPIO communication, encryption verification, authenticated decryption verification, and KAT-based hardware testing.

The software uses the `gpiozero` library with the LGPIO pin factory for Raspberry Pi 5 compatibility.

Physical verification of the current Basic builds remains pending.

See:

- [Software Documentation](software/README.md)
- [FPGA Constraints and Pin Mapping](constraints/README.md)
- [Bitstream Documentation](bitstreams/README.md)

## 11. Project Variants

| Branch | Purpose |
|---|---|
| `main` | General project documentation and overview |
| `basic` | Reference encryption and authenticated decryption implementation |
| `performance` | Implementation with hardware performance monitoring |
| `extended-decryption` | Two-pass authenticated decryption for multi-block ciphertext |

The Basic branch serves as the reference for evaluating the resource and timing overhead of subsequent implementations.

## 12. Current Verification Status

| Development stage | Status |
|---|---|
| RTL implementation | Completed |
| Functional simulation | Passed |
| Negative authentication testing | Passed |
| Python script preparation | Completed |
| Encryption synthesis | Completed |
| Encryption implementation | Completed |
| Encryption bitstream generation | Confirmed |
| Decryption synthesis | Completed |
| Decryption implementation | Completed |
| Decryption bitstream generation | Confirmed |
| Internal timing at 100 MHz | Passed |
| Implementation report analysis | Completed |
| External interface timing and CDC review | Pending |
| Raspberry Pi hardware verification | Pending |
| Physical power measurements | Pending |

## 13. Future Development

Planned development includes:

- Hardware-based latency and cycle-count measurement.
- Throughput and efficiency analysis.
- Extended authenticated decryption using a two-pass architecture.
- High-fanout control signal optimization.
- Critical path optimization.
- Improved power estimation using switching activity.
- Physical hardware verification.
- Implementation on additional FPGA platforms.
- Cross-platform resource and performance comparison.

## 14. Documentation

| Document | Description |
|---|---|
| [RTL](rtl/README.md) | Hardware architecture and module hierarchy |
| [Simulation](simulation/README.md) | Functional verification and testbenches |
| [Software](software/README.md) | Raspberry Pi communication and Python tests |
| [Constraints](constraints/README.md) | FPGA pin mapping and timing constraints |
| [Scripts](scripts/README.md) | Automated Vivado build process |
| [Reports](reports/README.md) | Detailed implementation results |
| [Bitstreams](bitstreams/README.md) | FPGA programming and verification instructions |

## 15. Reference Standard

NIST SP 800-232 — Ascon-Based Lightweight Cryptography Standards for Constrained Devices.

https://doi.org/10.6028/NIST.SP.800-232

---

**Basic Reference Implementation — Final-Year Engineering Project**