#!/usr/bin/env python3
"""Convert KHR_mesh_quantization GLBs to plain float32 GLBs for Godot 4.

Godot's glTF importer does not support KHR_mesh_quantization. The spec's
normalized integer -> float conversion is lossless enough for static props.
"""
import json
import struct
import sys
from pathlib import Path

COMP = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2), 5123: ("H", 2)}
NUM = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}
ATTRS = {"POSITION", "NORMAL", "TANGENT", "TEXCOORD_0", "TEXCOORD_1", "COLOR_0"}


def decode(c, component_type):
    if component_type == 5120:
        return max(c / 127.0, -1.0)
    if component_type == 5121:
        return c / 255.0
    if component_type == 5122:
        return max(c / 32767.0, -1.0)
    return c / 65535.0


def dequantize(path: Path) -> None:
    raw = path.read_bytes()
    total = struct.unpack_from("<I", raw, 8)[0]
    off, chunks = 12, {}
    while off < total:
        length, ctype = struct.unpack_from("<II", raw, off)
        off += 8
        chunks[ctype] = bytearray(raw[off:off + length])
        off += length
    gltf = json.loads(chunks[0x4E4F534A].decode("utf-8"))
    binary = chunks[0x004E4942]

    targets = set()
    for mesh in gltf.get("meshes", []):
        for prim in mesh.get("primitives", []):
            for name, idx in prim.get("attributes", {}).items():
                if name in ATTRS:
                    targets.add(idx)

    appended = bytearray()
    new_views = []
    for idx in sorted(targets):
        acc = gltf["accessors"][idx]
        ct = int(acc["componentType"])
        if ct not in COMP or not acc.get("normalized", False):
            continue
        fmt, size = COMP[ct]
        n = NUM[acc["type"]]
        view = gltf["bufferViews"][acc["bufferView"]]
        base = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
        stride = view.get("byteStride", n * size)
        count = int(acc["count"])
        while len(appended) % 4:
            appended.append(0)
        new_offset = len(appended)
        for i in range(count):
            for c in range(n):
                pos = base + i * stride + c * size
                value = struct.unpack_from("<" + fmt, binary, pos)[0]
                appended.extend(struct.pack("<f", decode(value, ct)))
        new_views.append({
            "buffer": 0, "byteOffset": new_offset, "byteLength": count * n * 4,
            "target": 34962,
        })
        acc["componentType"] = 5126
        acc.pop("normalized", None)
        acc["bufferView"] = len(gltf["bufferViews"]) + len(new_views) - 1
        acc["byteOffset"] = 0
        if "min" in acc:
            acc["min"] = [decode(v, ct) for v in acc["min"]]
        if "max" in acc:
            acc["max"] = [decode(v, ct) for v in acc["max"]]

    gltf["bufferViews"].extend(new_views)
    binary.extend(appended)
    while len(binary) % 4:
        binary.append(0)
    gltf["buffers"][0]["byteLength"] = len(binary)
    gltf["extensionsUsed"] = [e for e in gltf.get("extensionsUsed", [])
                              if e != "KHR_mesh_quantization"]
    gltf["extensionsRequired"] = [e for e in gltf.get("extensionsRequired", [])
                                  if e != "KHR_mesh_quantization"]
    for key in ("extensionsUsed", "extensionsRequired"):
        if not gltf[key]:
            gltf.pop(key)

    json_bytes = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    json_bytes += b" " * ((4 - len(json_bytes) % 4) % 4)
    out = bytearray()
    out.extend(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(json_bytes) + 8 + len(binary)))
    out.extend(struct.pack("<II", len(json_bytes), 0x4E4F534A))
    out.extend(json_bytes)
    out.extend(struct.pack("<II", len(binary), 0x004E4942))
    out.extend(binary)
    path.write_bytes(out)
    print(f"dequantized {path.name}: {len(out)} bytes")


if __name__ == "__main__":
    for arg in sys.argv[1:]:
        dequantize(Path(arg))
