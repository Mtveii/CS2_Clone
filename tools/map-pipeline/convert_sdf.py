#!/usr/bin/env python3
"""Convert a mesh (OBJ) to a narrow-band signed distance field (numpy .npy).

Usage:
  python convert_sdf.py --input model.obj --output sdf.npy --voxel-mm 200 --bounds 64 64 64
  python convert_sdf.py --demo-box --output box.npy   # generates a solid box for testing

The SDF is stored as int32 (SDF_SCALE = 10 units per mm, matching the engine).
Negative = inside solid, positive = air. Bedrock is NOT applied here (see chunkify).
"""
import argparse
import os
import sys
import numpy as np


SDF_SCALE = 10  # int units per mm, matches VoxelConstants.SDF_SCALE
SDF_MAX = 32767
SDF_MIN = -32768


def parse_obj(path):
    verts = []
    tris = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            parts = line.split()
            if parts[0] == 'v':
                verts.append([float(parts[1]), float(parts[2]), float(parts[3])])
            elif parts[0] == 'f':
                # supports v/vt/vn
                idx = []
                for p in parts[1:]:
                    idx.append(int(p.split('/')[0]) - 1)
                # fan triangulation
                for i in range(1, len(idx) - 1):
                    tris.append([idx[0], idx[i], idx[i + 1]])
    return np.asarray(verts, dtype=np.float64), np.asarray(tris, dtype=np.int64)


def make_demo_box():
    # 1m cube centered at origin
    v = np.array([
        [-0.5, -0.5, -0.5], [0.5, -0.5, -0.5], [0.5, 0.5, -0.5], [-0.5, 0.5, -0.5],
        [-0.5, -0.5, 0.5], [0.5, -0.5, 0.5], [0.5, 0.5, 0.5], [-0.5, 0.5, 0.5],
    ])
    tris = np.array([
        [0, 1, 2], [0, 2, 3],
        [4, 6, 5], [4, 7, 6],
        [0, 4, 5], [0, 5, 1],
        [2, 6, 7], [2, 7, 3],
        [0, 3, 7], [0, 7, 4],
        [1, 5, 6], [1, 6, 2],
    ], dtype=np.int64)
    return v, tris


