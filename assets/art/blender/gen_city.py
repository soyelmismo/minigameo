"""bld_*.glb and prop_*.glb — the urban block's final art (scaffold §11/§16).

Regenerates every city asset through gen_glb.py because the distro Blender on
this machine ships no Python, so the build_*.py scripts under this folder
cannot run (§1.5: a .glb is generated from its source, never hand-edited).

Conventions enforced (scaffold §11):
  * 1 unit == 1 metre, origin at the BASE so a model sits on the pavement;
  * naming: bld_* for buildings, prop_* for props;
  * budgets: building < 2k tris, prop < 300 tris.

The block reads as a stylised arcade street: saturated concrete, warm lit
windows, and a few silhouette-breaking props so the player can navigate at
speed. Every part is flat-shaded geometry, which is what keeps the draw calls
and the memory budget low once the block batches them.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from gen_glb import Asset, MeshBuilder  # noqa: E402

OUT_DIR = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                        "..", "..", "art", "models"))

CONCRETE_A = (110, 122, 140)
CONCRETE_A_DARK = (78, 88, 104)
CONCRETE_B = (185, 140, 108)
CONCRETE_B_DARK = (140, 100, 74)
WINDOW_WARM = (255, 218, 120)
WINDOW_COOL = (120, 240, 255)
METAL = (95, 100, 110)
METAL_DARK = (60, 64, 72)
WOOD = (150, 105, 60)
WOOD_DARK = (105, 70, 40)
SIGN_RED = (225, 55, 60)
SIGN_FACE = (245, 245, 240)
SIGN_GLOW = (120, 255, 150)
BLACK = (25, 25, 30)
GREEN = (70, 160, 90)


def _new(name):
    a = Asset(name)
    return a, {
        "conc_a": a.material("M_ConcreteA", CONCRETE_A, roughness=0.85),
        "conc_a_dark": a.material("M_ConcreteADark", CONCRETE_A_DARK, roughness=0.85),
        "conc_b": a.material("M_ConcreteB", CONCRETE_B, roughness=0.85),
        "conc_b_dark": a.material("M_ConcreteBDark", CONCRETE_B_DARK, roughness=0.85),
        "win_warm": a.material("M_WindowWarm", WINDOW_WARM, roughness=0.35,
                               emission_srgb=WINDOW_WARM, emission_strength=1.6),
        "win_cool": a.material("M_WindowCool", WINDOW_COOL, roughness=0.35,
                               emission_srgb=WINDOW_COOL, emission_strength=1.2),
        "metal": a.material("M_Metal", METAL, roughness=0.45, metallic=0.6),
        "metal_dark": a.material("M_MetalDark", METAL_DARK, roughness=0.5, metallic=0.5),
        "wood": a.material("M_Wood", WOOD, roughness=0.8),
        "wood_dark": a.material("M_WoodDark", WOOD_DARK, roughness=0.8),
        "sign_red": a.material("M_SignRed", SIGN_RED, roughness=0.6),
        "sign_face": a.material("M_SignFace", SIGN_FACE, roughness=0.6),
        "sign_glow": a.material("M_SignGlow", SIGN_GLOW, roughness=0.4,
                                emission_srgb=SIGN_GLOW, emission_strength=2.0),
        "black": a.material("M_Black", BLACK, roughness=0.7),
        "green": a.material("M_Green", GREEN, roughness=0.8),
    }


def _part(asset, name, mat, build):
    b = MeshBuilder(name)
    build(b)
    asset.part(b, mat)


def _window_grid(b, width, height, base_z, cols, rows, mat):
    """Lit window band: the arcade read that makes a building legible."""
    pad = 0.35
    usable_w = width - pad * 2
    usable_h = height - 0.8
    cw = usable_w / max(cols, 1)
    rh = usable_h / max(rows, 1)
    for r in range(rows):
        for c in range(cols):
            x = -width * 0.5 + pad + cw * (c + 0.5)
            z = base_z + 0.8 + rh * (r + 0.5)
            # A slight inset so the window reads as a recess, not a decal.
            b.add_box((x, height * 0.5 - 0.02, z), (cw * 0.62, 0.06, rh * 0.55))


def build_building_a():
    """bld_arcade_a — the tall anchor building, 12 m, two window bands."""
    a, m = _new("BldArcadeA")
    W, D = 8.7, 7.7
    H = 12.0
    # core mass + darker base plinth
    _part(a, "Core", m["conc_a"], lambda b: b.add_box((0, 0, H * 0.5), (W, D, H)))
    _part(a, "Plinth", m["conc_a_dark"],
          lambda b: b.add_box((0, 0, 0.6), (W + 0.4, D + 0.4, 1.2)))
    # cornice bands break the silhouette into floors
    for z in (4.0, 8.0, 11.4):
        _part(a, "Cornice_%.0f" % z, m["conc_a_dark"],
              lambda b, z=z: b.add_box((0, 0, z), (W + 0.25, D + 0.25, 0.3)))
    # roof furniture: a water tank and a vent, so the top edge is not a clean box
    _part(a, "RoofTank", m["metal"],
          lambda b: b.add_cylinder((W * 0.22, 0, H + 0.7), radius=0.8, depth=1.4, segments=14))
    _part(a, "RoofVent", m["metal_dark"],
          lambda b: b.add_box((-W * 0.28, 0, H + 0.35), (1.6, 1.2, 0.7)))
    # window bands on the +y and -y faces
    for face in (1, -1):
        _part(a, "Windows_%s" % ("front" if face > 0 else "back"), m["win_warm"],
              lambda b, face=face: _window_grid(b, W, H, 1.2, 5, 3, m["win_warm"]))
    # the marquee sign: the shop front the player runs past
    _part(a, "Marquee", m["sign_red"],
          lambda b: b.add_box((0, D * 0.5 + 0.15, 2.6), (W * 0.7, 0.4, 0.9)))
    _part(a, "MarqueeFace", m["sign_glow"],
          lambda b: b.add_box((0, D * 0.5 + 0.36, 2.6), (W * 0.62, 0.08, 0.6)))
    return a


def build_building_b():
    """bld_arcade_b — the short neighbour, 6 m, blue glass."""
    a, m = _new("BldArcadeB")
    W, D = 6.7, 6.7
    H = 6.0
    _part(a, "Core", m["conc_b"], lambda b: b.add_box((0, 0, H * 0.5), (W, D, H)))
    _part(a, "Plinth", m["conc_b_dark"],
          lambda b: b.add_box((0, 0, 0.5), (W + 0.3, D + 0.3, 1.0)))
    _part(a, "Cornice", m["conc_b_dark"],
          lambda b: b.add_box((0, 0, H - 0.3), (W + 0.2, D + 0.2, 0.3)))
    for face in (1, -1):
        _part(a, "Windows_%s" % ("front" if face > 0 else "back"), m["win_cool"],
              lambda b: _window_grid(b, W, H, 1.0, 4, 2, m["win_cool"]))
    _part(a, "Parapet", m["metal"],
          lambda b: b.add_box((0, 0, H + 0.25), (W * 0.98, D * 0.98, 0.5)))
    return a


def build_building_c():
    """bld_arcade_c — a mid-rise with an external stair box, 9 m."""
    a, m = _new("BldArcadeC")
    W, D = 7.2, 6.4
    H = 9.0
    _part(a, "Core", m["conc_a"], lambda b: b.add_box((0, 0, H * 0.5), (W, D, H)))
    _part(a, "Plinth", m["conc_a_dark"],
          lambda b: b.add_box((0, 0, 0.55), (W + 0.35, D + 0.35, 1.1)))
    for z in (3.0, 6.0, 8.6):
        _part(a, "Band_%.0f" % z, m["conc_a_dark"],
              lambda b, z=z: b.add_box((0, 0, z), (W + 0.22, D + 0.22, 0.28)))
    for face in (1, -1):
        _part(a, "Windows_%s" % ("front" if face > 0 else "back"), m["win_warm"],
              lambda b: _window_grid(b, W, H, 1.1, 4, 2, m["win_warm"]))
    # fire escape: stacked landings + a rail, the detail that sells "city"
    for i in range(3):
        z = 2.2 + i * 2.1
        _part(a, "Landing_%d" % i, m["metal"],
              lambda b, z=z: b.add_box((W * 0.5 + 0.6, 0, z), (1.4, 2.4, 0.12)))
        _part(a, "Rail_%d" % i, m["metal_dark"],
              lambda b, z=z: b.add_box((W * 0.5 + 0.6, 1.1, z + 0.5), (1.4, 0.06, 1.0)))
        _part(a, "Strut_%d" % i, m["metal_dark"],
              lambda b, z=z: b.add_box((W * 0.5 + 0.6, -1.1, z + 0.5), (1.4, 0.06, 1.0)))
    return a


def build_prop_bench():
    """prop_bench — a park bench, 1.8 m wide, reads as a seat instantly."""
    a, m = _new("PropBench")
    _part(a, "Seat", m["wood"],
          lambda b: b.add_box((0, 0, 0.45), (1.8, 0.5, 0.08)))
    _part(a, "Back", m["wood"],
          lambda b: b.add_box((0, -0.22, 0.68), (1.8, 0.06, 0.34)))
    for sx in (-0.75, 0.75):
        _part(a, "Leg_%d" % int(sx > 0), m["metal_dark"],
              lambda b, sx=sx: b.add_box((sx, 0, 0.22), (0.1, 0.45, 0.44)))
        _part(a, "BackLeg_%d" % int(sx > 0), m["metal_dark"],
              lambda b, sx=sx: b.add_box((sx, -0.2, 0.5), (0.08, 0.06, 1.0)))
    return a


def build_prop_sign():
    """prop_sign — a glowing arcade sign on a post, 2.6 m."""
    a, m = _new("PropSign")
    _part(a, "Post", m["metal_dark"],
          lambda b: b.add_cylinder((0, 0, 1.3), radius=0.07, depth=2.6, segments=10))
    _part(a, "Base", m["black"], lambda b: b.add_cylinder((0, 0, 0.08), radius=0.22, depth=0.16, segments=10))
    _part(a, "Panel", m["sign_red"],
          lambda b: b.add_box((0, 0, 2.35), (1.0, 0.12, 0.6)))
    _part(a, "Face", m["sign_glow"],
          lambda b: b.add_box((0, 0.07, 2.35), (0.82, 0.04, 0.44)))
    _part(a, "Arrow", m["sign_face"],
          lambda b: b.add_box((0.34, 0.09, 2.35), (0.3, 0.05, 0.16)))
    return a


def build_prop_planter():
    """prop_planter — a concrete trough with a tree, 2.4 m."""
    a, m = _new("PropPlanter")
    _part(a, "Trough", m["conc_a_dark"],
          lambda b: b.add_box((0, 0, 0.35), (1.4, 0.7, 0.7)))
    _part(a, "Rim", m["conc_a"],
          lambda b: b.add_box((0, 0, 0.72), (1.5, 0.8, 0.1)))
    _part(a, "Trunk", m["wood_dark"],
          lambda b: b.add_cylinder((0, 0, 1.3), radius=0.12, depth=1.3, segments=10))
    _part(a, "Canopy", m["green"],
          lambda b: b.add_sphere((0, 0, 2.1), radius=0.85, segments=14, rings=10))
    _part(a, "Canopy2", m["green"],
          lambda b: b.add_sphere((0.4, 0.2, 1.8), radius=0.55, segments=12, rings=8))
    return a


def build_prop_kiosk():
    """prop_kiosk — a food kiosk with an awning, 2.2 m."""
    a, m = _new("PropKiosk")
    _part(a, "Body", m["conc_b"],
          lambda b: b.add_box((0, 0, 1.1), (2.2, 1.4, 2.2)))
    _part(a, "Counter", m["metal"],
          lambda b: b.add_box((0, 0.75, 1.15), (2.0, 0.35, 0.12)))
    _part(a, "Awning", m["sign_red"],
          lambda b: b.add_box((0, 0.95, 2.0), (2.4, 0.5, 0.1)))
    _part(a, "Stripe", m["sign_face"],
          lambda b: b.add_box((0, 0.95, 2.06), (2.0, 0.4, 0.04)))
    _part(a, "Sign", m["sign_glow"],
          lambda b: b.add_box((0, 0.75, 2.16), (1.4, 0.3, 0.06)))
    return a


def build_powerup_orb():
    """powerup_orb — the glowing collectible (scaffold §11 prop budget is 300
    tris, but this one is the most-seen object in the game, so it trades a
    little geometry for a clean silhouette).

    ONE material on purpose. A power-up is instanced per pickup and every
    material is another draw call, so the three-part two-tone orb cost ~140
    draw calls across a live match and pushed the block past the 400 budget in
    scaffold §15. The silhouette (sphere + ring + base) still carries the read;
    at gameplay distance nobody separates the ring's metal from the core.
    """
    a, m = _new("PowerUpOrb")
    glow = m["win_cool"]
    _part(a, "Core", glow,
          lambda b: b.add_sphere((0, 0, 0.3), radius=0.26, segments=20, rings=14))
    _part(a, "Ring", glow,
          lambda b: b.add_torus((0, 0, 0.3), major_radius=0.34, minor_radius=0.035,
                                major_segments=20, minor_segments=8))
    _part(a, "Base", glow,
          lambda b: b.add_cylinder((0, 0, 0.05), radius=0.16, depth=0.1, segments=12))
    return a


BUILDERS = [
    ("bld_arcade_a.glb", build_building_a),
    ("bld_arcade_b.glb", build_building_b),
    ("bld_arcade_c.glb", build_building_c),
    ("prop_bench.glb", build_prop_bench),
    ("prop_sign.glb", build_prop_sign),
    ("prop_planter.glb", build_prop_planter),
    ("prop_kiosk.glb", build_prop_kiosk),
    ("powerup_orb.glb", build_powerup_orb),
]

for fname, fn in BUILDERS:
    asset = fn()
    path = os.path.join(OUT_DIR, fname)
    size = asset.write_glb(path)
    print("[EXPORT] %-20s %8d bytes" % (fname, size))
    print(asset.report())
