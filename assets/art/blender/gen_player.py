"""player_idle.glb — stylised arcade protagonist, idle pose (scaffold §11/§16).

METRIC: total height 1.80 m, origin at the BASE (feet on z=0 here, y=0 in Godot)
so the model drops straight onto the street. Tris stay well under the 8k
character budget from scaffold §11.

The proportions are the ones the original Blender builder specified
(assets/art/blender/build_player_idle.py); that pipeline cannot run on this
machine because the distro Blender ships no Python, so this regenerates the
same asset from the same numbers through gen_glb.py instead (§1.5: the .glb is
always generated, never hand-edited).

Silhouette: capsule torso, sphere head, tapered limbs — flat saturated colours
that read at 20 m, which is what the thematic props depend on for legibility.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from gen_glb import Asset, MeshBuilder  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..",
                   "art", "models", "player_idle.glb")

# Scaffold §11 palette, authored in sRGB 0..255.
SKIN = (250, 200, 165)
HAIR = (60, 40, 35)
EYE = (20, 20, 30)
JACKET = (242, 90, 40)
JACKET_DARK = (200, 65, 25)
PANTS = (45, 70, 190)
SHOE = (240, 240, 245)

# Heights measured from the sole, in metres.
H_FOOT = 0.10
H_ANKLE = 0.14
H_KNEE = 0.48
H_HIP = 0.86
H_CHEST = 1.20
H_SHOULDER = 1.34
H_NECK = 1.42
H_HEAD = 1.79

asset = Asset("PlayerRoot")
m_skin = asset.material("M_Skin", SKIN, roughness=0.65)
m_hair = asset.material("M_Hair", HAIR, roughness=0.55)
m_eye = asset.material("M_Eye", EYE, roughness=0.25)
m_jacket = asset.material("M_Jacket", JACKET, roughness=0.7)
m_jacket_dark = asset.material("M_JacketDark", JACKET_DARK, roughness=0.7)
m_pants = asset.material("M_Pants", PANTS, roughness=0.75)
m_shoe = asset.material("M_Shoe", SHOE, roughness=0.5)


def part(name, mat, build):
    b = MeshBuilder(name)
    build(b)
    asset.part(b, mat)
    return b


# ---------- feet: sole + ankle cuff, so the silhouette has a grounded base
for side, sx in (("L", -1), ("R", 1)):
    part("Foot_%s" % side, m_shoe,
         lambda b, sx=sx: b.add_box((sx * 0.13, 0.06, H_FOOT * 0.5),
                                    (0.22, 0.34, H_FOOT)))
    part("Cuff_%s" % side, m_shoe,
         lambda b, sx=sx: b.add_box((sx * 0.13, 0.05, H_ANKLE + 0.02),
                                    (0.17, 0.26, 0.09)))

# ---------- legs: tapered thigh + knee sphere + shin
for side, sx in (("L", -1), ("R", 1)):
    part("Leg_%s" % side, m_pants,
         lambda b, sx=sx: b.add_cone((sx * 0.14, 0.02, (H_HIP + H_KNEE) * 0.5),
                                     radius1=0.13, radius2=0.09,
                                     depth=H_HIP - H_KNEE, segments=16))
    part("Knee_%s" % side, m_pants,
         lambda b, sx=sx: b.add_sphere((sx * 0.14, 0.02, H_KNEE), radius=0.115,
                                       segments=16, rings=12))
    part("Shin_%s" % side, m_pants,
         lambda b, sx=sx: b.add_cone((sx * 0.14, 0.02, (H_KNEE + H_ANKLE) * 0.5),
                                     radius1=0.095, radius2=0.085,
                                     depth=H_KNEE - H_ANKLE, segments=16))

# ---------- torso
part("Hips", m_pants,
     lambda b: b.add_cone((0.0, 0.0, (H_HIP + H_CHEST) * 0.5 - 0.06),
                          radius1=0.20, radius2=0.24,
                          depth=H_CHEST - H_HIP + 0.12, segments=20))
part("Torso", m_jacket,
     lambda b: b.add_cylinder((0.0, 0.0, (H_CHEST + H_SHOULDER) * 0.5 + 0.04),
                              radius=0.235, depth=H_SHOULDER - H_CHEST + 0.10,
                              segments=20))
# chest stripe + collar band: the two-tone arcade read
part("Belt", m_jacket_dark,
     lambda b: b.add_cylinder((0.0, 0.0, H_HIP + 0.05), radius=0.215, depth=0.07,
                              segments=20))
part("Collar", m_jacket_dark,
     lambda b: b.add_cylinder((0.0, 0.0, H_SHOULDER + 0.03), radius=0.185,
                              depth=0.08, segments=20))
for side, sx in (("L", -1), ("R", 1)):
    part("Pauldrone_%s" % side, m_jacket,
         lambda b, sx=sx: b.add_sphere((sx * 0.235, 0.0, H_SHOULDER),
                                       radius=0.105, segments=16, rings=12))

# ---------- arms: idle pose, hanging with a slight outward angle
for side, sx in (("L", -1), ("R", 1)):
    ax = sx * 0.285
    part("Arm_%s" % side, m_jacket,
         lambda b, ax=ax: b.add_cone((ax, 0.01, (H_SHOULDER + H_HIP) * 0.5),
                                     radius1=0.075, radius2=0.062,
                                     depth=H_SHOULDER - H_HIP - 0.04,
                                     segments=14))
    part("Elbow_%s" % side, m_jacket,
         lambda b, ax=ax, sx=sx: b.add_sphere(
             (ax + sx * 0.005, 0.01, H_HIP + 0.02), radius=0.068,
             segments=14, rings=10))
    part("Forearm_%s" % side, m_jacket,
         lambda b, ax=ax, sx=sx: b.add_cone(
             (ax + sx * 0.01, 0.01, (H_HIP + H_KNEE) * 0.5 - 0.02),
             radius1=0.062, radius2=0.052, depth=H_HIP - H_KNEE + 0.02,
             segments=14))
    part("Hand_%s" % side, m_skin,
         lambda b, ax=ax, sx=sx: b.add_sphere(
             (ax + sx * 0.012, 0.01, H_KNEE + 0.06), radius=0.062,
             segments=14, rings=10))

# ---------- head: skull, hair cap, face direction marker, eyes
part("Head", m_skin,
     lambda b: b.add_sphere((0.0, 0.0, (H_NECK + H_HEAD) * 0.5), radius=0.19,
                            segments=24, rings=18))
part("Hair", m_hair,
     lambda b: b.add_sphere((0.0, 0.0, (H_NECK + H_HEAD) * 0.5 - 0.015),
                            radius=0.19, segments=24, rings=12))
part("Neck", m_skin,
     lambda b: b.add_cylinder((0.0, 0.0, (H_NECK + H_CHEST) * 0.5), radius=0.06,
                              depth=0.14, segments=12))
# Eyes sit on +y, which becomes the character's forward in Godot, so the face
# direction survives the y-up conversion.
for side, sx in (("L", -1), ("R", 1)):
    part("Eye_%s" % side, m_eye,
         lambda b, sx=sx: b.add_sphere(
             (sx * 0.07, 0.165, (H_NECK + H_HEAD) * 0.5 + 0.02), radius=0.028,
             segments=12, rings=8))

size = asset.write_glb(os.path.normpath(OUT))
print("[EXPORT] player_idle.glb %d bytes" % size)
print(asset.report())
