# ASCON FPGA — Simulation and Verification

This directory contains ModelSim testbenches and Tcl `.do` scripts for the encryption and decryption implementations of **Ascon-AEAD128** (NIST SP 800-232), including FPGA wrapper integration and authentication-failure tests.

## Prerequisites

- A VHDL-2008-capable ModelSim/Questa installation.
- The repository's `rtl/` and `verification/KAT/` directories.
- The reference vectors at `verification/KAT/LWC_AEAD_KAT_128_128.txt`.

**Run all scripts from the repository root**, not from inside `simulation/`, because source and KAT paths are relative to that directory.

Example in the ModelSim Transcript:

```tcl
cd {C:/FPGA_Projects/ASCON-FPGA-Implementations}
do simulation/encryption/run_v2_full.do
```

Replace the `cd` path with the location of your clone.

## Directory contents

```text
simulation/
├── README.md
├── encryption/
│   ├── run_v2_full.do
│   ├── run_v2_perf.do
│   ├── tb_wrapper_v2.vhd
│   ├── tb_wrapper_v2_full.vhd
│   └── tb_wrapper_v2_perf.vhd
└── decryption/
    ├── run_decrypt.do
    ├── run_decrypt_auth_all.do
    ├── run_decrypt_negative.do
    ├── run_wrapper_decrypt.do
    ├── tb_ascon_decrypt_top_level.vhd
    ├── tb_ascon_decrypt_negative.vhd
    └── tb_wrapper_decrypt.vhd
```

## How to run the verified suites

Execute the following commands **one at a time** in the ModelSim Transcript, from the repository root:

| Area | Command | Purpose |
| --- | --- | --- |
| Encryption | `do simulation/encryption/run_v2_full.do` | Full encryption KAT regression through the encryption wrapper |
| Encryption | `do simulation/encryption/run_v2_perf.do` | Selected encryption performance regression |
| Decryption | `do simulation/decryption/run_decrypt.do` | Full decryption-core KAT regression |
| Decryption | `do simulation/decryption/run_decrypt_negative.do` | Authentication checks in four fault modes |
| Decryption | `do simulation/decryption/run_wrapper_decrypt.do` | Decryption-wrapper integration and rejection checks |

`run_decrypt_auth_all.do` currently delegates to `run_wrapper_decrypt.do`; **it is not an additional independent suite** and does not execute all four negative KAT modes.

## Recorded baseline simulation results

Results reported from ModelSim runs on **16 November 2026**:

| Suite | Tested | Passed | Failed | Notes |
| --- | ---: | ---: | ---: | --- |
| Encryption full KAT | 1,089 | 1,089 | 0 | Full encryption regression |
| Encryption performance | 24 | 24 | 0 | Selected performance cases; not a separate timing-closure proof |
| Decryption core KAT | 1,089 | 1,089 | 0 | Correct decryption against reference vectors |
| Decryption negative mode 0 | 1,089 | 1,089 | 0 | Unmodified, valid inputs accepted |
| Decryption negative mode 1 | 1,089 | 1,089 | 0 | Modified authentication tag rejected |
| Decryption negative mode 2 | 1,056 | 1,056 | 0 | Modified ciphertext rejected |
| Decryption negative mode 3 | 1,056 | 1,056 | 0 | Modified associated data rejected |
| Decryption wrapper integration | 8 | 8 | 0 | Five valid and three corrupted-input scenarios |

The four negative-test modes total **4,290 passing test cases**. Modes 2 and 3 skip 33 KAT vectors each because the corresponding ciphertext or associated-data field is empty. These skips are expected, not failures.

The wrapper integration suite includes tests that reject modified tags, ciphertext, and associated data. The wrapper's plaintext-hiding behavior on authentication failure is a separate property from the decryption core's `TAG_VALID` indication.

**Scope:** These are functional simulation results, not proof of FPGA hardware operation, physical timing closure, side-channel resistance, or cryptographic security certification.

## Testbench and build notes

- The full encryption testbench file `tb_wrapper_v2_full.vhd` defines the entity `tb_wrapper_v2`; `run_v2_full.do` therefore loads `work.tb_wrapper_v2`. This is intentional.
- `tb_wrapper_v2.vhd` is an additional shorter testbench with the **same entity name** as the full testbench. Do not compile both into the same `work` library and expect them to coexist; the most recently compiled definition takes precedence. It is not independently invoked by the two current encryption `.do` scripts.
- Both `rtl/interfaces/wrapper_encrypt.vhd` and `rtl/interfaces/wrapper_decrypt.vhd` define an entity named `wrapper`. Each script compiles only the wrapper relevant to its suite. Do not compile both wrappers together into the same `work` library.
- The decryption KAT scripts read `verification/KAT/LWC_AEAD_KAT_128_128.txt`; keep this path intact or adjust it consistently if reorganizing the repository.
- The decryption core script supports `FIRST_COUNT` and `LAST_COUNT` settings for targeted vector runs; the baseline full run uses counts 1 through 1089.
- Some testbenches terminate with `std.env.finish`; ModelSim may print `Break in Process` after a successful summary. Assess the `TESTED`, `PASSED`, and `FAILED` lines rather than interpreting that message alone as a failure.

## Reproducing and preserving evidence

1. Check out the intended Git tag or commit.
2. Record the ModelSim/Questa version and operating environment.
3. Run the five independent suites above from the repository root.
4. Confirm the test counts and zero failures against the table.
5. Preserve the console summaries and relevant full logs under `reports/` (avoid committing generated simulator libraries, temporary waveforms, or large disposable build outputs).
6. For synthesis, implementation, utilization, and timing measurements, consult the separate Vivado reports and environment documentation; simulation results alone do not establish those metrics.

The exact tool versions, FPGA part, clock constraints, synthesis strategy, and Vivado report provenance should be recorded separately before declaring the full repository baseline frozen.
