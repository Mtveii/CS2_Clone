#!/usr/bin/env python3
"""Конвертер MagicaVoxel .vox (v150) -> компактный VMAP для нашего движка.

Источник: Oasis by Hard Cover, CC0 (github.com/Phyronnaz/VoxelAssets).
Берём модель 0 (коробка карты 40x60x16) как basic map shell, масштабируем
каждый воксель блоком scale^3, переставляем оси MV Z-up -> наш Y-up.

Формат VMAP:
  magic 'VMAP', version u32, voxel_size_mm u32, count u32,
  записи: int16 x, int16 y, int16 z, uint8 material
"""
import argparse
import struct
import sys
import os

SCALE = 3
VOXEL_SIZE_MM = 200
MAT_CONCRETE = 1
MAT_WOOD = 3


def read_dict(buf, o):
    d = {}
    n = struct.unpack_from('<i', buf, o)[0]
    o += 4
    for _ in range(n):
        kl = struct.unpack_from('<i', buf, o)[0]; o += 4
        k = buf[o:o + kl].decode('latin1'); o += kl
        vl = struct.unpack_from('<i', buf, o)[0]; o += 4
        v = buf[o:o + vl].decode('latin1'); o += vl
        d[k] = v
    return d


def parse(path):
    data = open(path, 'rb').read()
    assert data[:4] == b'VOX ', 'not a vox file'
    models = []
    palette = None

    def walk(o, end):
        nonlocal palette
        while o + 12 <= end:
            tag = data[o:o + 4].decode('latin1')
            cs, cc = struct.unpack_from('<ii', data, o + 4)
            body = o + 12
            child = body + cs
            if tag == 'SIZE':
                models.append({'size': struct.unpack_from('<iii', data, body), 'vox': []})
            elif tag == 'XYZI':
                n = struct.unpack_from('<i', data, body)[0]
                vox = []
                for i in range(n):
                    b = body + 4 + i * 4
                    vox.append((data[b], data[b + 1], data[b + 2], data[b + 3]))
                if models:
                    models[-1]['vox'] = vox
            elif tag == 'RGBA':
                palette = data[body:body + cs]
            if cc > 0:
                walk(child, child + cc)
            o = child + cc

    walk(8, len(data))
    return models, palette


def material_for(ci, palette):
    if palette is None or (ci - 1) * 4 + 3 >= len(palette):
        return MAT_CONCRETE
    i = (ci - 1) * 4
    r, g, b = palette[i], palette[i + 1], palette[i + 2]
    if r > g and r > b:
        return MAT_WOOD
    return MAT_CONCRETE


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('src', nargs='?', default='oasis.vox')
    parser.add_argument('out', nargs='?', default='assets/maps/oasis.vmap')
    parser.add_argument('--scale', type=int, default=SCALE,
                        help='voxel expansion factor (1 for props, 3 for Oasis)')
    parser.add_argument('--model', type=int, default=0,
                        help='model index inside a multi-model .vox')
    args = parser.parse_args()
    scale = max(1, args.scale)
    out = args.out
    models, palette = parse(args.src)
    if not models:
        raise SystemExit('no models')
    if args.model >= len(models):
        raise SystemExit(f'model {args.model} out of range ({len(models)})')
    m = models[args.model]
    print(f'model {args.model} size={m["size"]} voxels={len(m["vox"])} palette={"yes" if palette else "no"} scale={scale}')

    sx, sy, sz = m['size']
    ox = -sx * scale // 2
    oz = -sy * scale // 2
    records = []
    for x, y, z, ci in m['vox']:
        mat = MAT_WOOD if z >= sz - 2 else material_for(ci, palette)
        for dz in range(scale):
            for dy in range(scale):
                for dx in range(scale):
                    wx = ox + x * scale + dx
                    wy = (sz - 1 - z) * scale + dz
                    wz = oz + y * scale + dy
                    records.append((wx, wy, wz, mat))

    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, 'wb') as f:
        f.write(b'VMAP')
        f.write(struct.pack('<III', 1, VOXEL_SIZE_MM, len(records)))
        for x, y, z, mat in records:
            f.write(struct.pack('<hhhB', x, y, z, mat))
    print(f'wrote {out}: {len(records)} voxels, {os.path.getsize(out)/1024/1024:.2f} MB')


if __name__ == '__main__':
    main()
