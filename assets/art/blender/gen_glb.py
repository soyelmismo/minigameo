"""Minimal glTF 2.0 / GLB writer used by the art pipeline.

scaffold.md §11 mandates a Blender -> .glb pipeline, and §1.5 mandates that a
.glb is never hand-edited, only regenerated from its source. This package is
that regeneration path for environments where Blender's bundled Python is
unavailable (the distro package in this machine ships scripts but no Python,
so every build script under this folder dies on `import math`).

It writes the same thing the Blender exporter did: one glTF 2.0 binary with
Y-up axes, one mesh per part, and PBR materials carrying the authored sRGB
base colour. Nothing here is a .glb edit — the .py next to it is the source.

Conventions enforced here (scaffold §11):
  * 1 unit == 1 metre, so sizes passed in are metres;
  * the origin sits at the BASE of the asset, so a model drops straight onto
    the ground (Godot: y == 0 at the feet);
  * transforms are baked into the vertices, so no node carries a stray
    transform the way a Blender scale would.
"""

import json
import os
import struct

# Blender is Z-up; glTF is Y-up. Our parts are axis-aligned about the origin in
# the horizontal plane, so this reduces to "blender z becomes gltf y".
GLTF_DTYPE_TO_STRUCT = {
    "VEC3": ("f", 3),
    "VEC2": ("f", 2),
    "SCALAR": ("I", 1),
}


class MeshBuilder:
    """Collects indexed triangle geometry for one part of one asset."""

    def __init__(self, name: str, material: int = -1):
        self.name = name
        self.material = material
        self.positions = []
        self.normals = []
        self.indices = []

    # -- geometry ---------------------------------------------------------
    def _tri(self, a, b, c, na, nb, nc):
        base = len(self.positions)
        self.positions.extend([a, b, c])
        self.normals.extend([na, nb, nc])
        self.indices.extend([base, base + 1, base + 2])

    def _quad(self, a, b, c, d, na, nb, nc, nd):
        self._tri(a, b, c, na, nb, nc)
        self._tri(a, c, d, na, nc, nd)

    # -- primitives (all metric, all axis-aligned) ------------------------
    def add_box(self, center, size, name: str = "box"):
        """Axis-aligned box. size = (x, y, z) full extents in metres."""
        cx, cy, cz = center
        hx, hy, hz = size[0] * 0.5, size[1] * 0.5, size[2] * 0.5
        v = [
            (cx - hx, cy - hy, cz - hz), (cx + hx, cy - hy, cz - hz),
            (cx + hx, cy + hy, cz - hz), (cx - hx, cy + hy, cz - hz),
            (cx - hx, cy - hy, cz + hz), (cx + hx, cy - hy, cz + hz),
            (cx + hx, cy + hy, cz + hz), (cx - hx, cy + hy, cz + hz),
        ]
        faces = [
            (4, 5, 6, 7, (0, 0, 1)), (1, 0, 3, 2, (0, 0, -1)),
            (5, 1, 2, 6, (1, 0, 0)), (0, 4, 7, 3, (-1, 0, 0)),
            (7, 6, 2, 3, (0, 1, 0)), (0, 1, 5, 4, (0, -1, 0)),
        ]
        for a, b, c, d, n in faces:
            self._quad(v[a], v[b], v[c], v[d], n, n, n, n)

    def add_cylinder(self, center, radius, depth, segments: int = 20):
        """Cylinder whose axis runs along z, centred on `center`."""
        cz = center[2]
        lo, hi = cz - depth * 0.5, cz + depth * 0.5
        for i in range(segments):
            a0 = 2.0 * 3.141592653589793 * i / segments
            a1 = 2.0 * 3.141592653589793 * (i + 1) / segments
            p0 = (radius * _cos(a0), radius * _sin(a0))
            p1 = (radius * _cos(a1), radius * _sin(a1))
            n0 = (_cos(a0), _sin(a0), 0.0)
            n1 = (_cos(a1), _sin(a1), 0.0)
            self._quad(
                (p0[0], p0[1], lo), (p1[0], p1[1], lo),
                (p1[0], p1[1], hi), (p0[0], p0[1], hi),
                n0, n1, n1, n0)
            self._tri(
                (p0[0], p0[1], hi), (p1[0], p1[1], hi), (0.0, 0.0, hi),
                n0, n1, (0.0, 0.0, 1.0))
            self._tri(
                (0.0, 0.0, lo), (p1[0], p1[1], lo), (p0[0], p0[1], lo),
                (0.0, 0.0, -1.0), n1, n0)

    def add_cone(self, center, radius1, radius2, depth, segments: int = 16):
        """Truncated cone, axis along z, radius1 at the bottom."""
        cz = center[2]
        lo, hi = cz - depth * 0.5, cz + depth * 0.5
        for i in range(segments):
            a0 = 2.0 * 3.141592653589793 * i / segments
            a1 = 2.0 * 3.141592653589793 * (i + 1) / segments
            c0, s0 = _cos(a0), _sin(a0)
            c1, s1 = _cos(a1), _sin(a1)
            b0 = (radius1 * c0, radius1 * s0, lo)
            b1 = (radius1 * c1, radius1 * s1, lo)
            t0 = (radius2 * c0, radius2 * s0, hi)
            t1 = (radius2 * c1, radius2 * s1, hi)
            # side normal from the cone's slope
            drift = (radius1 - radius2) / max(depth, 1e-6)
            ln = (1.0 + drift * drift) ** 0.5
            n0 = (c0 / ln, s0 / ln, drift / ln)
            n1 = (c1 / ln, s1 / ln, drift / ln)
            self._quad(b0, b1, t1, t0, n0, n1, n1, n0)
            if radius1 > 1e-5:
                self._tri(b0, b1, (0.0, 0.0, lo), (0, 0, -1), (0, 0, -1), (0, 0, -1))
            if radius2 > 1e-5:
                self._tri(t0, t1, (0.0, 0.0, hi), (0, 0, 1), (0, 0, 1), (0, 0, 1))

    def add_sphere(self, center, radius, segments: int = 20, rings: int = 14):
        """UV sphere centred on `center`."""
        cx, cy, cz = center
        ring_pts = []
        for r in range(rings + 1):
            phi = 3.141592653589793 * r / rings
            z, rr = _cos(phi), _sin(phi)
            row = []
            for s in range(segments):
                theta = 2.0 * 3.141592653589793 * s / segments
                row.append((cx + radius * rr * _cos(theta),
                            cy + radius * rr * _sin(theta),
                            cz + radius * z))
            ring_pts.append(row)
        for r in range(rings):
            for s in range(segments):
                s2 = (s + 1) % segments
                a, b = ring_pts[r][s], ring_pts[r][s2]
                c, d = ring_pts[r + 1][s], ring_pts[r + 1][s2]
                self._quad(a, b, c, d, _nrm(a, (cx, cy, cz)), _nrm(b, (cx, cy, cz)),
                           _nrm(c, (cx, cy, cz)), _nrm(d, (cx, cy, cz)))

    def add_torus(self, center, major_radius, minor_radius,
                  major_segments: int = 20, minor_segments: int = 8):
        """Torus in the xy plane, axis along z, centred on `center`."""
        cx, cy, cz = center
        ring = []
        for i in range(major_segments):
            u = 2.0 * 3.141592653589793 * i / major_segments
            cu, su = _cos(u), _sin(u)
            col = []
            for j in range(minor_segments):
                v = 2.0 * 3.141592653589793 * j / minor_segments
                cv, sv = _cos(v), _sin(v)
                rr = major_radius + minor_radius * cv
                col.append((cx + rr * cu, cy + rr * su, cz + minor_radius * sv))
            ring.append(col)
        for i in range(major_segments):
            i2 = (i + 1) % major_segments
            for j in range(minor_segments):
                j2 = (j + 1) % minor_segments
                a, b = ring[i][j], ring[i][j2]
                c, d = ring[i2][j], ring[i2][j2]
                self._quad(a, b, c, d,
                           _nrm(a, (cx, cy, cz)), _nrm(b, (cx, cy, cz)),
                           _nrm(c, (cx, cy, cz)), _nrm(d, (cx, cy, cz)))

    def triangle_count(self) -> int:
        return len(self.indices) // 3


