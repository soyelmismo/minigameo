"""props — prop_bench.glb + prop_sign.glb (scaffold §16).

Street props for the city block. METRIC scale, origin at the BASE of the
prop (z=0 in Blender, y=0 in Godot) so they drop onto the sidewalk.

  prop_bench: 1.8 m long park bench, wooden slats + metal frame
  prop_sign:  2.6 m tall street sign, post + emissive face plate
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402

from art_common import (  # noqa: E402
    PALETTE, add_cone, add_cube, add_cylinder, add_sphere, add_torus,
    export_glb, make_material, mesh_count, new_root, report_bounds,
    reset_scene,
)

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..",
                       "art", "models")


def build_bench():
    reset_scene()
    root = new_root("PropBenchRoot")

    m_wood = make_material("M_BenchWood", PALETTE["wood"], roughness=0.8)
    m_wood_dark = make_material("M_BenchWoodDark", PALETTE["wood_dark"],
                                roughness=0.85)
    m_metal = make_material("M_BenchMetal", PALETTE["metal"], roughness=0.4,
                            metallic=0.7)
    m_metal_dark = make_material("M_BenchMetalDark", PALETTE["metal_dark"],
                                 roughness=0.5, metallic=0.6)

    L = 1.8            # length
    H_SEAT = 0.45      # seat height
    H_BACK = 0.88      # top of backrest

    # legs: two A-frame sides, slight outward splay
    for sx in (-1, 1):
        x = sx * (L * 0.5 - 0.16)
        add_cube("LegF_%d" % (sx > 0), root, (x, 0.22, H_SEAT * 0.5),
                 (0.09, 0.09, H_SEAT), m_metal)
        add_cube("LegB_%d" % (sx > 0), root, (x, -0.22, H_SEAT * 0.5),
                 (0.09, 0.09, H_SEAT), m_metal)
        add_cube("Foot_%d" % (sx > 0), root, (x, 0.0, 0.03),
                 (0.22, 0.56, 0.06), m_metal_dark)

    # seat: three slats
    for i, y in enumerate((-0.19, 0.0, 0.19)):
        add_cube("SlatSeat_%d" % i, root, (0.0, y, H_SEAT), (L, 0.15, 0.05),
                 m_wood)

    # backrest: two slats, tilted back
    for i, (y, z) in enumerate(((-0.24, H_BACK - 0.10), (-0.24, H_BACK - 0.30))):
        add_cube("SlatBack_%d" % i, root, (0.0, y, z), (L, 0.05, 0.12),
                 m_wood, rotation=(0.18, 0.0, 0.0))

    # back support posts
    for sx in (-1, 1):
        add_cube("PostBack_%d" % (sx > 0), root,
                 (sx * (L * 0.5 - 0.16), -0.26, H_SEAT + 0.22),
                 (0.07, 0.07, 0.62), m_metal, rotation=(0.18, 0.0, 0.0))

    # armrests
    for sx in (-1, 1):
        add_cube("Arm_%d" % (sx > 0), root,
                 (sx * (L * 0.5 - 0.20), 0.0, H_SEAT + 0.20),
                 (0.12, 0.52, 0.06), m_wood_dark)

    report_bounds("prop_bench")
    export_glb("PropBenchRoot", os.path.join(OUT_DIR, "prop_bench.glb"))
    print("[MESHES] prop_bench = %d" % mesh_count())


def build_sign():
    reset_scene()
    root = new_root("PropSignRoot")

    m_post = make_material("M_SignPost", PALETTE["metal"], roughness=0.35,
                           metallic=0.75)
    m_face = make_material("M_SignFace", PALETTE["sign_face"], roughness=0.55)
    m_red = make_material("M_SignRed", PALETTE["sign_red"], roughness=0.6)
    m_glow = make_material("M_SignGlow", PALETTE["sign_glow"], roughness=0.4,
                           emission_srgb=PALETTE["sign_glow"],
                           emission_strength=2.4)
    m_dark = make_material("M_SignDark", PALETTE["metal_dark"], roughness=0.5,
                           metallic=0.5)

    H_POST = 2.60
    R_POST = 0.07

    # post + base + cap
    add_cylinder("Post", root, (0.0, 0.0, H_POST * 0.5), radius=R_POST,
                 depth=H_POST, mat=m_post, vertices=16)
    add_cylinder("Base", root, (0.0, 0.0, 0.10), radius=0.24, depth=0.20,
                 mat=m_dark, vertices=16)
    add_sphere("PostCap", root, (0.0, 0.0, H_POST), radius=R_POST * 1.25,
               mat=m_dark, segments=14, rings=10)

    # sign plate: hangs off the post, facing the street (+Y)
    PLATE_W, PLATE_H, PLATE_T = 0.95, 0.42, 0.06
    z_plate = 2.05
    y_plate = 0.30
    add_cube("Plate", root, (0.0, y_plate, z_plate),
             (PLATE_W, PLATE_T, PLATE_H), m_face)

    # red frame + a glowing arrow (the arcade "this way" cue)
    add_cube("FrameTop", root, (0.0, y_plate, z_plate + PLATE_H * 0.5),
             (PLATE_W + 0.08, PLATE_T + 0.03, 0.05), m_red)
    add_cube("FrameBot", root, (0.0, y_plate, z_plate - PLATE_H * 0.5),
             (PLATE_W + 0.08, PLATE_T + 0.03, 0.05), m_red)
    for sx in (-1, 1):
        add_cube("FrameSide_%d" % (sx > 0), root,
                 (sx * (PLATE_W + 0.04) * 0.5, y_plate, z_plate),
                 (0.05, PLATE_T + 0.03, PLATE_H), m_red)

    add_cube("ArrowShaft", root, (0.0, y_plate - 0.02, z_plate),
             (0.34, 0.02, 0.08), m_glow)
    add_cone("ArrowHead", root, (0.20, y_plate - 0.02, z_plate),
             radius1=0.13, radius2=0.0, depth=0.20, mat=m_glow, vertices=12,
             rotation=(0.0, -1.5708, 0.0))

    # bracket between post and plate
    add_cube("Bracket", root, (0.0, 0.14, z_plate), (0.16, 0.30, 0.06),
             m_dark)
    add_torus("BoltRing", root, (0.0, y_plate - 0.01, z_plate),
              major_radius=0.09, minor_radius=0.018, mat=m_dark,
              major_segments=16, minor_segments=6)

    report_bounds("prop_sign")
    export_glb("PropSignRoot", os.path.join(OUT_DIR, "prop_sign.glb"))
    print("[MESHES] prop_sign = %d" % mesh_count())


build_bench()
build_sign()
