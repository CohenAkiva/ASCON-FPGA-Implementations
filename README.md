# ASCON FPGA Implementations

## Project Overview

This project focuses on the design, implementation, verification, and evaluation of hardware architectures for the **ASCON authenticated encryption algorithm** using VHDL on multiple FPGA platforms.

The project aims to develop configurable hardware implementations supporting authenticated encryption and decryption, investigate different architectural approaches, and evaluate their performance and resource utilization across FPGA technologies.

The initial development platform is the **Digilent Basys 3**, based on a Xilinx Artix-7 FPGA. Future development is planned to include Intel (Altera) FPGA platforms and potentially additional FPGA families.

## Project Objectives

The main objectives of this project are:

1. **Hardware Implementation:** Design and implement ASCON authenticated encryption and decryption in VHDL.
2. **Functional Verification:** Verify the implementations using simulation, testbenches, and official Known Answer Tests (KATs).
3. **Architectural Exploration:** Investigate alternative architectures, including a shared cryptographic engine and separate encryption/decryption engines.
4. **FPGA Integration:** Integrate the ASCON hardware with board-specific interfaces and control logic.
5. **Performance Evaluation:** Analyze FPGA resource utilization, timing, latency, and throughput.
6. **Cross-Platform Comparison:** Compare implementations across FPGA platforms and development toolchains.

## Target FPGA Platforms

| Platform | FPGA Family | Development Tools | Status |
|---|---|---|---|
| Digilent Basys 3 | Xilinx Artix-7 | AMD Vivado | Initial development |
| Intel (Altera) FPGA board | To be determined | Intel Quartus Prime | Planned |
| Additional FPGA platforms | To be determined | Platform-dependent | Potential future work |

## Hardware Architecture

The project explores multiple hardware implementation strategies.

### Shared-Engine Architecture

A single cryptographic processing engine is shared between encryption and decryption operations.

This approach is intended to investigate potential reductions in hardware resource utilization through resource sharing.

### Dual-Engine Architecture

Separate processing engines are implemented for encryption and decryption.

This approach is intended to investigate architectural parallelism, resource requirements, and performance trade-offs.

The exact implementation and comparison methodology will be refined as development progresses.

## ASCON Processing Architecture

The ASCON implementation is based on a 320-bit internal state and a round-based permutation architecture.

The permutation consists of three main transformations:

- **Addition of Round Constants (pC)**
- **Substitution Layer (pS)**
- **Linear Diffusion Layer (pL)**

The hardware design separates the cryptographic processing logic from the permutation controller, top-level control logic, and FPGA-specific interfaces where practical.

## Verification and Testing

The verification methodology includes:

- VHDL simulation and functional testbenches.
- Comparison against official ASCON Known Answer Test vectors.
- Verification of encryption and decryption operations.
- FPGA synthesis and implementation analysis.
- Hardware-level testing on the target FPGA boards.

## Performance Evaluation

The project aims to compare implementations using engineering metrics such as:

- LUT utilization.
- Flip-flop and register utilization.
- FPGA logic resource usage.
- Maximum operating frequency.
- Clock-cycle latency.
- Data throughput.
- Resource-versus-performance trade-offs.

## Project Development Status

The project is under active development, with initial encryption and decryption implementations completed for the Digilent Basys 3 FPGA platform.

### Implemented Components

- **ASCON Encryption Core:** VHDL implementation of authenticated encryption.
- **ASCON Decryption Core:** VHDL implementation of authenticated decryption and authentication-tag verification.
- **Shared Permutation Components:** Reusable round function, permutation controller, and supporting VHDL package.
- **FPGA Interface Wrappers:** Separate encryption and decryption wrappers supporting communication with a Raspberry Pi 5 through GPIO.
- **Verification Infrastructure:** VHDL testbenches, ModelSim scripts, Python-based hardware tests, and Known Answer Test vectors.
- **FPGA Implementation:** Initial synthesis, placement, routing, and implementation reports generated using AMD Vivado.

### Verification Progress

- **Encryption:** Previously validated against 1,089 KAT vectors.
- **Decryption:** Previously validated against 561 eligible KAT vectors, including positive and negative authentication tests (1,122 test executions).
- **Current limitation:** The existing decryption wrapper supports ciphertext messages of up to 16 bytes per transaction. Longer-message support remains future work.

These results refer to the previously tested implementations. Revalidation of the reorganized repository and its simulation scripts is pending.

### Next Development Stages

- Adapt simulation scripts to the new repository structure.
- Revalidate encryption and decryption implementations.
- Develop shared-engine and dual-engine architectures.
- Establish consistent performance measurement and comparison methods.
- Extend the implementations to additional FPGA platforms.

## Repository Structure

The repository is organized into the following directories:

| Directory | Description |
|---|---|
| `rtl/` | VHDL source files for ASCON encryption, decryption, shared components, and hardware interfaces. |
| `rtl/common/` | Shared ASCON package, round function, and permutation controller. |
| `rtl/encryption/` | ASCON authenticated encryption implementation. |
| `rtl/decryption/` | ASCON authenticated decryption implementation. |
| `rtl/interfaces/` | FPGA interface wrappers for communication and control. |
| `simulation/` | VHDL testbenches and ModelSim simulation scripts. |
| `software/` | Python utilities for verification and Raspberry Pi communication. |
| `constraints/` | FPGA pin assignments and timing constraints. |
| `verification/` | Known Answer Test vectors and verification resources. |
| `reports/` | Functional test results and FPGA synthesis/implementation reports. |
| `docs/` | Technical documentation and architectural descriptions. |
| `boards/` | Board-specific information and integration resources. |
| `scripts/` | Additional project scripts and utilities. |

The repository separates reusable cryptographic logic from FPGA-specific interfaces and verification infrastructure.

This organization is intended to support future architectural exploration and cross-platform FPGA implementations.

## Documentation

This repository is intended to include VHDL source code, testbenches, FPGA constraints, relevant implementation scripts, verification results, architecture diagrams, and technical documentation.

---

**Project Type:** Electrical / Computer Engineering Final Project

**Hardware Description Language:** VHDL

**Cryptographic Algorithm:** ASCON

**Primary Development Platform:** Xilinx Artix-7 (Digilent Basys 3)
