# Change log / audit

- **Unchanged byte-for-byte**: common ASCON package, round, permutation; encryption and decryption top-level; selected functional testbenches; KAT vectors; XDC and Raspberry Pi scripts.
- **Edited**: wrapper_encrypt.vhd and wrapper_decrypt.vhd: only external performance counter machinery removed.
- **Moved to archive**: original wrappers and counter-dependent encryption testbenches.
- **Added**: separate basic compile/run scripts and explanatory README.
- **Removed from active RTL**: duplicate common modules previously under rtl/encryption/.

Original `baseline-v1.0` archive remains untouched.

## Restored original exhaustive encryption testbench
- Restored `simulation/encryption/tb_wrapper_v2_full.vhd` and `run_v2_full.do` byte-for-byte from baseline-v1.0.
- Moved reduced testbench and run script to `archive/reduced_testbench/`.
- Full original testbench enumerates 1089 KAT cases; execution on simplified wrapper remains to be verified.
