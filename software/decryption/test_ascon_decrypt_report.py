#!/usr/bin/env python3
"""Hardware KAT report for the decryption-only Basys3 wrapper.
Requires test_ascon_decrypt_pi.py (with active_state=True fix) in same directory.
Supports KAT records with PT length <= 16 bytes; AD can span blocks.
"""
import argparse
import datetime
import pathlib
from test_ascon_decrypt_pi import Interface


def parse_kat(path):
    for paragraph in pathlib.Path(path).read_text(encoding='utf-8').split('\n\n'):
        fields = {}
        for line in paragraph.splitlines():
            if '=' in line:
                k, v = line.split('=', 1)
                fields[k.strip().upper()] = v.strip()
        if not fields or 'COUNT' not in fields:
            continue
        for k in ('KEY', 'NONCE', 'PT', 'AD', 'CT'):
            if k not in fields:
                raise ValueError(f"Count {fields['COUNT']} missing {k}")
        ct_tag = bytes.fromhex(fields['CT'])
        pt = bytes.fromhex(fields['PT'])
        if len(ct_tag) != len(pt) + 16:
            raise ValueError(f"Count {fields['COUNT']} invalid CT+TAG length")
        yield dict(count=int(fields['COUNT']), key=bytes.fromhex(fields['KEY']),
                   nonce=bytes.fromhex(fields['NONCE']), pt=pt,
                   ad=bytes.fromhex(fields['AD']), ct=ct_tag[:-16], tag=ct_tag[-16:])


def send_command(bus, command):
    bus.write(48, command)
    bus.wait_status(0x01, 0x01)


def run_one(bus, item, corrupt=False):
    tag = item['tag']
    if corrupt:
        tag = bytes([tag[0] ^ 0x80]) + tag[1:]
    bus.write_bytes(0, item['key'])
    bus.write_bytes(16, item['nonce'])
    bus.write(62, 1)
    bus.write_bytes(32, tag)
    bus.write(62, 0)
    bus.write(52, int(bool(item['ad'])))
    send_command(bus, 1)
    for start in range(0, len(item['ad']), 16):
        chunk = item['ad'][start:start+16]
        last_ad = start + 16 >= len(item['ad'])
        bus.write_bytes(32, chunk)
        bus.write(50, len(chunk))
        bus.write(51, 1 | (2 if last_ad else 0))
        send_command(bus, 2)
    bus.write_bytes(32, item['ct'])
    bus.write(50, len(item['ct']))
    bus.write(51, 2)
    send_command(bus, 2)
    status = bus.read(49)
    length = bus.read(53)
    result = bytes(bus.read(i) for i in range(16))
    authenticated = bool(status & 0x10)
    valid = bool(status & 0x02)
    done = bool(status & 0x04)
    error = bool(status & 0x08)
    if corrupt:
        passed = done and not error and not authenticated and not valid and length == 0 and result == bytes(16)
    else:
        passed = (done and not error and authenticated and valid
                  and length == len(item['pt']) and result[:length] == item['pt'])
    return dict(passed=passed, status=status, length=length, result=result,
                authenticated=authenticated,
                valid=valid, done=done, error=error)


