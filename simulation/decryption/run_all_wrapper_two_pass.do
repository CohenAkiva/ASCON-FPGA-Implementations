# Execute each independent suite; stop on any error.
onerror {quit -code 1}
do simulation/decryption/run_wrapper_decrypt_two_pass.do
do simulation/decryption/run_wrapper_decrypt.do
do simulation/decryption/run_wrapper_decrypt_extra.do
