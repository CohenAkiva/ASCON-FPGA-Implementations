#!/usr/bin/env python3
"""Basys3 Ascon Wrapper V2 KAT runner. Requires gpiozero on Raspberry Pi 5.

Run: python3 ascon_kat_v2.py LWC_AEAD_KAT_128_128.txt --count 529
For first tests, press Basys3 center RESET before starting this script.
"""
import argparse
import re
import time
from pathlib import Path
from gpiozero import OutputDevice, InputDevice
from gpiozero.pins.lgpio import LGPIOFactory

ADDR_PINS = [17, 27, 22, 23, 24, 25]
DATA_IN_PINS = [5, 6, 13, 19, 26, 12, 16, 20]
DATA_OUT_PINS = [21, 4, 18, 14, 15, 7, 8, 9]
TO_WRITE_PIN = 10
TO_READ_PIN = 11
DELAY = 0.001

class Bus:
    def __init__(self):
        self.factory = LGPIOFactory()
        self.addr = [OutputDevice(p, initial_value=False, pin_factory=self.factory) for p in ADDR_PINS]
        self.din = [OutputDevice(p, initial_value=False, pin_factory=self.factory) for p in DATA_IN_PINS]
        self.dout = [InputDevice(p, pull_up=None, active_state=True, pin_factory=self.factory) for p in DATA_OUT_PINS]
        self.wr = OutputDevice(TO_WRITE_PIN, initial_value=False, pin_factory=self.factory)
        self.rd = OutputDevice(TO_READ_PIN, initial_value=False, pin_factory=self.factory)

    @staticmethod
    def bits(pins, value):
        for i, pin in enumerate(pins):
            pin.value = (value >> i) & 1

    def write(self, address, value):
        self.bits(self.addr, address)
        self.bits(self.din, value)
        time.sleep(DELAY)
        self.wr.on(); time.sleep(DELAY)
        self.wr.off(); time.sleep(DELAY)

    def read(self, address):
        self.bits(self.addr, address)
        time.sleep(DELAY)
        self.rd.on(); time.sleep(DELAY)
        value = sum(int(pin.value) << i for i, pin in enumerate(self.dout))
        self.rd.off(); time.sleep(DELAY)
        return value

    def write_bytes(self, base, payload):
        for i, byte in enumerate(payload):
            self.write(base+i, byte)

    def read_bytes(self, base, n):
        return bytes(self.read(base+i) for i in range(n))

    def wait_idle(self, timeout=5.0):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            status = self.read(49)
            if status & 0x08:
                raise RuntimeError(f'FPGA rejected command (status=0x{status:02X})')
            if status & 0x01:
                return status
            time.sleep(0.01)
        raise TimeoutError('FPGA not ready within timeout')

    def initialize(self, key, nonce, has_ad):
        self.write_bytes(0, key)
        self.write_bytes(16, nonce)
        self.write(52, int(has_ad))
        self.write(48, 1)
        self.wait_idle()

    def block(self, payload, is_ad, is_last):
        assert len(payload) <= 16
        self.write_bytes(32, payload)
        self.write(50, len(payload))
        self.write(51, int(is_ad) | (int(is_last) << 1))
        self.write(48, 2)
        status = self.wait_idle()
        ciphertext = b''
        if not is_ad:
            if not (status & 0x02):
                raise RuntimeError('Expected ciphertext valid bit')
            n = self.read(53)
            if n != len(payload):
                raise RuntimeError(f'Unexpected result length: {n}')
            ciphertext = self.read_bytes(0, n)
        return ciphertext, status

    def encrypt(self, key, nonce, ad, pt):
        self.initialize(key, nonce, bool(ad))
        if ad:
            for offset in range(0, len(ad), 16):
                chunk = ad[offset:offset+16]
                self.block(chunk, True, offset+16 >= len(ad))
        ct = bytearray()
        # Empty plaintext is represented by one final zero-byte block.
        offsets = range(0, len(pt), 16) if pt else [0]
        for offset in offsets:
            chunk = pt[offset:offset+16]
            block_ct, status = self.block(chunk, False, offset+16 >= len(pt))
            ct.extend(block_ct)
        if not (status & 0x04):
            raise RuntimeError('TAG not ready after last plaintext block')
        tag = self.read_bytes(16, 16)
        return bytes(ct), tag

    def close(self):
        for pin in self.addr + self.din + self.dout + [self.wr, self.rd]:
            pin.close()
        self.factory.close()


def parse_kats(path):
    for entry in re.split(r'\n\s*\n', Path(path).read_text(encoding='ascii')):
        fields = dict(re.findall(r'^\s*(Count|Key|Nonce|PT|AD|CT)\s*=\s*([0-9a-fA-F]*)\s*$', entry, re.M))
        if len(fields) == 6:
            yield {k: int(v) if k == 'Count' else bytes.fromhex(v) for k,v in fields.items()}


def main():
    p = argparse.ArgumentParser()
    p.add_argument('kat_file')
    p.add_argument('--count', type=int, help='Run a specific NIST KAT Count')
    p.add_argument('--limit', type=int, default=10, help='Maximum cases if --count not supplied')
    args = p.parse_args()
    cases = [c for c in parse_kats(args.kat_file) if args.count is None or c['Count'] == args.count]
    cases = cases if args.count is not None else cases[:args.limit]
    if not cases:
        raise SystemExit('No matching KAT cases')
    print('Press and release Basys3 center RESET before running the first case.')
    input('Press ENTER to start...')
    bus = Bus()
    try:
        for case in cases:
            # TOP supports repeated transactions; no manual reset between cases.
            ct, tag = bus.encrypt(case['Key'], case['Nonce'], case['AD'], case['PT'])
            expected_ct, expected_tag = case['CT'][:-16], case['CT'][-16:]
            passed = ct == expected_ct and tag == expected_tag
            print(f"Count={case['Count']} AD={len(case['AD'])} PT={len(case['PT'])} "
                  f"{'PASS' if passed else 'FAIL'}")
            if not passed:
                print(f'  CT actual  : {ct.hex().upper()}')
                print(f'  CT expected: {expected_ct.hex().upper()}')
                print(f'  TAG actual : {tag.hex().upper()}')
                print(f'  TAG expect : {expected_tag.hex().upper()}')
                raise SystemExit(1)
        print(f'ALL {len(cases)} KAT CASES PASSED')
    finally:
        bus.close()

if __name__ == '__main__':
    main()
