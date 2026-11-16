# Development Environment and Reproducibility

## Project scope

ASCON-AEAD128 encryption and authenticated decryption implemented in VHDL for the Digilent Basys3 FPGA development board, with a byte-oriented GPIO interface to a Raspberry Pi 5.

## Verified tools and hardware

| Item | Verified configuration | Evidence / note |
| --- | --- | --- |
| FPGA development board | Digilent Basys3 | Project target |
| FPGA device | AMD/Xilinx Artix-7 `xc7a35tcpg236-1` | Vivado implementation reports; commercial-grade board device |
| FPGA design top | `wrapper` | Vivado report design name |
| Vivado | **2024.1**, win64, build **5076996** | Headers of the supplied synthesis and implementation reports, dated 2026-11-09 |
| ModelSim | **ModelSim – Intel FPGA Starter Edition, vsim 2020.1**, Simulator 2020.02, Feb 28 2020 | User-supplied `vsim -version` output |
| FPGA clock constraint | **10.000 ns (100 MHz)**, waveform `{0 5}` | Basys3 XDC files and timing reports |
| External test controller | Raspberry Pi 5 | Python hardware-test scripts and test logs |
| Hardware test language | Python 3 | `python3` entry points in the scripts |
| Raspberry Pi GPIO packages | `gpiozero`; decryption test also imports `lgpio` through `LGPIOFactory` | Python source imports |
| Host OS for Vivado reports | Windows, 64-bit | Vivado report headers |

**Important:** Vivado and ModelSim are different products with different version numbers. The verified Vivado version for the supplied reports is **2024.1**, not 2020.1. The verified ModelSim version is **2020.1**.

## Repository organization

```text
rtl/
  common/            # Shared ASCON package, round and permutation
  encryption/        # Encryption top-level RTL
  decryption/        # Decryption top-level RTL
  interfaces/        # Board-facing encryption/decryption wrappers
simulation/
  encryption/        # Testbenches and .do scripts
  decryption/        # Testbenches and .do scripts
constraints/         # Basys3 encryption/decryption XDC files
software/
  encryption/        # Raspberry Pi encryption KAT runner
  decryption/        # Raspberry Pi decryption tests and reports
verification/KAT/   # Reference AEAD test vectors
reports/
  encryption/        # Encryption logs and Vivado reports
  decryption/        # Decryption logs and Vivado reports
docs/                # Engineering documentation
```

## FPGA constraints and interface

The two supplied Basys3 XDC files use the same package pin and clock assignments. The clock is constrained at 100 MHz. FPGA package pin names, Raspberry Pi BCM pin numbering, and physical PMOD header positions must not be confused. Follow `constraints/README.md` and inspect the current XDC and Python pin maps before connecting hardware.

The Raspberry Pi and Basys3 communicate using **3.3 V GPIO levels** and a **common ground**. Do not connect their 3.3 V power rails together. Check GPIO directions, wiring, and reset behavior before running hardware scripts.

## Simulation workflow

1. Open ModelSim and create/use the intended `work` library.
2. Compile the shared ASCON RTL and the appropriate encryption **or** decryption top-level and wrapper, followed by the matching testbench.
3. Execute the corresponding `.do` script from `simulation/encryption/` or `simulation/decryption/`, using the working directory and file paths expected by that script.
4. Preserve the transcript and final PASS/FAIL summary.

**Compilation caution:** Both interface files declare a VHDL entity named `wrapper`. Do **not** compile both variants into the same `work` library for a single test run; one may replace the other. Use separate libraries or clean/recompile the selected variant.

### Existing simulation entry points

```text
simulation/encryption/run_v2_full.do
simulation/encryption/run_v2_perf.do
simulation/decryption/run_decrypt.do
simulation/decryption/run_decrypt_auth_all.do
simulation/decryption/run_wrapper_decrypt.do
simulation/decryption/run_decrypt_negative.do
```

Refer to `simulation/README.md` and the `.do` files for exact working-directory assumptions and commands. The documentation does not claim these scripts were re-executed during preparation.

## Vivado implementation workflow

1. Select the correct RTL wrapper variant and matching XDC file.
2. Set the FPGA part to `xc7a35tcpg236-1` (or select the corresponding Basys3 board definition).
3. Run synthesis, then implementation through routing.
4. Generate and archive utilization, timing, clock utilization, I/O, control sets, and power reports.
5. Verify the implementation timing summary and review methodology warnings before generating a bitstream.
6. Archive the exact source revision, XDC, tool version, and reports under the corresponding `reports/` subdirectory.

### Timing interpretation

The supplied routed decryption timing report shows **WNS +2.707 ns** and **TNS 0.000 ns** with a **10.000 ns** clock. It also reports **17 input ports without input delay** and **8 output ports without output delay**. Thus, meeting the user-specified timing constraints does **not** establish full external GPIO interface timing closure. The `reports/README.md` provides further detail.

## Hardware-test workflow

- Load the matching encryption or decryption bitstream onto the Basys3.
- Confirm shared ground, 3.3 V logic, BCM-to-PMOD wiring, and correct GPIO directions.
- Press the Basys3 reset button when prompted by the test script.
- Run the relevant Python script from the Raspberry Pi, supplying the KAT file path as required.
- Save the generated output log and distinguish **FPGA active cycles** from wall-clock time including GPIO transfers.

Example script locations (see `software/README.md` for validated arguments and prerequisites):

```text
software/encryption/ascon_kat_v2.py
software/decryption/test_ascon_decrypt_pi.py
software/decryption/test_ascon_decrypt_report.py
verification/KAT/LWC_AEAD_KAT_128_128.txt
```

The decryption report script notes a dependency on an `active_state=True` fix in its imported GPIO interface. Confirm the deployed `test_ascon_decrypt_pi.py` version and input polarity before treating a new hardware run as verified.

## Baseline verification checklist

- [ ] Confirm that all RTL files, testbenches, Python scripts, and XDC files match the intended baseline.
- [ ] Record the complete ModelSim and Vivado versions (above).
- [ ] Re-run the desired simulation suites and archive fresh transcripts.
- [ ] Confirm that the archived Vivado reports correspond to the same RTL revision and XDC files.
- [ ] Review missing external I/O timing constraints and other methodology warnings.
- [ ] Confirm physical GPIO mapping and decryption input polarity before further hardware testing.
- [ ] Commit and push the reviewed baseline to GitHub.
- [ ] Create and document a Git tag for the frozen baseline.

## Information not yet captured

The following are **not established** by the available evidence and should be recorded if strict build reproducibility is required: exact Windows and Raspberry Pi OS releases, Python interpreter version, installed `gpiozero`/`lgpio` package versions, exact ModelSim compile command/flags, Vivado project settings/strategies, and Git commit hashes corresponding to the archived reports.
