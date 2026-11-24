# Vivado Build Automation — Basic

## Requirements

- Vivado 2024.1 with Artix-7 device support.
- Git for Windows or GitHub Desktop.
- Repository checked out on the `basic` branch.
- Two separate, empty RTL projects targeting `xc7a35tcpg236-1`.

The reference builds use VHDL-2008, top entity `wrapper`, and the 100 MHz clock defined by the corresponding XDC. Keep Vivado projects outside the repository to avoid tracking generated project files.

## Scripts and inputs

| Script | Core | Wrapper | Constraints |
|---|---|---|---|
| `build_encrypt.tcl` | `rtl/encryption/ASCON_TOP_LEVEL.vhd` | `rtl/interfaces/wrapper_encrypt.vhd` | `constraints/basys3_encrypt.xdc` |
| `build_decrypt.tcl` | `rtl/decryption/ASCON_DECRYPT_TOP_LEVEL.vhd` | `rtl/interfaces/wrapper_decrypt.vhd` | `constraints/basys3_decrypt.xdc` |

Both scripts load `rtl/common/ascon_pack.vhd`, `ASCON_ROUND.vhd` and `ASCON_PERMUTATION.vhd`. Do not compile both wrappers in one project because they share the same entity name.

## Running a build

1. Switch to `basic` in GitHub Desktop. Prefer committing the intended source changes before building; otherwise inspect the recorded working-tree status.
2. Create a fresh empty RTL project named `ASCON_Basic_Encryption` or `ASCON_Basic_Decryption`, with the part specified above. Select **Do not specify sources at this time**.
3. Open the corresponding project in Vivado and run one of the following Tcl Console commands (adjust the repository path if necessary):

```tcl
source "C:/FPGA_Projects/ASCON-FPGA-Implementations/scripts/build_encrypt.tcl"
```

```tcl
source "C:/FPGA_Projects/ASCON-FPGA-Implementations/scripts/build_decrypt.tcl"
```

The decryption script also checks the exact project name. The encryption script checks the branch, part and empty source sets, but does not enforce the project name.

### Git not found

The decryption script automatically searches the standard GitHub Desktop installation directory if Git is not on PATH. The original encryption script requires Git on PATH. If necessary, execute this in the Vivado Tcl Console before running encryption:

```tcl
set candidates [glob -nocomplain -directory $::env(LOCALAPPDATA) GitHubDesktop/app-*/resources/app/git/cmd/git.exe]
if {[llength $candidates] == 0} {error "GitHub Desktop Git not found"}
set git_dir [file dirname [lindex [lsort -decreasing -dictionary $candidates] 0]]
set ::env(PATH) "$git_dir;$::env(PATH)"
exec git --version
```

This modifies only the current Vivado process environment. Alternatively install Git for Windows and restart Vivado.

## Automated flow

The scripts validate the branch, part and input files; record the commit, working-tree status and tool version; copy exact RTL/XDC inputs to a local snapshot; run synthesis; export synthesis reports and checkpoint; run implementation through routing; export implementation reports and checkpoint; and write the bitstream.

## Output layout

```text
reports/<direction>/<YYYYMMDD_HHMMSS>/
bitstreams/<direction>/<YYYYMMDD_HHMMSS>/
<Vivado project>/build_artifacts/<YYYYMMDD_HHMMSS>/
    sources/
    post_synth.dcp
    post_route.dcp
```

`<direction>` is `encryption` or `decryption`. Keep reports and selected bitstreams in Git; retain checkpoints and project caches locally. The scripts do not automatically commit or push files.

## Acceptance and troubleshooting

Check `BUILD FINISHED`, the actual `.bit` file, and any `*.error.txt` files produced when optional report commands fail. Review post-route WNS/TNS, WHS/THS, pulse-width checks, DRC, methodology, CDC and constraint coverage. A generated bitstream alone is not timing or hardware sign-off.

If a build stops after adding sources, do not blindly rerun it: the scripts intentionally reject nonempty projects. Preserve the failed logs and use a fresh empty project for a complete rerun, or resume the failed step deliberately. Never delete the reference reports to retry a build.

See [reference results](../reports/README.md) and [bitstream instructions](../bitstreams/README.md).
