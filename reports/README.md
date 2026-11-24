# Basic Implementation Reports

## Scope and Provenance

This directory records the ASCON Basic encryption and authenticated-decryption implementations on the Basys3 board (Artix-7, `xc7a35tcpg236-1`). Both builds use Vivado 2024.1, VHDL-2008, and a 100 MHz target clock (10 ns).

- Branch: `basic`
- RTL source commit recorded by both builds: `15328f4e1cbe695037201f577145071b68a59101`
- Build date: 2026-11-24
- Encryption: [20261124_163808](encryption/20261124_163808/)
- Decryption: [20261124_165115](decryption/20261124_165115/)

The working trees were not clean during the builds; consult each `build_info.txt`. The scripts preserve local snapshots of the actual RTL and XDC inputs.

A subsequent GitHub commit comparison confirmed that the committed RTL, XDC, and simulation source files remained unchanged from the recorded baseline.

## Resource Utilization

| Metric | Encryption | Decryption | DEC vs ENC |
|---|---:|---:|---:|
| Synthesized Slice LUTs | 1,924 | 2,101 | +9.20% |
| Implemented Slice LUTs | 1,899 (9.13%) | 2,069 (9.95%) | +8.95% |
| Slice registers | 2,425 (5.83%) | 2,444 (5.88%) | +0.78% |
| Occupied slices | 667 | 684 | +2.55% |
| SLICEL | 553 | 567 | +14 |
| SLICEM | 114 | 117 | +3 |
| Unique control sets | 67 | 82 | +15 |
| DSPs | 0 | 0 | 0 |
| BRAM tiles | 0 | 0 | 0 |
| Bonded IOBs | 26 | 26 | 0 |

Sources: `synth_utilization.rpt` and `impl_utilization.rpt`.

Use the post-route figures for cross-variant comparisons. Synthesis primitive counts are not equivalent to physical LUT utilization: compatible functions may share a LUT.

The reported Slice LUT count decreases by 25 and 32 respectively between synthesis and implementation.

The device has 20,800 LUTs and 41,600 registers. Occupied slice counts are taken directly from the implementation report; do not infer slice capacity from its percentage column without verifying the device resource definition.

### Hierarchical Utilization (Post-Route)

| Hierarchy | ENC LUTs | DEC LUTs | ENC FFs | DEC FFs |
|---|---:|---:|---:|---:|
| Entire wrapper | 1,899 | 2,069 | 2,425 | 2,444 |
| ASCON core including permutation | 1,575 | 1,715 | 1,695 | 1,696 |
| AEAD core excluding permutation | 645 | 703 | 1,042 | 1,043 |
| Permutation | 930 | 1,013 | 653 | 653 |

Source: `impl_hierarchical_utilization.rpt`.

Hierarchical LUT counts can overlap because of shared resources. The shared permutation RTL may map differently in the two complete designs.

The aggregate decryption overhead is 170 LUTs and 19 registers; this is not an isolated measurement of tag-comparison logic.

## Timing Analysis

| Metric | Encryption | Decryption |
|---|---:|---:|
| Target clock | 100 MHz | 100 MHz |
| WNS (ns) | 2.052 | 2.868 |
| TNS (ns) | 0.000 | 0.000 |
| WHS (ns) | 0.021 | 0.034 |
| THS (ns) | 0.000 | 0.000 |
| WPWS (ns) | 4.500 | 4.500 |
| Setup / hold failing endpoints | 0 / 0 | 0 / 0 |
| Estimated Fmax (MHz) | 125.82 | 140.21 |

Both builds meet the user-specified timing constraints.

Fmax is an approximate extrapolation, `1000 / (10 - WNS)` in MHz, not a validated operating frequency.

A new constrained implementation is required to establish operation at a higher clock rate. Clock frequency alone does not establish message throughput or latency.

### Critical Setup Paths

