# ASCON FPGA Implementations

## Project Overview

This Electrical and Computer Engineering final project focuses on the design, implementation, verification, and performance evaluation of **ASCON AEAD-128 authenticated encryption and decryption hardware** using VHDL.

The initial implementation platform is the **Digilent Basys 3 FPGA development board (Xilinx Artix-7)**, with a **Raspberry Pi 5** serving as an external GPIO-based control and verification host.

The project currently includes independently implemented encryption and decryption designs, reusable ASCON permutation components, board-level interfaces, simulation testbenches, automated verification scripts, and archived FPGA implementation reports.

The verified starting point is preserved under the Git tag **`baseline-v1.0`**.

The longer-term research objective is to investigate alternative hardware architectures, evaluate resource and performance trade-offs, and explore implementation portability across FPGA platforms and toolchains.

**Shared-engine and dual-engine architectural comparisons remain planned research activities, not completed experimental results.**

---

## Project Objectives

1. Implement ASCON authenticated encryption and decryption in synthesizable VHDL.
2. Verify functional correctness through simulation, testbenches, and known-answer tests (KATs).
3. Integrate FPGA implementations with Raspberry Pi GPIO-based control and verification.
4. Evaluate hardware resource utilization, timing, latency, throughput, and power estimates.
5. Investigate shared-engine and separate-engine architectures.
6. Establish reproducible development and verification workflows using Git and GitHub.
7. Explore portability to additional FPGA platforms, including Intel FPGA devices.

## Current Implementation Status

| Component | Description | Status |
|---|---|---|
| Encryption core | ASCON authenticated encryption and tag generation | Implemented and verified |
| Decryption core | ASCON authenticated decryption and tag verification | Implemented and verified |
| Common permutation logic | Reusable package, round function, and permutation controller | Implemented |
| Encryption interface | Basys 3 GPIO wrapper for Raspberry Pi communication | Implemented and hardware-tested |
| Decryption interface | Basys 3 GPIO wrapper with authentication status and controlled plaintext release | Implemented and hardware-tested |
| Verification environment | VHDL testbenches, KAT files, simulation scripts, and Python utilities | Implemented |
| Baseline repository | Organized source tree, documentation, reports, and version tag | Completed — `baseline-v1.0` |
| Shared-engine architecture | Unified encryption/decryption hardware investigation | Planned |
| Dual-engine architecture | Separate-engine architectural investigation and comparison | Planned |
| Additional FPGA platforms | Porting and comparative implementation | Planned |

## ASCON Processing Architecture

The ASCON permutation operates on a **320-bit internal state**, consisting of five 64-bit words.

Each permutation round applies three transformations:

- **pC:** Addition of round constants.
- **pS:** Nonlinear substitution layer.
- **pL:** Linear diffusion layer.

The implementation separates the round function, permutation controller, algorithm-level control logic, and board-specific interfaces where practical.

The reusable permutation components support the encryption and decryption implementations.

See [`rtl/README.md`](rtl/README.md) for additional information about the RTL organization.

---

## Verification Results

The following results were obtained during the development and verification of the baseline implementations.

| Verification activity | Recorded result | Scope |
|---|---|---|
| Encryption simulation KAT | **1,089 / 1,089 PASS** | Full encryption KAT |
| Decryption simulation KAT | **1,089 / 1,089 PASS** | Full decryption KAT |
| Encryption performance testbench | **24 / 24 PASS** | Recorded performance-oriented tests |
| Decryption negative/authentication tests | **4,290 PASS, 0 FAIL** | Recorded negative-test suite |
| Decryption wrapper integration | **8 PASS** | Valid and corrupted authentication cases |
| Encryption Raspberry Pi / FPGA hardware KAT | **1,089 / 1,089 PASS** | Recorded hardware verification |
| Decryption Raspberry Pi / FPGA hardware tests | **1,122 / 1,122 PASS** | 561 eligible vectors with valid and corrupted tags |

### Verification Scope and Limitations

The decryption wrapper currently supports a maximum of **16 ciphertext bytes per transaction**.

In the recorded decryption hardware verification:

- 561 eligible KAT vectors were exercised.
- Both valid and corrupted authentication tags were tested.
- 1,122 hardware test cases passed.
- 528 longer KAT vectors were skipped because they exceeded the wrapper's transaction-length capability.

Skipped vectors are **not** counted as passed tests.

The full decryption core simulation covers a broader set of vectors than the current hardware wrapper.

Following repository reorganization, the full decryption core KAT was rerun successfully, with **1,089 / 1,089 passing**. Other recorded results should not be interpreted as evidence that every simulation script has been rerun from a fresh repository checkout.

For additional information, see:

- [`simulation/README.md`](simulation/README.md)
- [`software/README.md`](software/README.md)
- [`reports/README.md`](reports/README.md)

---

## FPGA Implementation Results

### Development Platform