def describe(item, result, negative):
    hx = lambda b: b.hex().upper() if b else '(empty)'
    out = []
    out.append('=' * 60)
    out.append(f"ASCON-AEAD128 DECRYPTION | KAT Count={item['count']} | {'INVALID TAG' if negative else 'VALID TAG'}")
    out.append('=' * 60)
    out.append('INPUT - Sent to FPGA:')
    out.append(f"  KEY       : {hx(item['key'])}")
    out.append(f"  NONCE     : {hx(item['nonce'])}")
    out.append(f"  AD        : {hx(item['ad'])}")
    out.append(f"  CIPHERTEXT: {hx(item['ct'])}")
    actual_tag = bytes([item['tag'][0] ^ 0x80]) + item['tag'][1:] if negative else item['tag']
    out.append(f"  TAG_IN    : {hx(actual_tag)}")
    out.append('OUTPUT - Read from FPGA:')
    out.append(f"  PLAINTEXT : {hx(result['result'][:result['length']])}")
    out.append(f"  STATUS    : 0x{result['status']:02X} (AUTH={int(result['authenticated'])}, VALID={int(result['valid'])}, DONE={int(result['done'])}, ERROR={int(result['error'])})")
    out.append(f"  LENGTH    : {result['length']}")
    out.append('EXPECTED - Official KAT / authentication policy:')
    out.append(f"  PLAINTEXT : {'(hidden; zero length)' if negative else hx(item['pt'])}")
    out.append(f"  AUTH      : {0 if negative else 1}")
    out.append('VERIFICATION:')
    out.append(f"  Result    : {'PASS' if result['passed'] else 'FAIL'}")
    out.append('=' * 60)
    out.append(f"Count={item['count']} AD={len(item['ad'])} PT={len(item['pt'])} {'NEGATIVE' if negative else 'POSITIVE'} {'PASS' if result['passed'] else 'FAIL'}")
    return '\n'.join(out)


def main():
    parser = argparse.ArgumentParser(description='Generate a decryption hardware KAT report')
    parser.add_argument('kat', help='Path to LWC_AEAD_KAT_128_128.txt')
    parser.add_argument('--output', default='ascon_decrypt_hardware_results.txt')
    parser.add_argument('--max-cases', type=int, default=20, help='Number of eligible KATs to run (default 20)')
    parser.add_argument('--start-count', type=int, default=1)
    parser.add_argument('--negative', action='store_true', help='Also test corrupted TAG for each selected KAT')
    parser.add_argument('--hold-ms', type=float, default=5.0)
    args = parser.parse_args()
    if args.max_cases < 1 or args.hold_ms < 1:
        parser.error('--max-cases and --hold-ms must be >= 1')
    all_items = list(parse_kat(args.kat))
    eligible = [i for i in all_items if i['count'] >= args.start_count and len(i['pt']) <= 16]
    selected = eligible[:args.max_cases]
    if not selected:
        parser.error('No eligible KAT records')
    print(f'Selected {len(selected)} KAT cases; only PT <=16 bytes is supported by this wrapper.')
    print('Check common GND and FPGA bitstream. Press Basys3 RESET, then Enter.')
    input()
    log = [f'ASCON DECRYPTION HARDWARE KAT REPORT | {datetime.datetime.now().isoformat(timespec="seconds")}',
           'Tested via Raspberry Pi GPIO and Basys3 wrapper_decrypt.',
           'Scope: <=16 bytes ciphertext per transaction; longer AD supported.',
           'Basic implementation: no hardware cycle counters.', '']
    passed = failed = 0
    bus = Interface(args.hold_ms / 1000)
    try:
        for item in selected:
            for negative in ([False, True] if args.negative else [False]):
                try:
                    result = run_one(bus, item, negative)
                    entry = describe(item, result, negative)
                    ok = result['passed']
                except Exception as exc:
                    ok = False
                    entry = f"Count={item['count']} {'NEGATIVE' if negative else 'POSITIVE'} ERROR: {type(exc).__name__}: {exc}"
                log.append(entry + '\n')
                print(entry.splitlines()[-1], flush=True)
                passed += int(ok)
                failed += int(not ok)
                pathlib.Path(args.output).write_text('\n'.join(log), encoding='utf-8')
                if not ok:
                    print('Stopped on failure. Inspect report and wiring/handshake.')
                    break
            if failed:
                break
    finally:
        bus.close()
    summary = f'FINAL SUMMARY: {passed} PASS, {failed} FAIL, {passed+failed} EXECUTED; {len(selected)} KAT vectors selected'
    log.append('\n' + summary)
    pathlib.Path(args.output).write_text('\n'.join(log) + '\n', encoding='utf-8')
    print(summary)
    print(f'Report saved to {pathlib.Path(args.output).resolve()}')
    raise SystemExit(1 if failed else 0)


if __name__ == '__main__':
    main()
