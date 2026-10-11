"""Shared helpers for the Blender -> GLB art pipeline (scaffold §16, AGENTS.md §1.5).

Every asset builder in this folder starts from a factory-empty scene, builds
geometry with bpy primitives at METRIC scale (1 Blender unit == 1 metre ==
1 Godot unit), parents the parts to a root Empty placed at the BASE of the
object (so the exported origin is the ground contact point, z=0 in Blender /
y=0 in Godot), applies rotation+scale so no node carries a weird transform,
and exports a single GLB via the io_scene_gltf2 exporter.

NOTE ON COLOUR: Principled BSDF Base Color lives in linear space, while glTF
baseColorFactor is sRGB. We therefore convert every authored sRGB colour to
linear before writing it, so the saturated arcade palette survives the round
trip into Godot unchanged.
"""

import math
import os

import bpy

# --------------------------------------------------------------------------
# palette (authored in sRGB 0..255, converted to linear for the shader)
# --------------------------------------------------------------------------

PALETTE = {
    "skin": (250, 200, 165),
    "hair": (60, 40, 35),
    "eye": (20, 20, 30),
    "jacket": (242, 90, 40),      # hot orange-red
    "jacket_dark": (200, 65, 25),
    "pants": (45, 70, 190),       # arcade blue
    "shoe": (240, 240, 245),
    "orb_core": (90, 255, 230),
    "orb_shell": (35, 90, 120),
    "concrete_a": (110, 122, 140),
    "concrete_a_dark": (78, 88, 104),
    "concrete_b": (185, 140, 108),
    "concrete_b_dark": (140, 100, 74),
    "window_warm": (255, 218, 120),
    "window_cool": (120, 240, 255),
    "metal": (95, 100, 110),
    "metal_dark": (60, 64, 72),
    "wood": (150, 105, 60),
    "wood_dark": (105, 70, 40),
    "sign_red": (225, 55, 60),
    "sign_face": (245, 245, 240),
    "sign_glow": (120, 255, 150),
    "black": (25, 25, 30),
}


def srgb_to_linear(c: float) -> float:
    """sRGB transfer function -> linear light (what the shader socket wants)."""
    if c <= 0.04045:
        return c / 12.92
    return ((c + 0.055) / 1.055) ** 2.4


def linear_color(srgb255) -> tuple:
    """(r,g,b) in 0..255 sRGB -> (r,g,b,a) in linear float for the node socket."""
    return (
        srgb_to_linear(srgb255[0] / 255.0),
        srgb_to_linear(srgb255[1] / 255.0),
        srgb_to_linear(srgb255[2] / 255.0),
        1.0,
    )


def reset_scene() -> None:
    """Start from an empty scene so the exported GLB contains only our parts."""
    bpy.ops.wm.read_factory_settings(use_empty=True)


def new_root(name):
    """Empty at world origin. Parts are parented here; the base sits at z=0."""
    root = bpy.data.objects.new(name, None)
    root.empty_display_type = "PLAIN_AXES"
    bpy.context.scene.collection.objects.link(root)
    return root


def make_material(name, srgb255, roughness: float = 0.7,
                  metallic: float = 0.0, emission_srgb=None,
                  emission_strength: float = 0.0):
    """Flat / stylised Principled material. emission_* is the emissive hint."""
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    if bsdf is None:
        bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
        out = nt.nodes.new("ShaderNodeOutputMaterial")
        nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    bsdf.inputs["Base Color"].default_value = linear_color(srgb255)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emission_srgb is not None:
        bsdf.inputs["Emission Color"].default_value = linear_color(emission_srgb)
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    else:
        bsdf.inputs["Emission Color"].default_value = (0.0, 0.0, 0.0, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 0.0
    return mat


def _assign(obj, mat) -> None:
    if mat is None:
        return
    obj.data.materials.append(mat)


def _bake_and_link(obj, mat, root):
    """Apply rotation/scale (never location), assign material, parent to root."""
    _assign(obj, mat)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    obj.parent = root
    obj.select_set(False)
    return obj


# --------------------------------------------------------------------------
# primitive wrappers — all take world position + size in METRES
# --------------------------------------------------------------------------

def add_cube(name, root, loc, size, mat=None, rotation=(0.0, 0.0, 0.0)):
    """Axis-aligned box: size = (x, y, z) full extents in metres."""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (size[0], size[1], size[2])
    return _bake_and_link(obj, mat, root)


def add_cylinder(name, root, loc, radius, depth, mat=None,
                 vertices: int = 16, rotation=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius,
                                        depth=depth, location=loc,
                                        rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    return _bake_and_link(obj, mat, root)


def add_sphere(name, root, loc, radius, mat=None, segments: int = 24,
               rings: int = 16, scale=(1.0, 1.0, 1.0)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=loc,
                                         segments=segments, ring_count=rings)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    return _bake_and_link(obj, mat, root)


def add_cone(name, root, loc, radius1, radius2, depth, mat=None,
             vertices: int = 16, rotation=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius1,
                                    radius2=radius2, depth=depth,
                                    location=loc, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    return _bake_and_link(obj, mat, root)


def add_torus(name, root, loc, major_radius, minor_radius, mat=None,
              major_segments: int = 24, minor_segments: int = 8,
              rotation=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major_radius,
                                     minor_radius=minor_radius, location=loc,
                                     major_segments=major_segments,
                                     minor_segments=minor_segments,
                                     rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    return _bake_and_link(obj, mat, root)


# --------------------------------------------------------------------------
# export + verification
# --------------------------------------------------------------------------

def export_glb(root_name: str, out_path: str) -> str:
    """Export the whole (clean) scene as one GLB. Returns the written path."""
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=out_path,
        export_format="GLB",
        export_yup=True,          # Blender Z-up -> Godot Y-up
        export_apply=True,        # bake any remaining modifiers/transforms
        export_animations=False,
        export_skins=False,
        export_materials="EXPORT",
    )
    size = os.path.getsize(out_path) if os.path.exists(out_path) else 0
    print("[EXPORT] %-18s root=%-16s %8d bytes" % (os.path.basename(out_path),
                                                   root_name, size))
    if size <= 0:
        raise RuntimeError("Export produced an empty/missing file: " + out_path)
    return out_path


def scene_bounds() -> tuple:
    """World-space (min, max) of every mesh in the scene, ignoring the root."""
    import mathutils
    mins = [math.inf] * 3
    maxs = [-math.inf] * 3
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        for corner in obj.bound_box:
            w = obj.matrix_world @ mathutils.Vector(corner)
            for i in range(3):
                mins[i] = min(mins[i], w[i])
                maxs[i] = max(maxs[i], w[i])
    if mins[0] == math.inf:
        return (0.0, 0.0, 0.0), (0.0, 0.0, 0.0)
    return tuple(mins), tuple(maxs)


def report_bounds(label: str) -> None:
    """Print the metric bounding box so units/origin can be eyeballed in CI."""
    mn, mx = scene_bounds()
    dims = (mx[0] - mn[0], mx[1] - mn[1], mx[2] - mn[2])
    print("[BOUNDS] %-18s size=%.3f x %.3f x %.3f m | min=(%.3f, %.3f, %.3f)"
          % (label, dims[0], dims[1], dims[2], mn[0], mn[1], mn[2]))


def mesh_count() -> int:
    return len([o for o in bpy.context.scene.objects if o.type == "MESH"])