| Metric | Encryption | Decryption |
|---|---|---|
| Source | `u_ascon/current_top_state_reg[1]/C` | `u_ascon/PERM_INST/STATE_OUT_reg[317]/C` |
| Destination | `u_ascon/perm_state_in_reg[231]/D` | `u_ascon/DATA_OUT_reg[5]/CE` |
| Logic levels | 1 LUT5 | 14 (11 CARRY4, 1 LUT4, 2 LUT6) |
| Data path delay | 7.827 ns | 6.852 ns |
| Logic delay | 0.580 ns | 2.965 ns |
| Routing delay | 7.247 ns (92.59%) | 3.887 ns (56.73%) |

Source: `impl_timing_summary.rpt`.

Encryption is routing-dominated; decryption has a deeper logic path but a shorter total delay.

Future work may investigate high-fanout control nets and carry-chain logic. The precise function of the carry chain requires netlist tracing.

## Estimated Power

| Metric | Encryption | Decryption |
|---|---:|---:|
| Total on-chip power | 112 mW | 119 mW |
| Device static | 72 mW | 72 mW |
| Dynamic | 40 mW | 48 mW |
| Confidence | Low | Low |

Source: `impl_power.rpt`.

Rounded components may not sum to the reported total.

These are tool estimates, not board measurements. Use representative switching activity (e.g. SAIF) for improved estimates.

## Design Checks and Limitations

Both builds report zero DRC violations and 25 TIMING-18 methodology warnings (17 input and 8 output ports without delay constraints).

The Raspberry Pi GPIO interface is asynchronous to the FPGA clock. Internal timing closure does not establish external interface timing or CDC safety.

Review strobe synchronizers, bundled address/data stability, reset release, and external timing assumptions.

The CDC reports are not exhaustive evidence of safety. Do not add arbitrary delays merely to suppress warnings.

## Report Inventory

Each build directory contains the following 18 files:

### Build Metadata

- `build_info.txt`

### Synthesis Reports

- `synth_utilization.rpt`
- `synth_hierarchical_utilization.rpt`
- `synth_timing_summary.rpt`
- `synth_timing_paths.rpt`
- `synth_control_sets.rpt`

### Implementation Reports

- `impl_utilization.rpt`
- `impl_hierarchical_utilization.rpt`
- `impl_timing_summary.rpt`
- `impl_timing_paths.rpt`
- `impl_control_sets.rpt`
- `impl_clock_utilization.rpt`
- `impl_io.rpt`
- `impl_power.rpt`
- `impl_drc.rpt`
- `impl_methodology.rpt`
- `impl_cdc.rpt`
- `impl_check_timing.rpt`

## Reference Bitstreams

Both reference bitstream files are present in the GitHub repository.

| Direction | Build ID | File | Size |
|---|---|---|---:|
| Encryption | 20261124_163808 | `ascon_basic_encrypt.bit` | 2,192,115 bytes |
| Decryption | 20261124_165115 | `ascon_basic_decrypt.bit` | 2,192,115 bytes |

The bitstreams are stored separately in the [bitstreams directory](../bitstreams/README.md), alongside their corresponding build identifiers.

## Verification Status

| Verification Stage | Encryption | Decryption |
|---|---|---|
| Synthesis | Completed | Completed |
| Placement and routing | Completed | Completed |
| Internal timing at 100 MHz | Passed | Passed |
| DRC | Passed | Passed |
| Implementation reports | Available | Available |
| Bitstream file availability | Confirmed | Confirmed |
| External interface timing review | Pending | Pending |
| Physical FPGA programming | Pending | Pending |
| Raspberry Pi functional testing | Pending | Pending |
| Physical power measurement | Pending | Pending |

Both implementations provide a documented reference baseline for subsequent architectural and performance comparisons.

Physical hardware verification remains pending. Successful synthesis, implementation, and bitstream availability do not independently establish hardware-level functional correctness.

Preserve this baseline for later comparisons with Performance and Extended Decryption.

## Related Documentation

- [Build Instructions](../scripts/README.md)
- [FPGA Constraints](../constraints/README.md)
- [FPGA Bitstreams](../bitstreams/README.md)
- [Simulation Documentation](../simulation/README.md)
- [Software Documentation](../software/README.md)
- [Main Project Documentation](../README.md)

---

**ASCON Basic — Reference Implementation Results**