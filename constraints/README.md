# FPGA Constraints — ASCON Basic

## 1. Overview

This directory contains the Xilinx Design Constraints (XDC) files used for implementing the ASCON Basic encryption and decryption architectures on the Digilent Basys3 development board.

The constraint files define:

- Target clock frequency.
- Clock and reset pin assignments.
- External GPIO and PMOD pin assignments.
- Electrical I/O standards.
- FPGA configuration voltage.

Both encryption and decryption implementations use identical physical pin assignments, allowing the same Raspberry Pi wiring configuration to be used for both architectures.

## 2. Directory Structure

```text
constraints/
├── basys3_encrypt.xdc
├── basys3_decrypt.xdc
└── README.md
```

| File | Description |
|---|---|
| `basys3_encrypt.xdc` | Constraints for the encryption wrapper. |
| `basys3_decrypt.xdc` | Constraints for the decryption wrapper. |

Only the constraint file corresponding to the selected implementation should be included in each Vivado build.

## 3. Target Hardware

| Parameter | Specification |
|---|---|
| Development board | Digilent Basys3 |
| FPGA manufacturer | Xilinx |
| FPGA family | Artix-7 |
| FPGA part | xc7a35tcpg236-1 |
| Target clock frequency | 100 MHz |
| Clock period | 10 ns |
| I/O standard | LVCMOS33 |
| Configuration voltage | 3.3 V |
| External host | Raspberry Pi 5 |
| External interface | GPIO / PMOD |

## 4. Clock Constraints

The FPGA uses the onboard Basys3 oscillator as its primary clock source.

```tcl
create_clock -name CLK -period 10 -waveform {0 5} [get_ports CLK]
```

Clock pin assignment:

```tcl
set_property -dict { PACKAGE_PIN W5 IOSTANDARD LVCMOS33 } [get_ports { CLK }]
```

The defined clock properties are:

| Parameter | Value |
|---|---|
| Clock name | CLK |
| Frequency | 100 MHz |
| Period | 10 ns |
| Rising edge | 0 ns |
| Falling edge | 5 ns |
| Duty cycle | 50% |

All internal synchronous hardware operates in the FPGA clock domain.

The target clock frequency represents a design requirement. Successful operation at this frequency must be confirmed through post-implementation timing analysis.

## 5. Reset Configuration

The RESET input is connected to the Basys3 center push button.

```tcl
set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports { RESET }]
```

| Parameter | Value |
|---|---|
| Signal | RESET |
| FPGA package pin | U18 |
| Physical source | Center push button |
| Active level | High |

No external reset GPIO connection from the Raspberry Pi is required.

## 6. External Interface

The Raspberry Pi communicates with the ASCON wrapper through three PMOD connectors.

| PMOD | Function | Number of Signals | Direction |
|---|---|---:|---|
| JA | Input data bus | 8 | Raspberry Pi → FPGA |
| JB | Output data bus | 8 | FPGA → Raspberry Pi |
| JC | Address and control signals | 8 | Raspberry Pi → FPGA |

Total external communication signals: 24, excluding ground.

## 7. FPGA Pin Assignments

### PMOD JA — DATA_IN

| Signal | PMOD Pin | FPGA Package Pin | I/O Standard |
|---|---|---|---|
| DATA_IN[0] | JA1 | J1 | LVCMOS33 |
| DATA_IN[1] | JA2 | L2 | LVCMOS33 |
| DATA_IN[2] | JA3 | J2 | LVCMOS33 |
| DATA_IN[3] | JA4 | G2 | LVCMOS33 |
| DATA_IN[4] | JA7 | H1 | LVCMOS33 |
| DATA_IN[5] | JA8 | K2 | LVCMOS33 |
| DATA_IN[6] | JA9 | H2 | LVCMOS33 |
| DATA_IN[7] | JA10 | G3 | LVCMOS33 |

### PMOD JB — DATA_OUT

| Signal | PMOD Pin | FPGA Package Pin | I/O Standard |
|---|---|---|---|
| DATA_OUT[0] | JB1 | A14 | LVCMOS33 |
| DATA_OUT[1] | JB2 | A16 | LVCMOS33 |
| DATA_OUT[2] | JB3 | B15 | LVCMOS33 |
| DATA_OUT[3] | JB4 | B16 | LVCMOS33 |
| DATA_OUT[4] | JB7 | A15 | LVCMOS33 |
| DATA_OUT[5] | JB8 | A17 | LVCMOS33 |
| DATA_OUT[6] | JB9 | C15 | LVCMOS33 |
| DATA_OUT[7] | JB10 | C16 | LVCMOS33 |

### PMOD JC — Address and Control

| Signal | PMOD Pin | FPGA Package Pin | I/O Standard |
|---|---|---|---|
| TO_READ | JC1 | K17 | LVCMOS33 |
| TO_WRITE | JC2 | M18 | LVCMOS33 |
| ADDRESS[0] | JC3 | N17 | LVCMOS33 |
| ADDRESS[1] | JC4 | P18 | LVCMOS33 |
| ADDRESS[2] | JC7 | L17 | LVCMOS33 |
| ADDRESS[3] | JC8 | M19 | LVCMOS33 |
| ADDRESS[4] | JC9 | P17 | LVCMOS33 |
| ADDRESS[5] | JC10 | R18 | LVCMOS33 |

