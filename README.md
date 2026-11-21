# ASCON independent basic implementations — review candidate

Source: user-provided `ASCON_baseline_v1_0_original.zip` (tag baseline-v1.0).

**STATUS: UNVERIFIED REFACTOR.** The original tag was tested by the author; these edited files have **not** been simulated, synthesized, implemented or hardware-tested in this environment. Do not deploy as validated until re-running all tests.

## Layout
- `rtl/common`: one copy of shared package, round and permutation.
- `rtl/encryption/ASCON_TOP_LEVEL.vhd`: original encryption core, unchanged.
- `rtl/decryption/ASCON_DECRYPT_TOP_LEVEL.vhd`: original decryption core, unchanged.
- `rtl/interfaces`: separate wrappers, each still named entity `wrapper` to preserve board/XDC and testbench compatibility. **Compile in separate work libraries/projects**, not together.
- `simulation/*/run_basic.do`: one standalone testbench per implementation. Run from repository root.
- `archive`: original wrappers and metric-specific testbenches retained for reference.

## Changes
1. Deduplicated identical `ascon_pack`, `ASCON_ROUND`, `ASCON_PERMUTATION` files.
2. Removed `active_cycles`, `last_cycles`, `total_cycles` registers and related assignments/readback from each wrapper.
3. Removed address readback 54..61 (now defaults to zero, as other unsupported addresses).
4. Kept original ASCON top-level cores, FSMs, GPIO synchronizers, address map for functional data, and decryption authentication gating unchanged.
5. Separated testbench scripts. Full encryption testbench originally reads counters and is archived; basic run uses the non-metric testbench.

## Important limitations and verification
- No simulator (GHDL/ModelSim) is installed in this execution environment. No PASS is claimed.
- Decryption baseline handles up to one 16-byte ciphertext block per transaction; do not claim arbitrary-length decryption.
- Run original KATs and negative TAG tests, and check GPIO + Vivado timing on Basys3 before replacing the baseline.
- This is a minimal, conservative cleanup, **not** a full security review or functional redesign.
- Existing Raspberry Pi scripts may read cycle counters at addresses 54..61; update them if necessary before deployment.

### Run from repository root in ModelSim
`do simulation/encryption/run_basic.do` or `do simulation/decryption/run_basic.do` in separate clean work libraries.
