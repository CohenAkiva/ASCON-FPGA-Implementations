# ASCON Basic decryption | Vivado project-mode build
set root [file normalize [file join [file dirname [info script]] ..]]
set expected_branch basic
set expected_part xc7a35tcpg236-1
# Locate Git automatically when GitHub Desktop is not on PATH.
set git_exe [auto_execok git]
if {$git_exe eq "" && [info exists ::env(LOCALAPPDATA)]} {
    set candidates [glob -nocomplain -directory $::env(LOCALAPPDATA) GitHubDesktop/app-*/resources/app/git/cmd/git.exe]
    foreach candidate [lsort -decreasing -dictionary $candidates] {
        if {![catch {exec $candidate --version}]} {
            set git_exe [list $candidate]
            break
        }
    }
}
if {$git_exe eq ""} {error "Git not found. Install Git or make GitHub Desktop Git available."}
puts "Git: [exec {*}$git_exe --version]"
if {[catch {exec {*}$git_exe -C $root rev-parse --abbrev-ref HEAD} branch]} {error "Cannot verify Git branch: $branch"}
if {$branch ne $expected_branch} {error "Expected branch $expected_branch, found $branch"}
set commit [exec {*}$git_exe -C $root rev-parse HEAD]
set dirty [exec {*}$git_exe -C $root status --porcelain]
if {[catch {current_project} proj] || $proj eq ""} {error "Open the dedicated Basic Decryption Vivado project first"}
if {[get_property NAME $proj] ne "ASCON_Basic_Decryption"} {error "Open ASCON_Basic_Decryption first"}
if {[get_property PART $proj] ne $expected_part} {error "Incorrect FPGA part"}
if {[llength [get_files -quiet -of_objects [get_filesets sources_1]]] || [llength [get_files -quiet -of_objects [get_filesets constrs_1]]]} {error "Use a fresh empty project; existing sources were not modified"}
set rtl [list rtl/common/ascon_pack.vhd rtl/common/ASCON_ROUND.vhd rtl/common/ASCON_PERMUTATION.vhd rtl/decryption/ASCON_DECRYPT_TOP_LEVEL.vhd rtl/interfaces/wrapper_decrypt.vhd]
set xdc constraints/basys3_decrypt.xdc
foreach rel [concat $rtl [list $xdc]] {if {![file isfile [file join $root $rel]]} {error "Missing $rel"}}
set stamp [clock format [clock seconds] -format %Y%m%d_%H%M%S]
set out [file join $root reports decryption $stamp]
set bits [file join $root bitstreams decryption $stamp]
set local [file join [get_property DIRECTORY $proj] build_artifacts $stamp]
foreach dir [list $out $bits $local] {if {[file exists $dir]} {error "Output already exists: $dir"}; file mkdir $dir}
set meta [open [file join $out build_info.txt] w]
puts $meta "Branch: $branch\nSource commit: $commit\nVivado: [version -short]\nPart: $expected_part\nTarget clock: 100 MHz\nWorking tree changes at build start:\n$dirty"
close $meta
# Preserve exact input files and a checksum-independent source snapshot locally.
foreach rel [concat $rtl [list $xdc]] {set dst [file join $local sources $rel]; file mkdir [file dirname $dst]; file copy [file join $root $rel] $dst}
foreach rel $rtl {add_files -norecurse [file join $local sources $rel]}
set_property FILE_TYPE {VHDL 2008} [get_files -of_objects [get_filesets sources_1]]
add_files -fileset constrs_1 -norecurse [file join $local sources $xdc]
set_property top wrapper [get_filesets sources_1]
update_compile_order -fileset sources_1
proc ascon_report {cmd path args} {
    if {[catch {$cmd {*}$args -file $path} msg]} {puts "WARNING: $cmd failed: $msg"; set f [open "${path}.error.txt" w]; puts $f $msg; close $f}
}
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {![string match {*Complete*} [get_property STATUS [get_runs synth_1]]]} {error "Synthesis failed: [get_property STATUS [get_runs synth_1]]"}
open_run synth_1
report_utilization -file [file join $out synth_utilization.rpt]
report_timing_summary -file [file join $out synth_timing_summary.rpt]
ascon_report report_utilization [file join $out synth_hierarchical_utilization.rpt] -hierarchical
ascon_report report_timing [file join $out synth_timing_paths.rpt] -max_paths 20
ascon_report report_control_sets [file join $out synth_control_sets.rpt]
write_checkpoint -force [file join $local post_synth.dcp]
close_design
launch_runs impl_1 -to_step route_design -jobs 4
wait_on_run impl_1
if {![string match {*Complete*} [get_property STATUS [get_runs impl_1]]]} {error "Implementation failed: [get_property STATUS [get_runs impl_1]]"}
open_run impl_1
report_utilization -file [file join $out impl_utilization.rpt]
report_timing_summary -report_unconstrained -file [file join $out impl_timing_summary.rpt]
report_drc -file [file join $out impl_drc.rpt]
ascon_report report_utilization [file join $out impl_hierarchical_utilization.rpt] -hierarchical
ascon_report report_timing [file join $out impl_timing_paths.rpt] -max_paths 20
foreach {cmd name} {report_power power report_clock_utilization clock_utilization report_control_sets control_sets report_io io report_cdc cdc report_methodology methodology check_timing check_timing} {ascon_report $cmd [file join $out impl_${name}.rpt]}
write_checkpoint -force [file join $local post_route.dcp]
# Bitstream generation is not a timing sign-off.
write_bitstream -force [file join $bits ascon_basic_decrypt.bit]
puts "BUILD FINISHED - review timing, DRC, CDC and any report errors before sign-off."
puts "Reports: $out\nBitstream: $bits\nCheckpoints and source snapshot: $local"
