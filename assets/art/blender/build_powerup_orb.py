"""powerup_orb.glb — floating collectable orb (scaffold §16).

METRIC: sphere diameter 0.60 m, origin at the BASE of the object (z=0 in
Blender, y=0 in Godot) so the world code can drop it at a spawn point
without extra offset. The emissive hint lives in the material (Principled
Emission), which glTF carries over as emissiveFactor -> Godot emission.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402

from art_common import (  # noqa: E402
    PALETTE, add_sphere, add_torus, export_glb, make_material, mesh_count,
    new_root, report_bounds, reset_scene,
)

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..",
                   "art", "models", "powerup_orb.glb")
ROOT_NAME = "PowerUpRoot"

reset_scene()
root = new_root(ROOT_NAME)

R_CORE = 0.22          # bright inner core
R_SHELL = 0.30         # outer polished shell -> 0.60 m diameter

m_core = make_material("M_OrbCore", PALETTE["orb_core"], roughness=0.25,
                       emission_srgb=PALETTE["orb_core"],
                       emission_strength=3.5)
m_shell = make_material("M_OrbShell", PALETTE["orb_shell"], roughness=0.12,
                        metallic=0.35)
m_ring = make_material("M_OrbRing", PALETTE["orb_core"], roughness=0.2,
                       metallic=0.6, emission_srgb=PALETTE["orb_core"],
                       emission_strength=1.6)

# core sits at half height so the base of the orb touches the origin
add_sphere("Core", root, (0.0, 0.0, R_SHELL), radius=R_CORE, mat=m_core,
           segments=32, rings=24)

# outer shell: slightly flattened along Y so it reads as a bead, not a ball
add_sphere("Shell", root, (0.0, 0.0, R_SHELL), radius=R_SHELL, mat=m_shell,
           segments=32, rings=24, scale=(1.0, 0.88, 1.0))

# two orbit rings (the classic arcade pickup silhouette).
# major + minor is clamped to R_SHELL so the ring never dips below the
# origin plane: the whole orb keeps its base exactly on the ground.
RING_MINOR = 0.020
RING_MAJOR = R_SHELL - RING_MINOR - 0.001
add_torus("Ring_V", root, (0.0, 0.0, R_SHELL), major_radius=RING_MAJOR,
          minor_radius=RING_MINOR, mat=m_ring, major_segments=40,
          minor_segments=8, rotation=(0.0, 0.0, 0.0))
add_torus("Ring_H", root, (0.0, 0.0, R_SHELL), major_radius=RING_MAJOR,
          minor_radius=RING_MINOR, mat=m_ring, major_segments=40,
          minor_segments=8, rotation=(1.5708, 0.0, 0.0))

report_bounds("powerup_orb")
export_glb(ROOT_NAME, os.path.abspath(OUT))
print("[MESHES] powerup_orb = %d" % mesh_count())
