# ASCON FPGA — Verification and Implementation Reports

This directory archives verification results and AMD/Xilinx Vivado reports for the ASCON-AEAD128 encryption and decryption implementations on the Digilent Basys3 FPGA board.

## Report provenance

- **Tool:** Vivado **2024.1**, Windows 64-bit, build **5076996** (as recorded in both report sets).
- **Target FPGA:** **XC7A35T-1CPG236C** (Artix-7 / Basys3).
- **Top-level implementation entity:** `wrapper` (encryption and decryption are built separately).
- **Clock constraint:** `CLK`, **10.000 ns / 100 MHz**.
- **Measurements:** The resource and timing comparisons below use **routed implementation** reports, not synthesis estimates.
- **Source:** `encryption/vivado/` and `decryption/vivado/` contain the original reports. Keep the original files unmodified.

## Implementation comparison (routed)

| Metric | Encryption | Decryption |
|---|---:|---:|
| Slice LUTs | 1,986 | 2,159 |
| Slice registers (flip-flops) | 2,521 | 2,540 |
| Occupied slices | 726 | 743 |
| Setup WNS (ns) | +2.439 | +2.707 |
| Setup TNS (ns) | 0.000 | 0.000 |
| Hold WHS (ns) | +0.036 | +0.017 |
| Target clock (MHz) | 100 | 100 |
| Estimated total on-chip power (W) | 0.113 | 0.120 |

Both routed reports state that **all user-specified timing constraints are met**. These figures describe the **full wrapper-based implementation**, not only the standalone cryptographic core. Power estimates have **low confidence** according to the Vivado reports and must not be presented as measured board power.

**Important timing limitation:** Both routed timing summaries report `TIMING-18`: **17 input ports without input delay** and **8 output ports without output delay**. The successful timing result applies to constrained paths and does **not** establish full external GPIO/PMOD interface timing closure. Do not interpret positive WNS as an independently measured maximum operating frequency.

## Hardware verification logs

### Encryption

File: `encryption/ascon_v2_results_1089.txt`

- Interface: Raspberry Pi 5 GPIO ↔ Basys3 encryption wrapper.
- Reference: `verification/KAT/LWC_AEAD_KAT_128_128.txt`.
- Result: **1,089 / 1,089 KAT cases passed**.
- The log includes ciphertext and authentication tag comparisons and FPGA active-cycle counts.

### Decryption and authentication

File: `decryption/ascon_decrypt_results_with_negative.txt`

- Interface: Raspberry Pi 5 GPIO ↔ Basys3 decryption wrapper.
- Requested KAT range: **1,089** vectors.
- Supported vectors (plaintext length ≤ 16 bytes): **561**.
- Unsupported/skipped vectors (plaintext length > 16 bytes): **528**.
- Each supported vector was tested with a **valid tag** and a **corrupted tag**.
- Result: **1,122 / 1,122 individual hardware tests passed**, **0 failed**.
- Negative tests verify rejection of invalid tags and suppression of plaintext output.
- Skipped vectors are **not** counted as passes. The hardware test script supports a single ciphertext block per transaction; the decryption RTL's broader ModelSim verification is documented separately.

The hardware logs measure FPGA active cycles separately from Raspberry Pi GPIO transfer time. Do not treat active-cycle counts as end-to-end throughput or latency.

## Suggested repository layout

```text
reports/
├── README.md
├── encryption/
│   ├── ascon_v2_results_1089.txt
│   └── vivado/
│       ├── 01_utilization.rpt
│       ├── 03_timing_summary.rpt
│       ├── 06_clock_utilization.rpt
│       ├── 07_power.rpt
│       ├── 13_control_sets.rpt
│       ├── 14_io.rpt
│       ├── 15_synth_utilization.rpt
│       └── 17_synth_timing.rpt
├── decryption/
│   ├── ascon_decrypt_results_with_negative.txt
│   └── vivado/
│       ├── impl_utilization.txt
│       ├── impl_timing_summary.txt
│       ├── impl_clock_utilization.txt
│       ├── impl_power.txt
│       ├── impl_control_sets.txt
│       ├── impl_io.txt
│       ├── synth_utilization.txt
│       └── synth_timing_summary.txt
└── comparisons/
```

The tree lists the report files supplied for this documentation pass; verify their placement in GitHub before tagging a baseline.

## Reproducibility and interpretation

1. Check out the intended Git tag/commit, ensuring the RTL and matching XDC are from the same snapshot.
2. Record the exact Vivado version, target device, top entity, synthesis/implementation strategies, constraints and any Tcl/build scripts.
3. Build **encryption and decryption separately**: their interface sources both declare an entity named `wrapper`.
4. Compare **post-route** utilization and timing to the archived reports, and rerun the appropriate ModelSim KAT suites (`simulation/README.md`).
5. Hardware KAT logs are evidence of the recorded runs, not a guarantee that any future build or rewiring will pass without retesting.

**Baseline items still to verify:** synthesis/implementation strategy settings, full build commands or reproducible project scripts, simulator version, and exact source-to-report correspondence. These cannot be reconstructed from the summary reports alone.

## Related documentation

- [`../rtl/README.md`](../rtl/README.md) — VHDL architecture and modules.
- [`../simulation/README.md`](../simulation/README.md) — simulation testbenches and KAT runs.
- [`../constraints/README.md`](../constraints/README.md) — FPGA pin assignments and timing constraints.
- [`../software/README.md`](../software/README.md) — Raspberry Pi test scripts.
