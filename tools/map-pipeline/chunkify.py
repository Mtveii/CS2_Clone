#!/usr/bin/env python3
"""Split a SDF .npy grid into 32^3 chunks + manifest.json.

Usage:
  python chunkify.py --input sdf.npy --output-dir out/ --voxel-mm 200 --chunk-size 32
"""
import argparse
import hashlib
import json
import os
import numpy as np


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--input', required=True)
    ap.add_argument('--output-dir', required=True)
    ap.add_argument('--voxel-mm', type=int, default=200)
    ap.add_argument('--chunk-size', type=int, default=32)
    ap.add_argument('--bedrock-shell', type=int, default=2)
    args = ap.parse_args()

    sdf = np.load(args.input)
    assert sdf.ndim == 3, 'expected 3D grid'
    nx, ny, nz = sdf.shape
    cs = args.chunk_size
    os.makedirs(args.output_dir, exist_ok=True)
    chunks_dir = os.path.join(args.output_dir, 'chunks')
    os.makedirs(chunks_dir, exist_ok=True)

    # chunk coords range
    cx_range = range(-( -(-nx // cs)), (nx // cs) + 2)  # generous
    # simpler: iterate over possible chunk coords
    chunk_coords = set()
    for x in range(nx):
        for y in range(ny):
            for z in range(nz):
                chunk_coords.add((x // cs, y // cs, z // cs))
    # but negative indices possible if origin not at 0; here origin at 0 so fine.

    manifest_chunks = []
    for (cx, cy, cz) in sorted(chunk_coords):
        # extract slice
        x0 = cx * cs; x1 = x0 + cs
        y0 = cy * cs; y1 = y0 + cs
        z0 = cz * cs; z1 = z0 + cs
        # pad if out of bounds
        sl = np.zeros((cs, cs, cs), dtype=np.int32)
        # fill from sdf where in range
        ix0 = max(0, x0); ix1 = min(nx, x1)
        iy0 = max(0, y0); iy1 = min(ny, y1)
        iz0 = max(0, z0); iz1 = min(nz, z1)
        if ix0 < ix1 and iy0 < iy1 and iz0 < iz1:
            sl[ix0 - x0:ix1 - x0, iy0 - y0:iy1 - y0, iz0 - z0:iz1 - z0] = \
                sdf[ix0:ix1, iy0:iy1, iz0:iz1]
        # apply bedrock shell: boundaries of the whole volume
        for lx in range(cs):
            for ly in range(cs):
                for lz in range(cs):
                    gx = x0 + lx; gy = y0 + ly; gz = z0 + lz
                    if (gx < args.bedrock_shell or gx >= nx - args.bedrock_shell or
                        gz < args.bedrock_shell or gz >= nz - args.bedrock_shell or
                        gy < args.bedrock_shell):
                        sl[lx, ly, lz] = -32768  # solid bedrock (SDF_MIN)
        # write chunk as raw int32 little-endian
        fname = f'chunk_{cx}_{cy}_{cz}.bin'
        fpath = os.path.join(chunks_dir, fname)
        sl.astype('<i4').tofile(fpath)
        # checksum (crc32c) over the raw bytes
        import zlib
        # zlib.crc32 is CRC32 (IEEE), not CRC32C. Use a simple CRC32C impl.
        data = sl.astype('<i4').tobytes()
        crc = _crc32c(data)
        manifest_chunks.append({
            'coords': [cx, cy, cz],
            'file': 'chunks/' + fname,
            'checksum': crc,
            'size': cs,
        })

    manifest = {
        'version': 1,
        'voxel_size_mm': args.voxel_mm,
        'chunk_size': cs,
        'bounds_vox': [nx, ny, nz],
        'bedrock_shell': args.bedrock_shell,
        'edit_algo_version': 1,
        'chunks': manifest_chunks,
    }
    mpath = os.path.join(args.output_dir, 'manifest.json')
    with open(mpath, 'w') as f:
        json.dump(manifest, f, indent=2)
    print(f'Wrote {len(manifest_chunks)} chunks + manifest to {args.output_dir}')


def _crc32c(data: bytes) -> int:
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


if __name__ == '__main__':
    main()
