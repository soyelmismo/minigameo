"""player_idle.glb — stylised arcade protagonist, idle pose (scaffold §16).

METRIC: total height ~1.80 m, footprint fits inside a 1 x 1.8 x 1 m box
(AGENTS.md brief). Origin is the BASE of the character (feet on z=0 in
Blender, y=0 in Godot) so it can be dropped straight onto the street.

Silhouette: capsule torso, sphere head, tapered limbs — clean shapes and
flat saturated colours, arcade-Nintendo readable at 20 m.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402

from art_common import (  # noqa: E402
    PALETTE, add_cone, add_cube, add_cylinder, add_sphere, export_glb,
    make_material, mesh_count, new_root, report_bounds, reset_scene,
)

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..",
                   "art", "models", "player_idle.glb")
ROOT_NAME = "PlayerRoot"

reset_scene()
root = new_root(ROOT_NAME)

m_skin = make_material("M_Skin", PALETTE["skin"], roughness=0.65)
m_hair = make_material("M_Hair", PALETTE["hair"], roughness=0.55)
m_eye = make_material("M_Eye", PALETTE["eye"], roughness=0.25)
m_jacket = make_material("M_Jacket", PALETTE["jacket"], roughness=0.7)
m_jacket_dark = make_material("M_JacketDark", PALETTE["jacket_dark"],
                              roughness=0.7)
m_pants = make_material("M_Pants", PALETTE["pants"], roughness=0.75)
m_shoe = make_material("M_Shoe", PALETTE["shoe"], roughness=0.5)

# ---------------------------------------------------------------- proportions
# Heights are measured from the sole (z = 0).
H_FOOT = 0.10
H_ANKLE = 0.14
H_KNEE = 0.48
H_HIP = 0.86
H_CHEST = 1.20
H_SHOULDER = 1.34
H_NECK = 1.42
H_HEAD = 1.79          # top of skull (keeps the whole body inside 1.8 m)

# ------------------------------------------------------------------- feet
for side, sx in (("L", -1), ("R", 1)):
    add_cube("Foot_%s" % side, root, (sx * 0.13, 0.06, H_FOOT * 0.5),
             (0.22, 0.34, H_FOOT), m_shoe)
    # ankle cuff of the trainer
    add_cube("Cuff_%s" % side, root, (sx * 0.13, 0.05, H_ANKLE + 0.02),
             (0.17, 0.26, 0.09), m_shoe)

# ------------------------------------------------------------------- legs
# Tapered capsule-ish legs: cone from hip (narrow) to ankle (narrower) plus
# a knee sphere so the silhouette stays round at speed.
for side, sx in (("L", -1), ("R", 1)):
    add_cone("Leg_%s" % side, root, (sx * 0.14, 0.02, (H_HIP + H_KNEE) * 0.5),
             radius1=0.13, radius2=0.09, depth=H_HIP - H_KNEE,
             mat=m_pants, vertices=16)
    add_sphere("Knee_%s" % side, root, (sx * 0.14, 0.02, H_KNEE), radius=0.115,
               mat=m_pants, segments=16, rings=12)
    add_cone("Shin_%s" % side, root, (sx * 0.14, 0.02, (H_KNEE + H_ANKLE) * 0.5),
             radius1=0.095, radius2=0.085, depth=H_KNEE - H_ANKLE,
             mat=m_pants, vertices=16)

# ------------------------------------------------------------------ torso
add_cone("Hips", root, (0.0, 0.0, (H_HIP + H_CHEST) * 0.5 - 0.06),
         radius1=0.20, radius2=0.24, depth=H_CHEST - H_HIP + 0.12,
         mat=m_pants, vertices=20)
add_cylinder("Torso", root, (0.0, 0.0, (H_CHEST + H_SHOULDER) * 0.5 + 0.04),
             radius=0.235, depth=H_SHOULDER - H_CHEST + 0.10, mat=m_jacket,
             vertices=20)
# chest stripe + collar band: the two-tone arcade read
add_cylinder("Belt", root, (0.0, 0.0, H_HIP + 0.05), radius=0.215,
             depth=0.07, mat=m_jacket_dark, vertices=20)
add_cylinder("Collar", root, (0.0, 0.0, H_SHOULDER + 0.03), radius=0.185,
             depth=0.08, mat=m_jacket_dark, vertices=20)
# shoulder pads keep the arms from clipping the torso
for side, sx in (("L", -1), ("R", 1)):
    add_sphere("Pauldrone_%s" % side, root, (sx * 0.235, 0.0, H_SHOULDER),
               radius=0.105, mat=m_jacket, segments=16, rings=12)

# ------------------------------------------------------------------- arms
# Idle pose: arms hang with a slight outward angle, hands open.
for side, sx in (("L", -1), ("R", 1)):
    ax = sx * 0.285
    add_cone("Arm_%s" % side, root, (ax, 0.01, (H_SHOULDER + H_HIP) * 0.5),
             radius1=0.075, radius2=0.062, depth=H_SHOULDER - H_HIP - 0.04,
             mat=m_jacket, vertices=14)
    add_sphere("Elbow_%s" % side, root, (ax + sx * 0.005, 0.01, H_HIP + 0.02),
               radius=0.068, mat=m_jacket, segments=14, rings=10)
    add_cone("Forearm_%s" % side, root,
             (ax + sx * 0.01, 0.01, (H_HIP + H_KNEE) * 0.5 - 0.02),
             radius1=0.062, radius2=0.052, depth=H_HIP - H_KNEE + 0.02,
             mat=m_jacket, vertices=14)
    add_sphere("Hand_%s" % side, root, (ax + sx * 0.015, 0.01, H_KNEE + 0.01),
               radius=0.062, mat=m_skin, segments=14, rings=10,
               scale=(1.0, 0.75, 1.25))

# ------------------------------------------------------------------- head
add_cylinder("Neck", root, (0.0, 0.0, (H_NECK + H_SHOULDER) * 0.5),
             radius=0.075, depth=H_NECK - H_SHOULDER + 0.06, mat=m_skin,
             vertices=14)
head_r = (H_HEAD - H_NECK) * 0.5
add_sphere("Skull", root, (0.0, 0.0, H_NECK + head_r), radius=head_r,
           mat=m_skin, segments=24, rings=18, scale=(1.0, 0.95, 1.05))
# hair cap + a fringe, so the head reads as a head and not a ball
add_sphere("HairCap", root, (0.0, -0.01, H_NECK + head_r * 1.12),
           radius=head_r * 1.04, mat=m_hair, segments=20, rings=14,
           scale=(1.02, 1.0, 0.78))
add_cube("Fringe", root, (0.0, 0.055, H_NECK + head_r * 1.12),
         (0.30, 0.06, 0.10), m_hair)
# eyes + mouth: minimal arcade face, readable from any distance
for side, sx in (("L", -1), ("R", 1)):
    add_sphere("Eye_%s" % side, root, (sx * 0.075, head_r * 0.86,
                                       H_NECK + head_r * 1.02),
               radius=0.032, mat=m_eye, segments=12, rings=8)
add_cube("Mouth", root, (0.0, head_r * 0.9, H_NECK + head_r * 0.72),
         (0.10, 0.02, 0.025), m_hair)

report_bounds("player_idle")
export_glb(ROOT_NAME, os.path.abspath(OUT))
print("[MESHES] player_idle = %d" % mesh_count())
