#!/usr/bin/env python3
"""Validate a chunkified output directory."""
import argparse
import json
import os
import struct
import sys


def crc32c(data):
    crc = 0xFFFFFFFF
    for byte in data:
        crc ^= byte
        for _ in range(8):
            if crc & 1:
                crc = (crc >> 1) ^ 0x82F63B78
            else:
                crc >>= 1
            crc &= 0xFFFFFFFF
    return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--dir', required=True)
    args = ap.parse_args()
    d = args.dir
    mpath = os.path.join(d, 'manifest.json')
    if not os.path.exists(mpath):
        print('missing manifest.json', file=sys.stderr)
        sys.exit(1)
    with open(mpath) as f:
        m = json.load(f)
    ok = True
    for ch in m['chunks']:
        fpath = os.path.join(d, ch['file'])
        if not os.path.exists(fpath):
            print('MISSING', fpath); ok = False; continue
        with open(fpath, 'rb') as f:
            data = f.read()
        expected = (m['chunk_size'] ** 3) * 4
        if len(data) != expected:
            print('BAD SIZE', fpath, len(data), '!=', expected); ok = False; continue
        cs = crc32c(data)
        if cs != ch['checksum']:
            print('CHECKSUM MISMATCH', fpath, cs, '!=', ch['checksum']); ok = False; continue
    if not ok:
        print('VALIDATION FAILED')
        sys.exit(1)
    print(f"VALIDATION OK: {len(m['chunks'])} chunks")


if __name__ == '__main__':
    main()