def mesh_to_sdf(verts, tris, voxel_mm, bounds_vox):
    """Brute-force SDF: for each voxel center, signed distance to nearest triangle."""
    nx, ny, nz = bounds_vox
    # voxel centers in mm
    xs = (np.arange(nx) + 0.5) * voxel_mm
    ys = (np.arange(ny) + 0.5) * voxel_mm
    zs = (np.arange(nz) + 0.5) * voxel_mm
    # scale verts to mm
    V = verts * 1000.0
    # Precompute triangle data
    T0 = V[tris[:, 0]]
    T1 = V[tris[:, 1]]
    T2 = V[tris[:, 2]]
    E0 = T1 - T0
    E1 = T2 - T0
    N = np.cross(E0, E1)
    # For each voxel
    out = np.zeros((nx, ny, nz), dtype=np.int32)
    # iterate in chunks to keep memory sane
    for xi in range(nx):
        for yi in range(ny):
            for zi in range(nz):
                p = np.array([xs[xi], ys[yi], zs[zi]])
                # unsigned distance to nearest triangle
                # point-to-triangle distance (Ericson)
                best = 1e18
                for t in range(len(tris)):
                    a = T0[t]; b = T1[t]; c = T2[t]
                    # closest point on triangle abc to p
                    ab = b - a; ac = c - a; ap = p - a
                    d1 = np.dot(ab, ap); d2 = np.dot(ac, ap)
                    if d1 <= 0 and d2 <= 0:
                        dist = np.linalg.norm(ap)
                    else:
                        bp = p - b
                        d3 = np.dot(ab, bp); d4 = np.dot(ac, bp)
                        if d3 >= np.dot(ab, ab) and d4 <= d3:
                            dist = np.linalg.norm(bp)
                        else:
                            cp = p - c
                            d5 = np.dot(ab, cp); d6 = np.dot(ac, cp)
                            if d6 >= np.dot(ac, ac) and d5 <= d6:
                                dist = np.linalg.norm(cp)
                            else:
                                vc = d1 * np.dot(ac, ac) - d2 * np.dot(ab, ac)
                                if vc <= 0 and d1 >= 0 and d2 <= np.dot(ac, ac):
                                    dist = np.linalg.norm(ap - ab * (d1 / np.dot(ab, ab)))
                                else:
                                    vb = d5 * np.dot(ab, ac) - d1 * np.dot(ac, ac)
                                    if vb <= 0 and d2 >= 0 and d1 <= np.dot(ab, ac):
                                        dist = np.linalg.norm(ap - ac * (d2 / np.dot(ac, ac)))
                                    else:
                                        va = d3 * np.dot(ac, ac) - d4 * np.dot(ab, ac)
                                        if va <= 0 and (d4 - d3) >= 0 and (d3 - d4) <= np.dot(ab, ab) - np.dot(ab, ac):
                                            dist = np.linalg.norm(bp - ab * ((d4 - d3) / (np.dot(ab, ab) - 2 * np.dot(ab, ac) + np.dot(ac, ac))))
                                        else:
                                            denom = np.dot(ab, ab) * np.dot(ac, ac) - np.dot(ab, ac) ** 2
                                            v = (d1 * np.dot(ac, ac) - d2 * np.dot(ab, ac)) / denom
                                            w = (d2 * np.dot(ab, ab) - d1 * np.dot(ab, ac)) / denom
                                            pt = a + ab * v + ac * w
                                            dist = np.linalg.norm(p - pt)
                    if dist < best:
                        best = dist
                # sign: inside if odd number of ray crossings along X
                # simple: use winding via raycast count
                # cast ray along +X, count triangle intersections
                crossings = 0
                for t in range(len(tris)):
                    a = T0[t]; b = T1[t]; c = T2[t]
                    # ray from p along +X
                    # Moller-Trumbore
                    e1 = b - a; e2 = c - a
                    h = np.cross(np.array([1.0, 0, 0]), e2)
                    det = np.dot(e1, h)
                    if abs(det) < 1e-9:
                        continue
                    inv = 1.0 / det
                    svec = p - a
                    u = np.dot(svec, h) * inv
                    if u < 0 or u > 1:
                        continue
                    q = np.cross(svec, e1)
                    v = np.dot(np.array([1.0, 0, 0]), q) * inv
                    if v < 0 or u + v > 1:
                        continue
                    tval = np.dot(e2, q) * inv
                    if tval >= 0:
                        crossings += 1
                inside = (crossings % 2) == 1
                signed = -best if inside else best
                mm = signed  # mm
                val = int(round(mm * SDF_SCALE))
                val = max(SDF_MIN, min(SDF_MAX, val))
                out[xi, yi, zi] = val
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--input', help='OBJ file')
    ap.add_argument('--output', required=True)
    ap.add_argument('--voxel-mm', type=int, default=200)
    ap.add_argument('--bounds', type=int, nargs=3, default=[32, 32, 32], help='grid dims in voxels')
    ap.add_argument('--demo-box', action='store_true')
    args = ap.parse_args()

    if args.demo_box:
        verts, tris = make_demo_box()
    elif args.input:
        verts, tris = parse_obj(args.input)
    else:
        print('Provide --input or --demo-box', file=sys.stderr)
        sys.exit(2)

    sdf = mesh_to_sdf(verts, tris, args.voxel_mm, tuple(args.bounds))
    np.save(args.output, sdf)
    print(f'Saved {args.output} shape={sdf.shape} dtype={sdf.dtype} '
          f'min={sdf.min()} max={sdf.max()}')


if __name__ == '__main__':
    main()
