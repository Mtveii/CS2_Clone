#!/usr/bin/env python3
"""Generate a tiny isolated VMAP (floor, walls, crates) for map integration tests."""
import struct
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "assets" / "maps" / "training_arena.vmap"
VOXELS = set()


def box(x0, x1, y0, y1, z0, z1):
    for x in range(x0, x1 + 1):
        for y in range(y0, y1 + 1):
            for z in range(z0, z1 + 1):
                VOXELS.add((x, y, z))


# Floor slab, perimeter walls, inner cover blocks.
box(-12, 12, 0, 1, -20, 20)
box(-12, -11, 2, 9, -20, 20)
box(11, 12, 2, 9, -20, 20)
box(-12, 12, 2, 9, -20, -19)
box(-12, 12, 2, 9, 19, 20)
for cx, cz in [(-6, -10), (6, -10), (-6, 10), (6, 10), (0, 0)]:
    box(cx - 1, cx + 1, 2, 4, cz - 1, cz + 1)

body = bytearray()
for x, y, z in sorted(VOXELS):
    body.extend(struct.pack("<hhhB", x, y, z, 1))
header = struct.pack("<IIII", 0x50414D56, 1, 200, len(VOXELS))
OUT.write_bytes(header + body)
print(f"wrote {OUT.name}: {len(VOXELS)} voxels, {OUT.stat().st_size} bytes")
