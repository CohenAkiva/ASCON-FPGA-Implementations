#!/usr/bin/env python3
"""Raspberry Pi 5 -> Basys3 ASCON decryption wrapper hardware test.

Requires gpiozero and lgpio. Uses BCM numbering, not physical pin numbers.
Do not connect 3.3V rails together. Connect a common GND.
"""
import argparse
import time
from gpiozero import DigitalOutputDevice, DigitalInputDevice
from gpiozero.pins.lgpio import LGPIOFactory

ADDR_PINS = [17, 27, 22, 23, 24, 25]
DATA_IN_PINS = [5, 6, 13, 19, 26, 12, 16, 20]
DATA_OUT_PINS = [21, 4, 18, 14, 15, 7, 8, 9]
READ_PIN = 11
WRITE_PIN = 10

KEY = bytes.fromhex('000102030405060708090A0B0C0D0E0F')
NONCE = bytes.fromhex('101112131415161718191A1B1C1D1E1F')
CIPHERTEXT = bytes.fromhex('E8')
PLAINTEXT = bytes.fromhex('20')
TAG = bytes.fromhex('DD576ABA1CD3E6FC704DE02AEDB79588')

class Interface:
    def __init__(self, hold_s):
        self.hold_s = hold_s
        self.factory = LGPIOFactory()
        self.outputs = []
        self.inputs = []
        try:
            self.addr = [self._out(pin) for pin in ADDR_PINS]
            self.din = [self._out(pin) for pin in DATA_IN_PINS]
            self.read_strobe = self._out(READ_PIN)
            self.write_strobe = self._out(WRITE_PIN)
            self.dout = [self._in(pin) for pin in DATA_OUT_PINS]
        except Exception:
            self.close()
            raise

    def _out(self, pin):
        obj = DigitalOutputDevice(pin, active_high=True, initial_value=False, pin_factory=self.factory)
        self.outputs.append(obj)
        return obj

    def _in(self, pin):
        obj = DigitalInputDevice(pin, pull_up=None, pin_factory=self.factory)
        self.inputs.append(obj)
        return obj

    @staticmethod
    def set_bus(devices, value):
        for bit, device in enumerate(devices):
            if (value >> bit) & 1:
                device.on()
            else:
                device.off()

    def write(self, addr, value):
        if not 0 <= addr < 64 or not 0 <= value < 256:
            raise ValueError('Address or data byte out of range')
        self.set_bus(self.addr, addr)
        self.set_bus(self.din, value)
        time.sleep(self.hold_s)
        self.write_strobe.on()
        time.sleep(self.hold_s)
        self.write_strobe.off()
        time.sleep(self.hold_s)

    def read(self, addr):
        if not 0 <= addr < 64:
            raise ValueError('Address out of range')
        self.set_bus(self.addr, addr)
        time.sleep(self.hold_s)
        self.read_strobe.on()
        time.sleep(self.hold_s)
        value = sum(int(dev.value) << bit for bit, dev in enumerate(self.dout))
        self.read_strobe.off()
        time.sleep(self.hold_s)
        return value

    def write_bytes(self, base, values):
        for i, value in enumerate(values):
            self.write(base + i, value)

    def wait_status(self, mask, expected, timeout_s=3.0):
        deadline = time.monotonic() + timeout_s
        last = 0
        while time.monotonic() < deadline:
            last = self.read(49)
            if (last & mask) == expected:
                return last
            time.sleep(0.005)
        raise TimeoutError(f'STATUS timeout: mask=0x{mask:02X}, expected=0x{expected:02X}, last=0x{last:02X}')

    def close(self):
        for device in reversed(self.inputs):
            device.close()
        for device in reversed(self.outputs):
            device.close()
        self.factory.close()


def run_case(bus, tag, should_authenticate):
    bus.write_bytes(0, KEY)
    bus.write_bytes(16, NONCE)
    bus.write(62, 1)  # TAG input bank
    bus.write_bytes(32, tag)
    bus.write(62, 0)  # Ciphertext input bank
    bus.write(52, 0)  # No associated data
    bus.write(48, 1)  # INIT
    bus.wait_status(0x01, 0x01)

    # Plaintext must not be visible before authentication.
    before = bus.read(0)
    assert before == 0, f'Plaintext visible before completion: 0x{before:02X}'

    bus.write_bytes(32, CIPHERTEXT)
    bus.write(50, len(CIPHERTEXT))
    bus.write(51, 2)  # IS_LAST=1, PROCESS_AD=0
    bus.write(48, 2)  # PROCESS BLOCK
    status = bus.wait_status(0x04, 0x04)
    length = bus.read(53)
    result = bytes(bus.read(i) for i in range(16))
    auth = bool(status & 0x10)
    valid = bool(status & 0x02)
    error = bool(status & 0x08)
    print(f'STATUS=0x{status:02X}  AUTH={int(auth)}  VALID={int(valid)}  ERROR={int(error)}')
    print(f'Length={length}  Plaintext register={result.hex().upper()}')
    if error:
        raise AssertionError('Wrapper ERROR flag is set')
    if should_authenticate:
        assert auth and valid, 'Valid TAG was rejected'
        assert length == len(PLAINTEXT), 'Incorrect plaintext length'
        assert result[:length] == PLAINTEXT, 'Plaintext does not match KAT'
        print('PASS: Valid TAG accepted, plaintext matches KAT')
    else:
        assert not auth and not valid, 'Invalid TAG was accepted!'
        assert length == 0 and result == bytes(16), 'Plaintext leaked on authentication failure!'
        print('PASS: Invalid TAG rejected; plaintext hidden')


def main():
    parser = argparse.ArgumentParser(description='Test Basys3 ASCON decryption via Raspberry Pi GPIO')
    parser.add_argument('--hold-ms', type=float, default=5.0,
                        help='Time to hold each GPIO phase in milliseconds (default: 5)')
    parser.add_argument('--negative', action='store_true',
                        help='Run invalid-TAG test only (requires fresh FPGA RESET)')
    args = parser.parse_args()
    if args.hold_ms < 1:
        parser.error('--hold-ms must be >= 1')
    print('Check common GND, 3.3V GPIO levels, FPGA bitstream and 100 MHz CLK.')
    print('Press the Basys3 RESET button once, then press Enter to start.')
    input()
    bus = Interface(args.hold_ms / 1000)
    try:
        if args.negative:
            bad_tag = bytes([TAG[0] ^ 0x80]) + TAG[1:]
            run_case(bus, bad_tag, False)
        else:
            run_case(bus, TAG, True)
    finally:
        bus.close()


if __name__ == '__main__':
    main()
