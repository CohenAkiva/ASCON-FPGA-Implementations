# Project Documentation

This directory contains engineering documentation for the **ASCON FPGA Implementations** project, including encryption and authenticated decryption on the Digilent Basys3 FPGA board and Raspberry Pi 5 integration.

## Documentation index

| Document | Purpose |
| --- | --- |
| [`development_environment.md`](development_environment.md) | Verified tool versions, target hardware, clock constraint, dependencies, and reproducibility notes. |
| [`../rtl/README.md`](../rtl/README.md) | VHDL design organization and architecture. |
| [`../simulation/README.md`](../simulation/README.md) | Simulation suites, testbenches, and ModelSim run scripts. |
| [`../constraints/README.md`](../constraints/README.md) | Basys3 pin constraints and FPGA clock. |
| [`../software/README.md`](../software/README.md) | Raspberry Pi Python tools and hardware testing. |
| [`../reports/README.md`](../reports/README.md) | KAT evidence, synthesis, implementation, timing, and power reports. |

## Verification and reproducibility

The repository separates **RTL simulation**, **FPGA implementation**, and **physical hardware tests**. Passing one stage does not imply that every other stage has been verified. Read the relevant README and retain the original logs/reports for each baseline release.

For a reproducible baseline, record the exact Git commit or tag, source file versions, constraint file, tool versions, run commands, and generated report dates. Do not treat an existing report as evidence that a newly edited RTL revision has passed.

## Documentation conventions

- Paths are relative to the repository root unless otherwise noted.
- Clock periods are given in nanoseconds; frequencies are given in MHz.
- FPGA active-cycle counts exclude Raspberry Pi GPIO transfer time unless explicitly stated.
- Physical pin names in XDC files are **FPGA package pins**, not Raspberry Pi BCM GPIO numbers.
- Reported timing closure applies to the constrained paths only; external I/O timing constraints must be reviewed separately.

## Baseline status

Documentation is being prepared for a version-controlled baseline. Final Git commit identifiers and release tags should be added only after all sources, constraints, scripts, and evidence have been reviewed and committed.
