# ASCON FPGA Implementations

## Project Overview

This electrical/computer engineering final project investigates the design, implementation, verification, and evaluation of **ASCON authenticated encryption and decryption** hardware in VHDL. The initial platform is the **Digilent Basys 3 (Xilinx Artix-7)**, with a **Raspberry Pi 5** providing a GPIO-based test and control interface.

The long-term goal is to compare different hardware architectures and, where practical, different FPGA families and toolchains. **Shared-engine and dual-engine architectural comparisons are planned research directions, not completed results.**

## Project Objectives

1. Implement ASCON authenticated encryption and decryption in VHDL.
2. Verify functionality using simulation, testbenches, and known-answer tests (KATs).
3. Integrate the designs with FPGA board interfaces and external host control.
4. Measure resource utilization, timing, latency, and hardware behavior.
5. Explore shared-engine versus separate-engine architectures.
6. Investigate portability to additional FPGA platforms, including Intel FPGA devices.

## Current Implementations

| Component | Description | Status |
|---|---|---|
| Encryption core | ASCON authenticated encryption and tag generation | Implemented and previously verified |
| Decryption core | ASCON authenticated decryption and tag verification | Implemented and previously verified |
| Common permutation logic | Reusable package, round function, and permutation controller | Implemented |
| Encryption interface | Basys 3 GPIO wrapper for Raspberry Pi communication | Implemented and hardware-tested |
| Decryption interface | Basys 3 GPIO wrapper with authentication status and controlled plaintext release | Implemented and hardware-tested |
| Shared-engine / dual-engine comparison | Alternative architectures and quantitative trade-off analysis | Planned |
| Other FPGA families | Porting and comparative implementation | Planned |

### ASCON Processing Architecture

The ASCON permutation operates on a **320-bit internal state** and applies three transformations in each round:

- **pC:** addition of round constants;
- **pS:** nonlinear substitution layer;
- **pL:** linear diffusion layer.

The VHDL design separates the round function, permutation controller, algorithm-level control, and board-specific interface logic where practical. See [`rtl/README.md`](rtl/README.md) for the RTL organization.

## Verification Results

The following are **recorded results from earlier runs of the implementations**, not a claim that all scripts have been rerun after reorganizing the repository.

| Verification activity | Recorded outcome | Scope |
|---|---|---|
| Encryption simulation KAT | **1,089 / 1,089 passed** | Full encryption KAT run |
| Decryption core simulation KAT | **1,089 / 1,089 passed** | Full decryption core KAT run |
| Encryption Raspberry Pi / FPGA hardware KAT | **1,089 / 1,089 passed** | Recorded hardware test report |
| Decryption Raspberry Pi / FPGA hardware tests | **1,122 / 1,122 passed** | 561 eligible vectors tested with valid and corrupted tags |

**Hardware decryption scope:** The current decryption wrapper processes at most **16 bytes of ciphertext per transaction**. In the recorded hardware KAT run, **528 longer vectors were skipped**, not passed. The decryption core's simulation coverage and the hardware wrapper's coverage are therefore different.

For original logs, test commands, and interpretation, consult [`simulation/README.md`](simulation/README.md), [`software/README.md`](software/README.md), and [`reports/README.md`](reports/README.md).

## FPGA Implementation and Timing

- **Development board:** Digilent Basys 3.
- **FPGA:** Xilinx Artix-7 XC7A35T-1CPG236C.
- **Target clock constraint:** 100 MHz (10 ns period).
- **Implementation tool:** AMD Vivado **2024.1**, as identified in the archived implementation reports.
- **Simulator:** ModelSim – Intel FPGA Starter Edition **2020.1** (`vsim 2020.02`, February 28, 2020).

The archived routed timing reports indicate that the **specified internal timing constraints were met** at the 100 MHz target. However, the reports identify **missing external input/output delay constraints** for the GPIO interface. Accordingly, the results must **not** be interpreted as complete timing sign-off for all external interface paths.

Resource utilization, timing slack, and estimated power must be compared using the relevant reports for each build. See [`reports/README.md`](reports/README.md) and [`docs/development_environment.md`](docs/development_environment.md).

## Repository Structure

```text
ASCON-FPGA-Implementations/
├── rtl/
│   ├── common/           # ASCON package, round and permutation
│   ├── encryption/       # Encryption top level
│   ├── decryption/       # Decryption top level
│   └── interfaces/       # Board/host wrappers
├── simulation/
│   ├── encryption/       # Encryption testbenches and .do scripts
│   └── decryption/       # Decryption testbenches and .do scripts
├── software/
│   ├── encryption/       # Raspberry Pi encryption verification
│   └── decryption/       # Raspberry Pi decryption verification
├── constraints/          # Basys 3 XDC constraints
├── verification/
│   └── KAT/              # Known-answer test vectors
├── reports/
│   ├── encryption/       # Encryption test logs and Vivado reports
│   ├── decryption/       # Decryption test logs and Vivado reports
│   └── comparisons/      # Future comparisons
├── docs/                 # Technical documentation and environment
├── boards/               # Board-specific information
└── scripts/              # Supporting utilities
```

## Documentation Guide

| Location | Contents |
|---|---|
| [`rtl/README.md`](rtl/README.md) | VHDL module structure and interfaces |
| [`simulation/README.md`](simulation/README.md) | Testbenches, simulation scripts, and verification flow |
| [`constraints/README.md`](constraints/README.md) | Basys 3 pin mapping and timing constraints |
| [`software/README.md`](software/README.md) | Raspberry Pi Python scripts and GPIO testing |
| [`reports/README.md`](reports/README.md) | Hardware results, utilization, timing, and power reports |
| [`docs/README.md`](docs/README.md) | Technical documentation index |
| [`docs/development_environment.md`](docs/development_environment.md) | Tool versions, hardware, and reproducibility notes |

## Reproducibility and Current Limitations

- The source tree has been reorganized. **Simulation scripts and build instructions should be revalidated from the current repository paths** before treating a new checkout as fully reproducible.
- The two FPGA interface wrappers may define the same VHDL entity name (`wrapper`); build each configuration in its own compilation context or library as described in the simulation documentation.
- Hardware GPIO timing is not fully constrained by the available XDC files; external interface timing requires separate consideration.
- Hardware decryption testing is currently limited to ciphertext blocks of up to 16 bytes per transaction.
- Archived power figures are tool estimates, not direct board power measurements.
- Do not equate a **100 MHz clock constraint** with an independently measured maximum operating frequency.

## Planned Development

1. Revalidate the reorganized encryption and decryption simulation flows.
2. Freeze reproducible baseline revisions with source files, constraints, scripts, KAT logs, and Vivado reports.
3. Establish consistent measurement methods for latency, throughput, resource usage, and power.
4. Investigate shared-engine and separate-engine architectures.
5. Extend hardware support and compare implementations on additional FPGA platforms.

---

**Project type:** Electrical / Computer Engineering Final Project  
**Hardware description language:** VHDL  
**Algorithm:** ASCON authenticated encryption  
**Initial platform:** Digilent Basys 3 (Xilinx Artix-7)
