"""buildings — building_a.glb + building_b.glb (scaffold §16).

Two stylised city-block towers. Each is a plain box mass with emissive
window bands and a roofline cap, built at METRIC scale with the origin at
the BASE of the building (street contact, z=0 in Blender / y=0 in Godot),
so city_block.gd can place them by ground position.

  building_a: 8.0 m wide x 7.0 m deep x 12.0 m tall  (warm concrete)
  building_b: 6.5 m wide x 6.5 m deep x  9.5 m tall  (terracotta, stepped)
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402

from art_common import (  # noqa: E402
    PALETTE, add_cube, add_cylinder, add_sphere, export_glb, make_material,
    mesh_count, new_root, report_bounds, reset_scene,
)

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..",
                       "art", "models")


def window_band(root, mat, z, w, d, band_h=1.05, inset=0.02):
    """Four emissive strips wrapping the tower at height z."""
    add_cube("WinN", root, (0.0, -(d * 0.5 + inset), z), (w, 0.06, band_h), mat)
    add_cube("WinS", root, (0.0, (d * 0.5 + inset), z), (w, 0.06, band_h), mat)
    add_cube("WinE", root, ((w * 0.5 + inset), 0.0, z), (0.06, d, band_h), mat)
    add_cube("WinW", root, (-(w * 0.5 + inset), 0.0, z), (0.06, d, band_h), mat)


def cornice(root, mat, z, w, d, overhang=0.35, thick=0.22):
    """Roof lip that makes the silhouette read as a building, not a crate."""
    add_cube("Cornice", root, (0.0, 0.0, z + thick * 0.5),
             (w + overhang * 2, d + overhang * 2, thick), mat)


def build_building_a():
    reset_scene()
    root = new_root("BuildingARoot")
    W, D, H = 8.0, 7.0, 12.0

    m_wall = make_material("M_BldAWall", PALETTE["concrete_a"], roughness=0.88)
    m_wall_dark = make_material("M_BldAWallDark", PALETTE["concrete_a_dark"],
                                roughness=0.9)
    m_win = make_material("M_BldAWin", PALETTE["window_warm"], roughness=0.4,
                          emission_srgb=PALETTE["window_warm"],
                          emission_strength=2.2)

    # main mass + a darker ground-floor plinth (arcade readable base)
    add_cube("Mass", root, (0.0, 0.0, H * 0.5), (W, D, H), m_wall)
    add_cube("Plinth", root, (0.0, 0.0, 0.45), (W * 1.02, D * 1.02, 0.9),
             m_wall_dark)

    # window bands: 6 floors, skipping the ground floor
    for i in range(6):
        window_band(root, m_win, 2.0 + i * 1.7, W, D)

    # roofline: cornice + a small AC box + antenna for the skyline
    cornice(root, m_wall_dark, H, W, D)
    add_cube("RoofBox", root, (1.6, -1.4, H + 0.55), (2.4, 1.8, 1.1),
             m_wall_dark)
    add_cylinder("Antenna", root, (-2.6, 1.8, H + 1.1), radius=0.06,
                 depth=2.2, mat=m_wall_dark, vertices=10)
    add_sphere("AntennaTip", root, (-2.6, 1.8, H + 2.2), radius=0.1,
               mat=m_win, segments=12, rings=8)

    report_bounds("building_a")
    export_glb("BuildingARoot", os.path.join(OUT_DIR, "building_a.glb"))
    print("[MESHES] building_a = %d" % mesh_count())


def build_building_b():
    reset_scene()
    root = new_root("BuildingBRoot")
    W, D, H = 6.5, 6.5, 9.5

    m_wall = make_material("M_BldBWall", PALETTE["concrete_b"], roughness=0.9)
    m_wall_dark = make_material("M_BldBWallDark", PALETTE["concrete_b_dark"],
                                roughness=0.9)
    m_win = make_material("M_BldBWin", PALETTE["window_cool"], roughness=0.4,
                          emission_srgb=PALETTE["window_cool"],
                          emission_strength=2.0)

    # stepped mass: lower wide block + narrower upper block (setback tower)
    add_cube("MassLower", root, (0.0, 0.0, 6.0), (W, D, 6.0), m_wall)
    add_cube("MassUpper", root, (0.0, 0.0, 8.0), (W * 0.78, D * 0.78, 4.0),
             m_wall)
    add_cube("Plinth", root, (0.0, 0.0, 0.4), (W * 1.03, D * 1.03, 0.8),
             m_wall_dark)

    # window bands on both masses
    for i in range(3):
        window_band(root, m_win, 1.7 + i * 1.55, W, D)
    for i in range(2):
        window_band(root, m_win, 6.9 + i * 1.5, W * 0.78, D * 0.78)

    cornice(root, m_wall_dark, H, W * 0.78, D * 0.78, overhang=0.4)
    # shop awning on the ground floor: the arcade street cue
    add_cube("Awning", root, (0.0, -(D * 0.5 + 0.5), 2.6),
             (W * 0.9, 1.1, 0.12), m_wall_dark)

    report_bounds("building_b")
    export_glb("BuildingBRoot", os.path.join(OUT_DIR, "building_b.glb"))
    print("[MESHES] building_b = %d" % mesh_count())


build_building_a()
build_building_b()