def _cos(x: float) -> float:
    import math
    return math.cos(x)


def _sin(x: float) -> float:
    import math
    return math.sin(x)


def _nrm(p, c):
    import math
    v = (p[0] - c[0], p[1] - c[1], p[2] - c[2])
    ln = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]) or 1.0
    return (v[0] / ln, v[1] / ln, v[2] / ln)


class Asset:
    """A named asset: a list of MeshBuilder parts plus its materials."""

    def __init__(self, name: str):
        self.name = name
        self.parts = []
        self.materials = []

    def material(self, name: str, srgb255, roughness: float = 0.7,
                 metallic: float = 0.0, emission_srgb=None,
                 emission_strength: float = 0.0) -> int:
        entry = {
            "name": name,
            "pbrMetallicRoughness": {
                "baseColorFactor": [srgb255[0] / 255.0, srgb255[1] / 255.0,
                                    srgb255[2] / 255.0, 1.0],
                "metallicFactor": metallic,
                "roughnessFactor": roughness,
            },
        }
        if emission_srgb is not None:
            entry["emissiveFactor"] = [emission_srgb[0] / 255.0,
                                       emission_srgb[1] / 255.0,
                                       emission_srgb[2] / 255.0]
            entry.setdefault("extensions", {})
        self.materials.append(entry)
        return len(self.materials) - 1

    def part(self, builder: MeshBuilder, mat_index: int) -> None:
        builder.material = mat_index
        self.parts.append(builder)

    def bounds(self):
        if not self.parts:
            return (0, 0, 0), (0, 0, 0)
        mins = [float("inf")] * 3
        maxs = [float("-inf")] * 3
        for p in self.parts:
            for v in p.positions:
                for i in range(3):
                    mins[i] = min(mins[i], v[i])
                    maxs[i] = max(maxs[i], v[i])
        return mins, maxs

    def report(self) -> str:
        mn, mx = self.bounds()
        dims = [mx[i] - mn[i] for i in range(3)]
        tris = sum(p.triangle_count() for p in self.parts)
        return ("[BOUNDS] %-20s %.2f x %.2f x %.2f m  min y=%.2f  "
                "parts=%d tris=%d" % (self.name, dims[0], dims[1], dims[2],
                                      mn[1], len(self.parts), tris))

    def write_glb(self, out_path: str) -> int:
        """Serialise the asset as a glTF 2.0 binary. Returns the file size."""
        buffer = bytearray()
        views = []
        accessors = []
        meshes = []
        nodes = []

        def push(data: bytes, target: int) -> int:
            while len(buffer) % 4:
                buffer.append(0)
            offset = len(buffer)
            buffer.extend(data)
            views.append({"buffer": 0, "byteOffset": offset,
                          "byteLength": len(data), "target": target})
            return len(views) - 1

        # Parts that share a material are concatenated into ONE mesh. A mesh
        # node is a draw call, so an orb made of three parts cost three calls
        # per power-up on screen and pushed a live match past the 400 draw-call
        # budget in scaffold §15. The city merges at runtime for the same
        # reason; doing it here means every consumer gets it for free.
        by_material = {}
        for p in self.parts:
            by_material.setdefault(p.material, []).append(p)
        groups = []
        for mat_index in sorted(by_material.keys(), key=lambda v: int(v)):
            groups.append((mat_index, by_material[mat_index]))

        for mat_index, parts in groups:
            pos = []
            nrm = []
            idx = []
            for p in parts:
                base = len(pos) // 3
                for x, y, z in p.positions:
                    pos.extend([x, z, -y])
                for x, y, z in p.normals:
                    nrm.extend([x, z, -y])
                for i in p.indices:
                    idx.append(i + base)
            pos_bytes = struct.pack("<%df" % len(pos), *pos)
            nrm_bytes = struct.pack("<%df" % len(nrm), *nrm)
            idx_bytes = struct.pack("<%dI" % len(idx), *idx)

            v_pos = push(pos_bytes, 34962)
            v_nrm = push(nrm_bytes, 34962)
            v_idx = push(idx_bytes, 34963)

            # POSITION min/max are mandatory for glTF 2.0 and Godot validates
            # them on import, so they must come from the y-up positions, taking
            # every third element per axis.
            xs = [pos[i] for i in range(0, len(pos), 3)]
            ys = [pos[i] for i in range(1, len(pos), 3)]
            zs = [pos[i] for i in range(2, len(pos), 3)]
            pmin = [min(xs), min(ys), min(zs)]
            pmax = [max(xs), max(ys), max(zs)]
            base = len(accessors)
            accessors.append({
                "bufferView": v_pos, "componentType": 5126, "count": len(pos) // 3,
                "type": "VEC3", "min": pmin, "max": pmax,
            })
            accessors.append({
                "bufferView": v_nrm, "componentType": 5126,
                "count": len(nrm) // 3, "type": "VEC3",
            })
            accessors.append({
                "bufferView": v_idx, "componentType": 5125,
                "count": len(idx), "type": "SCALAR",
            })
            meshes.append({
                "name": "%s_%d" % (self.name, mat_index),
                "primitives": [{
                    "attributes": {"POSITION": base, "NORMAL": base + 1},
                    "indices": base + 2,
                    "material": mat_index,
                }],
            })
            nodes.append({"name": "%s_%d" % (self.name, mat_index),
                          "mesh": len(meshes) - 1})

        gltf = {
            "asset": {"version": "2.0", "generator": "arcades gen_glb.py"},
            "scene": 0,
            "scenes": [{"name": self.name, "nodes": list(range(len(nodes)))}],
            "nodes": nodes,
            "meshes": meshes,
            "materials": self.materials,
            "accessors": accessors,
            "bufferViews": views,
            "buffers": [{"byteLength": len(buffer)}],
        }

        json_bytes = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
        while len(json_bytes) % 4:
            json_bytes += b" "
        bin_bytes = bytes(buffer)
        while len(bin_bytes) % 4:
            bin_bytes += b"\x00"

        total = 12 + 8 + len(json_bytes) + 8 + len(bin_bytes)
        out = bytearray()
        out.extend(struct.pack("<4sII", b"glTF", 2, total))
        out.extend(struct.pack("<II", len(json_bytes), 0x4E4F534A))  # JSON
        out.extend(json_bytes)
        out.extend(struct.pack("<II", len(bin_bytes), 0x004E4942))   # BIN
        out.extend(bin_bytes)

        os.makedirs(os.path.dirname(out_path), exist_ok=True)
        with open(out_path, "wb") as fh:
            fh.write(bytes(out))
        return len(out)