- **Development board:** Digilent Basys 3
- **FPGA device:** Xilinx Artix-7 XC7A35T-1CPG236C
- **Clock constraint:** 100 MHz (10 ns)
- **Implementation tool:** AMD Vivado 2024.1
- **Simulation tool:** ModelSim – Intel FPGA Starter Edition 2020.1

### Recorded Post-Implementation Results

| Metric | Encryption | Decryption |
|---|---:|---:|
| LUTs | 1,986 | 2,159 |
| Flip-Flops | 2,521 | 2,540 |
| Occupied Slices | 726 | 743 |
| Worst Negative Slack (WNS) | +2.439 ns | +2.707 ns |
| Total Negative Slack (TNS) | 0 ns | 0 ns |
| Clock constraint | 100 MHz | 100 MHz |

These are recorded implementation results for the corresponding designs and should not be interpreted as the resource requirements of a combined dual-engine implementation.

### Timing Considerations

The archived routed timing reports indicate that the specified internal timing constraints were satisfied at the 100 MHz target.

However, external GPIO input/output timing is not fully constrained. In particular, the available reports identify missing input and output delay constraints.

Therefore, these results do **not** constitute complete timing sign-off for the external GPIO interface.

A 100 MHz clock constraint also does not establish an independently measured maximum operating frequency.

### Power Evaluation

The archived decryption implementation includes an estimated total power of approximately **0.120 W**.

This is a tool-generated estimate with limited confidence, not a direct physical measurement of FPGA board power consumption.

Future architectural comparisons should use consistent implementation settings and measurement methodologies.

---

## Repository Structure

```text
ASCON-FPGA-Implementations/
├── rtl/
│   ├── common/           # Shared ASCON components
│   ├── encryption/       # Encryption top level
│   ├── decryption/       # Decryption top level
│   └── interfaces/       # FPGA board/host wrappers
├── simulation/
│   ├── encryption/       # Encryption testbenches and scripts
│   └── decryption/       # Decryption testbenches and scripts
├── software/
│   ├── encryption/       # Raspberry Pi encryption tests
│   └── decryption/       # Raspberry Pi decryption tests
├── constraints/          # Basys 3 XDC constraints
├── verification/
│   └── KAT/              # Known-answer test vectors
├── reports/
│   ├── encryption/       # Encryption results and Vivado reports
│   ├── decryption/       # Decryption results and Vivado reports
│   └── comparisons/      # Future comparative analysis
├── docs/                 # Technical documentation
├── boards/               # Board-specific documentation
├── scripts/              # Supporting utilities
├── .gitignore
└── README.md
```

## Documentation Guide

| Location | Contents |
|---|---|
| [`rtl/README.md`](rtl/README.md) | VHDL modules and interfaces |
| [`simulation/README.md`](simulation/README.md) | Testbenches, simulation scripts, and verification |
| [`constraints/README.md`](constraints/README.md) | FPGA pin mapping and timing constraints |
| [`software/README.md`](software/README.md) | Raspberry Pi Python verification scripts |
| [`reports/README.md`](reports/README.md) | Verification, utilization, timing, and power results |
| [`docs/README.md`](docs/README.md) | Technical documentation index |
| [`docs/development_environment.md`](docs/development_environment.md) | Tool versions, development environment, and reproducibility |

---

## Version Control and Baseline

The project is maintained using Git and GitHub.

### Baseline Version

**Tag: `baseline-v1.0`**

This version preserves the organized encryption and decryption implementations, verification infrastructure, FPGA constraints, archived reports, and technical documentation.

The baseline serves as a reference point for subsequent architectural development and comparative analysis.

Future implementations should be evaluated against this baseline using consistent verification and reporting procedures.

---

## Reproducibility and Current Limitations

- The repository source tree has been reorganized. Not all simulation and build flows have been rerun from a fresh checkout.
- The full decryption KAT was successfully rerun after the repository reorganization.
- The encryption and decryption board wrappers define the same VHDL entity name, `wrapper`; they should be compiled in separate configurations or compilation libraries.
- External GPIO timing is not fully constrained by the current XDC files.
- Hardware decryption testing is currently limited to ciphertext transactions of up to 16 bytes.
- Archived power results are estimates rather than direct board measurements.
- Architectural comparisons and additional FPGA platform implementations have not yet been completed.

## Future Development

1. Complete reproducibility checks for the baseline simulation and build workflows.
2. Establish consistent methods for measuring latency, throughput, resource utilization, timing, and power.
3. Design and implement a shared encryption/decryption engine.
4. Investigate separate-engine and combined-engine architectures.
5. Compare architectural alternatives against the verified baseline.
6. Extend hardware capabilities and verification coverage.
7. Explore additional FPGA families and toolchains.
8. Document experimental results and engineering trade-offs.

---

**Project type:** Electrical / Computer Engineering Final Project  
**Hardware description language:** VHDL  
**Algorithm:** ASCON AEAD-128  
**Initial hardware platform:** Digilent Basys 3 (Xilinx Artix-7)  
**External verification host:** Raspberry Pi 5  
**Baseline version:** `baseline-v1.0`