The Raspberry Pi BCM GPIO numbers and physical header pin assignments are documented in [software/README.md](../software/README.md).

## 8. Electrical Configuration

All FPGA interface signals use the LVCMOS33 I/O standard.

The configuration voltage settings are:

```tcl
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
```

Electrical precautions:

- Use compatible 3.3 V logic levels.
- Connect a common ground between the FPGA and Raspberry Pi.
- Do not connect the independent 3.3 V power rails together.
- Never apply 5 V to the communication signals.
- Disconnect power before changing physical connections.
- Verify PMOD connector orientation before connecting the boards.

## 9. Clock Domain Crossing and Synchronization

The Raspberry Pi GPIO signals are asynchronous relative to the internal 100 MHz FPGA clock.

The encryption and decryption wrappers implement two-stage synchronization for the external control signals:

- TO_READ.
- TO_WRITE.

Rising-edge detection is used to generate internal read and write events.

The synchronization mechanism reduces the probability of metastability propagation into the internal control logic.

However, the multi-bit ADDRESS and DATA_IN buses are not independently synchronized bit by bit.

The communication protocol therefore requires the Raspberry Pi to establish stable address and data values before asserting the corresponding control signal and maintain them for sufficient time during the operation.

The Python communication scripts implement settling and strobe delays for this purpose.

The synchronization architecture must be reviewed through Vivado CDC analysis and physical hardware testing.

## 10. Timing Constraint Scope

The current XDC files explicitly define the internal FPGA clock and physical I/O assignments.

However, the sections reserved for input and output delay constraints are currently empty.

The current constraint files do not explicitly define:

- External input delays.
- External output delays.
- Asynchronous input timing exceptions.
- Additional timing constraints for the GPIO communication protocol.

The external Raspberry Pi interface is asynchronous and does not provide a shared interface clock.

Appropriate timing exceptions or additional constraints should only be introduced after reviewing the actual clock-domain crossing architecture and bundled-data communication protocol.

Timing exceptions must not be used simply to suppress timing violations.

Passing internal FPGA timing analysis alone does not establish complete external GPIO timing correctness.

## 11. Vivado Implementation Procedure

Each implementation must be built independently using its corresponding RTL sources and XDC file.

### Encryption

- Top-level entity: `wrapper`
- Wrapper source: `rtl/interfaces/wrapper_encrypt.vhd`
- Constraint file: `constraints/basys3_encrypt.xdc`

### Decryption

- Top-level entity: `wrapper`
- Wrapper source: `rtl/interfaces/wrapper_decrypt.vhd`
- Constraint file: `constraints/basys3_decrypt.xdc`

Both implementations target:

```text
xc7a35tcpg236-1
```

The encryption and decryption wrappers must not be compiled together into the same active design because both declare an entity named `wrapper`.

## 12. Timing and Implementation Verification

The following reports should be generated during FPGA synthesis and implementation:

| Report | Purpose |
|---|---|
| Utilization | FPGA resource consumption. |
| Timing Summary | Setup and hold timing verification. |
| Timing Paths | Detailed critical path analysis. |
| Clock Utilization | Clock network usage. |
| CDC | Clock-domain crossing analysis. |
| Control Sets | Register control signal distribution. |
| IO | Physical I/O assignments. |
| DRC | Design rule checks. |
| Methodology | FPGA design methodology checks. |
| Power | Estimated FPGA power consumption. |

### Timing Acceptance Criteria

| Metric | Target |
|---|---|
| WNS — Worst Negative Slack | ≥ 0 ns |
| TNS — Total Negative Slack | 0 ns |
| WHS — Worst Hold Slack | ≥ 0 ns |
| THS — Total Hold Slack | 0 ns |
| Setup timing violations | None |
| Hold timing violations | None |
| Blocking DRC violations | None |
| Unconstrained paths | Identified and reviewed |
| CDC findings | Reviewed and justified |
| Bitstream generation | Successful |

All timing results must be interpreted together with timing-constraint coverage.

A successful bitstream generation does not necessarily imply that all timing requirements have been satisfied.

## 13. Verification Status

| Verification Activity | Status |
|---|---|
| Encryption and decryption XDC comparison | Completed |
| FPGA pin assignment consistency | Reviewed |
| Raspberry Pi GPIO mapping consistency | Reviewed |
| Internal clock constraint definition | Completed |
| Vivado synthesis | Pending |
| Vivado implementation | Pending |
| Post-route timing verification | Pending |
| Timing constraint coverage review | Pending |
| CDC analysis | Pending |
| Design rule checks | Pending |
| Bitstream generation | Pending |
| Physical hardware verification | Pending |

The actual implementation results will be documented after completing the Vivado build process.

## 14. Related Documentation

- [Project Overview](../README.md)
- [RTL Architecture](../rtl/README.md)
- [Simulation and Functional Verification](../simulation/README.md)
- [Raspberry Pi Software and Wiring](../software/README.md)

### External References

- [Digilent Basys3 Reference Manual](https://digilent.com/reference/basys3/refmanual)
- AMD Xilinx Vivado Design Suite User Guide: Using Constraints (UG903).
- AMD Xilinx Vivado Design Suite User Guide: Design Analysis and Closure Techniques (UG906).