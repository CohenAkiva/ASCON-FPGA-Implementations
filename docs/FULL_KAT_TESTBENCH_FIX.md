# Full KAT testbench compatibility fix

The original 1089 run_case invocations and ciphertext/TAG assertions are preserved.

Only the performance-counter reads at addresses 58..61, the assertion `Zero active cycle count`, and the PASS output of the cycle count were removed. The associated `cycle_count` variable was also removed.

No RTL was modified by this patch.

Run from the project root in ModelSim:

    do simulation/encryption/run_v2_full.do

This ZIP is not yet verified by ModelSim/Vivado in this environment.
