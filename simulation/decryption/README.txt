Two-pass wrapper verification bundle

Copy files into simulation/decryption/ under your repository root.
The RTL remains unchanged; scripts compile rtl/interfaces/wrapper_decrypt_two_pass_draft.vhd.
Run the scripts one at a time in ModelSim:
  do simulation/decryption/run_wrapper_decrypt_two_pass.do
  do simulation/decryption/run_wrapper_decrypt.do
  do simulation/decryption/run_wrapper_decrypt_extra.do

The existing core-only run_decrypt.do and run_decrypt_negative.do are not changed.
WARNING: These tests have not been executed in ModelSim in this environment.
The two-pass wrapper assumes trusted identical replay; these suites do not prove
resistance to modification between VERIFY and RELEASE.
