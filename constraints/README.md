# Basys3 FPGA Constraints

This directory contains the Xilinx Design Constraints (XDC) files for the ASCON encryption and decryption implementations targeting the Digilent Basys3 FPGA board.

## Files

| File | Intended implementation |
| --- | --- |
| `basys3_encrypt.xdc` | Encryption wrapper |
| `basys3_decrypt.xdc` | Decryption wrapper |

**Baseline status:** The two supplied XDC files are byte-for-byte identical. They use the same clock, reset, address, control, input-data, and output-data pin assignments. Keep both files to make each implementation independently reproducible.

## Clock

```tcl
create_clock -name CLK -period 10 -waveform {0 5} [get_ports CLK]
set_property -dict { PACKAGE_PIN W5 IOSTANDARD LVCMOS33 } [get_ports { CLK }]
```

- FPGA clock input: `CLK`, package pin `W5`.
- Requested clock period: **10 ns** (nominal **100 MHz**).
- Clock waveform: rising edge at 0 ns, falling edge at 5 ns.
- This is a **timing constraint**, not proof of timing closure. Check post-implementation timing reports before claiming 100 MHz operation.

## Reset

| Signal | Basys3 source | FPGA package pin | I/O standard |
| --- | --- | --- | --- |
| `RESET` | Center pushbutton | `U18` | `LVCMOS33` |

The XDC specifies the physical pin but does not specify the reset polarity or internal reset behavior; consult the relevant wrapper RTL.

## PMOD Pin Assignments

### PMOD JA — 8-bit input bus

| FPGA port | Package pin |
| --- | --- |
| `DATA_IN[0]` | `J1` |
| `DATA_IN[1]` | `L2` |
| `DATA_IN[2]` | `J2` |
| `DATA_IN[3]` | `G2` |
| `DATA_IN[4]` | `H1` |
| `DATA_IN[5]` | `K2` |
| `DATA_IN[6]` | `H2` |
| `DATA_IN[7]` | `G3` |

### PMOD JB — 8-bit output bus

| FPGA port | Package pin |
| --- | --- |
| `DATA_OUT[0]` | `A14` |
| `DATA_OUT[1]` | `A16` |
| `DATA_OUT[2]` | `B15` |
| `DATA_OUT[3]` | `B16` |
| `DATA_OUT[4]` | `A15` |
| `DATA_OUT[5]` | `A17` |
| `DATA_OUT[6]` | `C15` |
| `DATA_OUT[7]` | `C16` |

### PMOD JC — control and 6-bit address bus

| FPGA port | Package pin |
| --- | --- |
| `TO_READ` | `K17` |
| `TO_WRITE` | `M18` |
| `ADDRESS[0]` | `N17` |
| `ADDRESS[1]` | `P18` |
| `ADDRESS[2]` | `L17` |
| `ADDRESS[3]` | `M19` |
| `ADDRESS[4]` | `P17` |
| `ADDRESS[5]` | `R18` |

All mapped ports use `IOSTANDARD LVCMOS33`.

**Important:** The table lists **FPGA package pin names**, not physical PMOD header position numbers or Raspberry Pi GPIO numbers. For wiring, cross-reference the official Basys3 PMOD pinout and the software GPIO mapping. Connect a common ground between boards, use 3.3 V logic levels, and do not connect 5 V GPIO signals to the FPGA I/O pins.

## Configuration Properties

Both files contain:

```tcl
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
```

These are device configuration properties. They do not establish a power connection between the FPGA board and an external controller.

## Timing Constraint Coverage and Limitations

The supplied XDC files define a clock but leave the `set input delay` and `set output delay` sections empty. Accordingly, the constraints do **not** specify external interface arrival times, output requirements, or a complete GPIO timing budget. No asynchronous clock-group or false-path exceptions are present in these files.

Before declaring the FPGA-to-Raspberry Pi interface fully timing-verified, review the wrapper's synchronization and handshaking design and add justified interface timing constraints where applicable. Do not add arbitrary delay values or timing exceptions simply to suppress violations.

## Reproducibility Checklist

1. Select the intended top-level wrapper and the matching XDC file in Vivado.
2. Record the FPGA part, Vivado version, synthesis and implementation strategies, and tool settings in the project documentation.
3. Run synthesis and implementation; archive utilization, timing, and DRC reports for **each** implementation.
4. Record the actual post-implementation worst negative slack (WNS) and whether timing constraints are met.
5. Check the generated pinout and physical PMOD wiring before connecting the Raspberry Pi.
6. Commit the XDC files and documentation together with the verified RTL revision; tag the encryption and decryption baselines.

See `../rtl/README.md`, `../simulation/README.md`, and `../reports/README.md` (when available) for the associated design, verification, and implementation documentation.
