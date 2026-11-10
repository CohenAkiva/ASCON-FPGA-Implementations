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

The project is under active development.

The initial work focuses on the Xilinx Basys 3 platform, including ASCON encryption/decryption development, functional verification, and integration with FPGA control and communication logic.

Additional architectural variants, platform implementations, and comparative measurements will be added as development progresses.

## Future Work

Planned extensions include:

- Refinement and verification of encryption/decryption architectures.
- Evaluation of shared-engine and dual-engine implementations.
- Integration with additional FPGA platforms.
- Comparative resource and timing analysis.
- Hardware testing and documentation of experimental results.

## Documentation

This repository is intended to include VHDL source code, testbenches, FPGA constraints, relevant implementation scripts, verification results, architecture diagrams, and technical documentation.

---

**Project Type:** Electrical / Computer Engineering Final Project

**Hardware Description Language:** VHDL

**Cryptographic Algorithm:** ASCON

**Primary Development Platform:** Xilinx Artix-7 (Digilent Basys 3)
