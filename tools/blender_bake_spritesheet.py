import argparse
import json
import math
import os
import sys
import numpy as np

import bpy
from mathutils import Euler, Matrix, Vector


def _clear_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def _setup_render(cell_size: int, samples: int = 12) -> None:
    scene = bpy.context.scene
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    scene.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in engines else engines[0]
    if hasattr(scene, "eevee"):
        if hasattr(scene.eevee, "taa_render_samples"):
            scene.eevee.taa_render_samples = samples
        elif hasattr(scene.eevee, "samples"):
            scene.eevee.samples = samples
    scene.render.film_transparent = True
    scene.render.resolution_x = cell_size
    scene.render.resolution_y = cell_size
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = 0.0

    world = bpy.data.worlds.new("ToonWorld")
    scene.world = world
    world.use_nodes = True
    nt = world.node_tree
    bg = nt.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.65, 0.82, 0.78, 1.0)
        bg.inputs[1].default_value = 0.08


def _setup_lights_and_camera(ortho_scale: float, cam_dist: float = 8.0, target_z: float = 0.9, elev_deg: float = 32.0):
    scene = bpy.context.scene

    key_data = bpy.data.lights.new("KeySun", type="SUN")
    key_data.energy = 3.0
    key_data.angle = math.radians(2.0)
    key_obj = bpy.data.objects.new("KeySun", key_data)
    scene.collection.objects.link(key_obj)
    key_obj.rotation_euler = Euler((math.radians(48.0), math.radians(-16.0), math.radians(-32.0)), "XYZ")

    rim_data = bpy.data.lights.new("RimSun", type="SUN")
    rim_data.energy = 0.45
    rim_data.color = (0.72, 0.98, 0.92)
    rim_obj = bpy.data.objects.new("RimSun", rim_data)
    scene.collection.objects.link(rim_obj)
    rim_obj.rotation_euler = Euler((math.radians(-50.0), 0.0, math.radians(145.0)), "XYZ")

    cam_data = bpy.data.cameras.new("OrthoCam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = ortho_scale
    cam_data.clip_start = 0.1
    cam_data.clip_end = 100.0
    cam_obj = bpy.data.objects.new("OrthoCam", cam_data)
    scene.collection.objects.link(cam_obj)
    scene.camera = cam_obj

    elev = math.radians(elev_deg)
    cam_y = -cam_dist * math.cos(elev)
    cam_z = target_z + cam_dist * math.sin(elev)
    cam_obj.location = Vector((0.0, cam_y, cam_z))
    direction = Vector((0.0, 0.0, target_z)) - cam_obj.location
    cam_obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    return cam_obj


def _make_ink_mat(color=(0.05, 0.09, 0.08, 1.0)) -> bpy.types.Material:
    mat = bpy.data.materials.new("InkOutline")
    mat.use_nodes = True
    mat.use_backface_culling = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    emit = nt.nodes.new("ShaderNodeEmission")
    emit.inputs[0].default_value = color
    emit.inputs[1].default_value = 1.0
    nt.links.new(emit.outputs[0], out.inputs[0])
    return mat


def _make_toon_mat(name: str, base_rgb: tuple, shadow_rgb: tuple | None = None, emissive: float = 0.0, threshold: float = 0.48) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")

    if emissive > 0.0:
        emit = nt.nodes.new("ShaderNodeEmission")
        emit.inputs[0].default_value = (*base_rgb, 1.0)
        emit.inputs[1].default_value = emissive
        nt.links.new(emit.outputs[0], out.inputs[0])
        return mat

    if shadow_rgb is None:
        shadow_rgb = (base_rgb[0] * 0.54, base_rgb[1] * 0.56, min(1.0, base_rgb[2] * 0.64))

    diff = nt.nodes.new("ShaderNodeBsdfDiffuse")
    diff.inputs[0].default_value = (1.0, 1.0, 1.0, 1.0)
    s2r = nt.nodes.new("ShaderNodeShaderToRGB")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "CONSTANT"
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = (*shadow_rgb, 1.0)
    ramp.color_ramp.elements[1].position = threshold
    ramp.color_ramp.elements[1].color = (*base_rgb, 1.0)

    emit = nt.nodes.new("ShaderNodeEmission")
    emit.inputs[1].default_value = 1.0
    nt.links.new(diff.outputs[0], s2r.inputs[0])
    nt.links.new(s2r.outputs[0], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], emit.inputs[0])
    nt.links.new(emit.outputs[0], out.inputs[0])
    return mat


def _toonify_external_materials(meshes: list[bpy.types.Object]) -> None:
    seen: set[int] = set()
    for m in meshes:
        for slot in m.material_slots:
            mat = slot.material
            if mat is None or mat.as_pointer() in seen:
                continue
            seen.add(mat.as_pointer())
            mat.use_nodes = True
            nt = mat.node_tree
            out_node = next((n for n in nt.nodes if n.type == "OUTPUT_MATERIAL"), None)
            bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
            if out_node is None or bsdf is None:
                continue

            base_in = bsdf.inputs.get("Base Color")
            alpha_in = bsdf.inputs.get("Alpha")
            base_src = base_in.links[0].from_socket if (base_in and base_in.is_linked) else None
            base_val = tuple(base_in.default_value) if base_in else (0.85, 0.85, 0.85, 1.0)
            alpha_src = alpha_in.links[0].from_socket if (alpha_in and alpha_in.is_linked) else None

            diff = nt.nodes.new("ShaderNodeBsdfDiffuse")
            diff.inputs[0].default_value = (1.0, 1.0, 1.0, 1.0)
            s2r = nt.nodes.new("ShaderNodeShaderToRGB")
            ramp = nt.nodes.new("ShaderNodeValToRGB")
            ramp.color_ramp.interpolation = "CONSTANT"
            ramp.color_ramp.elements[0].position = 0.0
            ramp.color_ramp.elements[0].color = (0.58, 0.62, 0.68, 1.0)
            ramp.color_ramp.elements[1].position = 0.36
            ramp.color_ramp.elements[1].color = (1.0, 1.0, 1.0, 1.0)

            mix = nt.nodes.new("ShaderNodeMix")
            mix.data_type = "RGBA"
            mix.blend_type = "MULTIPLY"
            mix.inputs[0].default_value = 1.0
            if base_src is not None:
                nt.links.new(base_src, mix.inputs[6])
            else:
                mix.inputs[6].default_value = base_val

            emit = nt.nodes.new("ShaderNodeEmission")
            emit.inputs[1].default_value = 1.0
            nt.links.new(diff.outputs[0], s2r.inputs[0])
            nt.links.new(s2r.outputs[0], ramp.inputs[0])
            nt.links.new(ramp.outputs[0], mix.inputs[7])
            nt.links.new(mix.outputs[2], emit.inputs[0])

            for link in list(out_node.inputs["Surface"].links):
                nt.links.remove(link)
            if alpha_src is not None:
                trans = nt.nodes.new("ShaderNodeBsdfTransparent")
                mix_sh = nt.nodes.new("ShaderNodeMixShader")
                nt.links.new(alpha_src, mix_sh.inputs[0])
                nt.links.new(trans.outputs[0], mix_sh.inputs[1])
                nt.links.new(emit.outputs[0], mix_sh.inputs[2])
                nt.links.new(mix_sh.outputs[0], out_node.inputs["Surface"])
            else:
                nt.links.new(emit.outputs[0], out_node.inputs["Surface"])


def _add_outline(obj: bpy.types.Object, ink_mat: bpy.types.Material, thickness: float = 0.022) -> None:
    if len(obj.data.materials) == 0:
        return
    obj.data.materials.append(ink_mat)
    mod = obj.modifiers.new("Outline", "SOLIDIFY")
    mod.thickness = -thickness
    mod.offset = -1.0
    mod.use_flip_normals = True
    mod.use_rim = False
    mod.material_offset = len(obj.data.materials) - 1


def _add_subsurf(obj: bpy.types.Object, levels: int = 2) -> None:
    mod = obj.modifiers.new("Subsurf", "SUBSURF")
    mod.levels = levels
    mod.render_levels = levels


def _shade_smooth(obj: bpy.types.Object) -> None:
    for poly in obj.data.polygons:
        poly.use_smooth = True


def _create_part(
    name: str,
    kind: str,
    loc=(0, 0, 0),
    scale=(1, 1, 1),
    rot=(0, 0, 0),
    mat=None,
    ink_mat=None,
    outline: float = 0.022,
    subsurf: int = 1,
    verts: int = 16,
    radius1: float = 0.5,
    radius2: float = 0.35,
    depth: float = 1.0,
):
    if kind == "sphere":
        bpy.ops.mesh.primitive_uv_sphere_add(segments=verts, ring_count=max(8, verts // 2), radius=0.5, location=loc)
    elif kind == "cone":
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius1, radius2=radius2, depth=depth, location=loc)
    elif kind == "cylinder":
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius1, depth=depth, location=loc)
    elif kind == "torus":
        bpy.ops.mesh.primitive_torus_add(major_segments=28, minor_segments=10, major_radius=radius1, minor_radius=radius2, location=loc)
    else:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)

    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    obj.rotation_euler = Euler(rot, "XYZ")
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if subsurf > 0:
        _add_subsurf(obj, subsurf)
    _shade_smooth(obj)
    if mat is not None:
        obj.data.materials.append(mat)
    if ink_mat is not None and outline > 0.0:
        _add_outline(obj, ink_mat, outline)
    return obj


def _bind_to_bone(obj: bpy.types.Object, arm: bpy.types.Object, bone_name: str) -> None:
    obj.parent = arm
    obj.parent_type = "BONE"
    obj.parent_bone = bone_name
    b = arm.data.bones[bone_name]
    inv = (arm.matrix_world @ Matrix.Translation(b.tail) @ b.matrix_local).inverted()
    # Parent to bone sets child relative to bone tail; preserve world transform cleanly
    obj.matrix_parent_inverse = (arm.matrix_world @ b.matrix_local @ Matrix.Translation((0.0, b.length, 0.0))).inverted()


def _create_armature(name: str, bone_defs: list[tuple]) -> bpy.types.Object:
    arm_data = bpy.data.armatures.new(name)
    arm_obj = bpy.data.objects.new(name, arm_data)
    bpy.context.scene.collection.objects.link(arm_obj)
    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_data.edit_bones
    for b_name, parent_name, head, tail in bone_defs:
        bone = eb.new(b_name)
        bone.head = Vector(head)
        bone.tail = Vector(tail)
        if parent_name:
            bone.parent = eb[parent_name]
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm_obj


def _set_pose(arm: bpy.types.Object, frame: int, poses: dict) -> None:
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.location = (0.0, 0.0, 0.0)
        pb.rotation_euler = (0.0, 0.0, 0.0)
        pb.scale = (1.0, 1.0, 1.0)
    for b_name, vals in poses.items():
        if b_name not in arm.pose.bones:
            continue
        pb = arm.pose.bones[b_name]
        if "loc" in vals:
            pb.location = vals["loc"]
        if "rot" in vals:
            pb.rotation_euler = tuple(math.radians(a) for a in vals["rot"])
        if "scale" in vals:
            pb.scale = vals["scale"]
    for pb in arm.pose.bones:
        pb.keyframe_insert(data_path="location", frame=frame)
        pb.keyframe_insert(data_path="rotation_euler", frame=frame)
        pb.keyframe_insert(data_path="scale", frame=frame)


def _reset_pose(arm: bpy.types.Object) -> None:
    if arm.animation_data:
        arm.animation_data_clear()
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.location = (0.0, 0.0, 0.0)
        pb.rotation_euler = (0.0, 0.0, 0.0)
        pb.scale = (1.0, 1.0, 1.0)


def _build_hero_rig():
    ink = _make_ink_mat((0.05, 0.09, 0.08, 1.0))
    m_skin = _make_toon_mat("HeroSkin", (0.98, 0.80, 0.68), (0.82, 0.58, 0.48))
    m_hair = _make_toon_mat("HeroHair", (0.12, 0.14, 0.18), (0.05, 0.06, 0.09))
    m_eye = _make_toon_mat("HeroEye", (0.08, 0.09, 0.12), (0.04, 0.04, 0.06))
    m_white = _make_toon_mat("HeroWhite", (0.94, 0.97, 0.94), (0.68, 0.82, 0.78))
    m_jade = _make_toon_mat("HeroJade", (0.20, 0.76, 0.62), (0.11, 0.48, 0.40))
    m_gold = _make_toon_mat("HeroGold", (0.95, 0.74, 0.22), (0.68, 0.46, 0.10))
    m_red = _make_toon_mat("HeroRed", (0.88, 0.24, 0.14), (0.58, 0.12, 0.08))
    m_boot = _make_toon_mat("HeroBoot", (0.22, 0.17, 0.14), (0.11, 0.08, 0.07))
    m_sword = _make_toon_mat("HeroSword", (0.16, 0.88, 0.76), (0.08, 0.56, 0.52))
    m_slash = _make_toon_mat("HeroSlashArc", (0.34, 0.98, 0.86), emissive=1.35)

    arm = _create_armature("HeroRig", [
        ("root", None, (0, 0, 0.0), (0, 0, 0.25)),
        ("pelvis", "root", (0, 0, 0.78), (0, 0, 0.95)),
        ("chest", "pelvis", (0, 0, 0.95), (0, 0, 1.38)),
        ("head", "chest", (0, 0, 1.42), (0, 0, 1.88)),
        ("thigh_L", "pelvis", (-0.16, 0, 0.76), (-0.16, 0, 0.42)),
        ("shin_L", "thigh_L", (-0.16, 0, 0.42), (-0.16, 0, 0.06)),
        ("thigh_R", "pelvis", (0.16, 0, 0.76), (0.16, 0, 0.42)),
        ("shin_R", "thigh_R", (0.16, 0, 0.42), (0.16, 0, 0.06)),
        ("arm_L", "chest", (-0.28, 0, 1.32), (-0.36, 0, 1.02)),
        ("forearm_L", "arm_L", (-0.36, 0, 1.02), (-0.38, -0.14, 0.80)),
        ("arm_R", "chest", (0.28, 0, 1.32), (0.36, 0, 1.02)),
        ("forearm_R", "arm_R", (0.36, 0, 1.02), (0.36, -0.18, 0.88)),
        ("sword", "forearm_R", (0.36, -0.19, 0.88), (0.36, -0.72, 1.15)),
        ("ribbon_L", "pelvis", (-0.10, 0.14, 0.87), (-0.28, 0.62, 0.68)),
        ("ribbon_R", "pelvis", (0.10, 0.14, 0.87), (0.26, 0.60, 0.58)),
        ("slash_arc", "chest", (0.0, -0.25, 1.06), (0.0, -0.85, 1.06)),
    ])

    def attach(part, bone):
        _bind_to_bone(part, arm, bone)

    # Head + hair + topknot + face details (facing -Y)
    attach(_create_part("Head", "sphere", (0, 0, 1.64), (0.50, 0.48, 0.52), mat=m_skin, ink_mat=ink, outline=0.024), "head")
    attach(_create_part("HairCap", "sphere", (0, 0.04, 1.69), (0.54, 0.53, 0.49), mat=m_hair, ink_mat=ink, outline=0.022), "head")
    attach(_create_part("HairBack", "cone", (0, 0.20, 1.56), (0.42, 0.24, 0.36), rot=(math.radians(15), 0, 0), mat=m_hair, ink_mat=ink, outline=0.020, radius1=0.45, radius2=0.18, depth=0.6), "head")
    attach(_create_part("Topknot", "sphere", (0, 0.03, 1.97), (0.20, 0.20, 0.21), mat=m_hair, ink_mat=ink, outline=0.018), "head")
    attach(_create_part("HairCrown", "torus", (0, 0.03, 1.91), (0.16, 0.16, 0.19), mat=m_jade, ink_mat=ink, outline=0.015, radius1=0.75, radius2=0.22), "head")
    attach(_create_part("EyeL", "sphere", (-0.11, -0.23, 1.64), (0.07, 0.04, 0.09), mat=m_eye, outline=0.0), "head")
    attach(_create_part("EyeR", "sphere", (0.11, -0.23, 1.64), (0.07, 0.04, 0.09), mat=m_eye, outline=0.0), "head")
    attach(_create_part("BrowL", "cube", (-0.11, -0.24, 1.71), (0.10, 0.03, 0.025), rot=(0, math.radians(-10), 0), mat=m_hair, outline=0.0, subsurf=0), "head")
    attach(_create_part("BrowR", "cube", (0.11, -0.24, 1.71), (0.10, 0.03, 0.025), rot=(0, math.radians(10), 0), mat=m_hair, outline=0.0, subsurf=0), "head")

    # Torso, celadon robe, pauldrons, sash, robe tails
    attach(_create_part("Torso", "cone", (0, 0, 1.15), (0.50, 0.38, 0.56), mat=m_white, ink_mat=ink, outline=0.024, radius1=0.48, radius2=0.58, depth=0.90), "chest")
    attach(_create_part("ChestTrim", "cone", (0, -0.02, 1.24), (0.44, 0.36, 0.36), mat=m_jade, outline=0.0, radius1=0.42, radius2=0.54, depth=0.65), "chest")
    attach(_create_part("PauldronL", "sphere", (-0.30, 0, 1.35), (0.24, 0.24, 0.18), mat=m_gold, ink_mat=ink, outline=0.018), "chest")
    attach(_create_part("PauldronR", "sphere", (0.30, 0, 1.35), (0.24, 0.24, 0.18), mat=m_gold, ink_mat=ink, outline=0.018), "chest")
    attach(_create_part("WaistSash", "cylinder", (0, 0, 0.89), (0.50, 0.39, 0.14), mat=m_red, ink_mat=ink, outline=0.018, radius1=0.52, depth=1.0), "pelvis")
    attach(_create_part("RobeSkirtBack", "cone", (0, 0.12, 0.65), (0.60, 0.34, 0.58), rot=(math.radians(-16), 0, 0), mat=m_jade, ink_mat=ink, outline=0.022, radius1=0.62, radius2=0.38, depth=0.95), "pelvis")
    attach(_create_part("RobeSkirtTrim", "cone", (0, 0.12, 0.58), (0.52, 0.28, 0.42), rot=(math.radians(-16), 0, 0), mat=m_gold, outline=0.0, radius1=0.64, radius2=0.46, depth=0.35), "pelvis")

    # Arms + wide celadon sleeves + glowing jade sword
    attach(_create_part("SleeveL", "cone", (-0.32, 0, 1.15), (0.22, 0.24, 0.38), mat=m_white, ink_mat=ink, outline=0.018, radius1=0.55, radius2=0.35, depth=1.0), "arm_L")
    attach(_create_part("ForeL", "cone", (-0.37, -0.08, 0.90), (0.26, 0.28, 0.28), mat=m_jade, ink_mat=ink, outline=0.018, radius1=0.62, radius2=0.34, depth=1.0), "forearm_L")
    attach(_create_part("HandL", "sphere", (-0.38, -0.15, 0.78), (0.14, 0.14, 0.14), mat=m_skin, ink_mat=ink, outline=0.015), "forearm_L")

    attach(_create_part("SleeveR", "cone", (0.32, 0, 1.15), (0.22, 0.24, 0.38), mat=m_white, ink_mat=ink, outline=0.018, radius1=0.55, radius2=0.35, depth=1.0), "arm_R")
    attach(_create_part("ForeR", "cone", (0.36, -0.09, 0.92), (0.24, 0.26, 0.26), mat=m_jade, ink_mat=ink, outline=0.018, radius1=0.58, radius2=0.34, depth=1.0), "forearm_R")
    attach(_create_part("HandR", "sphere", (0.36, -0.19, 0.88), (0.14, 0.14, 0.14), mat=m_skin, ink_mat=ink, outline=0.015), "forearm_R")

    attach(_create_part("SwordHilt", "cylinder", (0.36, -0.20, 0.89), (0.05, 0.05, 0.24), rot=(math.radians(64), 0, 0), mat=m_gold, ink_mat=ink, outline=0.014, radius1=0.6, depth=1.0, subsurf=0), "sword")
    attach(_create_part("SwordGuard", "cube", (0.36, -0.29, 0.935), (0.22, 0.06, 0.07), rot=(math.radians(-26), 0, 0), mat=m_gold, ink_mat=ink, outline=0.014, subsurf=0), "sword")
    attach(_create_part("SwordBlade", "cone", (0.36, -0.60, 1.085), (0.11, 0.045, 0.78), rot=(math.radians(64), 0, 0), mat=m_sword, ink_mat=ink, outline=0.020, radius1=0.6, radius2=0.05, depth=1.0, subsurf=0, verts=8), "sword")

    # Legs + dark boots
    attach(_create_part("ThighL", "cylinder", (-0.16, 0, 0.58), (0.22, 0.22, 0.38), mat=m_white, ink_mat=ink, outline=0.020, radius1=0.52, depth=1.0), "thigh_L")
    attach(_create_part("BootL", "cone", (-0.16, -0.02, 0.22), (0.18, 0.24, 0.38), mat=m_boot, ink_mat=ink, outline=0.020, radius1=0.60, radius2=0.48, depth=1.0), "shin_L")
    attach(_create_part("ThighR", "cylinder", (0.16, 0, 0.58), (0.22, 0.22, 0.38), mat=m_white, ink_mat=ink, outline=0.020, radius1=0.52, depth=1.0), "thigh_R")
    attach(_create_part("BootR", "cone", (0.16, -0.02, 0.22), (0.18, 0.24, 0.38), mat=m_boot, ink_mat=ink, outline=0.020, radius1=0.60, radius2=0.48, depth=1.0), "shin_R")

    # Continuous flowing red silk ribbons anchored right into waist sash
    attach(_create_part("RibbonL", "cone", (-0.16, 0.34, 0.78), (0.14, 0.05, 0.58), rot=(math.radians(-112), 0, math.radians(16)), mat=m_red, ink_mat=ink, outline=0.015, radius1=0.35, radius2=0.55, depth=1.0, subsurf=1), "ribbon_L")
    attach(_create_part("RibbonR", "cone", (0.14, 0.32, 0.72), (0.14, 0.05, 0.54), rot=(math.radians(-116), 0, math.radians(-14)), mat=m_red, ink_mat=ink, outline=0.015, radius1=0.35, radius2=0.55, depth=1.0, subsurf=1), "ribbon_R")

    # Tapered 160-deg front crescent sword-wave arc (replaces full-circle hoop)
    mesh = bpy.data.meshes.new("SlashCrescentMesh")
    segs = 20
    verts_list, faces_list = [], []
    for k in range(segs + 1):
        u = float(k) / float(segs) * 2.0 - 1.0
        ang = u * math.radians(82.0)
        taper = max(0.04, math.cos(u * math.pi * 0.5))
        r_out = 0.94
        r_in = 0.94 - 0.34 * taper
        z_mid = 1.06 + math.sin(u * 0.6) * 0.06
        dz = 0.04 * taper
        sx, cy = math.sin(ang), -math.cos(ang)
        verts_list.append((sx * r_in, cy * r_in - 0.10, z_mid))
        verts_list.append((sx * r_out, cy * r_out - 0.10, z_mid + dz))
        verts_list.append((sx * r_out, cy * r_out - 0.10, z_mid - dz))
        if k > 0:
            b0 = (k - 1) * 3
            b1 = k * 3
            faces_list.append((b0, b0 + 1, b1 + 1, b1))
            faces_list.append((b0, b1, b1 + 2, b0 + 2))
            faces_list.append((b0 + 1, b0 + 2, b1 + 2, b1 + 1))
    mesh.from_pydata(verts_list, [], faces_list)
    slash_obj = bpy.data.objects.new("SlashArc", mesh)
    bpy.context.scene.collection.objects.link(slash_obj)
    slash_obj.data.materials.append(m_slash)
    _shade_smooth(slash_obj)
    attach(slash_obj, "slash_arc")

    return arm, slash_obj


def _animate_hero(arm: bpy.types.Object, slash_obj: bpy.types.Object, action_name: str) -> int:
    _reset_pose(arm)
    slash_obj.hide_render = True

    # Note: for vertical-up bones (pelvis, chest, head), local X = pitch, local Y = vertical yaw twist, local Z = side roll.
    if action_name == "run":
        n_frames = 8
        for i in range(n_frames):
            f = i + 1
            p = (float(i) / float(n_frames)) * 2.0 * math.pi
            s = math.sin(p)
            c = math.cos(p)
            bob = abs(math.sin(p)) * 0.09 - 0.04
            knee_l = max(0.0, -c) * 65.0 + 12.0
            knee_r = max(0.0, c) * 65.0 + 12.0
            _set_pose(arm, f, {
                "pelvis": {"loc": (0.0, 0.0, bob), "rot": (-10.0, s * 10.0, 0.0)},
                "chest": {"rot": (-8.0, -s * 14.0, 0.0)},
                "head": {"rot": (14.0, s * 4.0, 0.0)},
                "thigh_L": {"rot": (s * 48.0, 0.0, 0.0)},
                "shin_L": {"rot": (-knee_l, 0.0, 0.0)},
                "thigh_R": {"rot": (-s * 48.0, 0.0, 0.0)},
                "shin_R": {"rot": (-knee_r, 0.0, 0.0)},
                "arm_L": {"rot": (-s * 42.0, 0.0, -10.0)},
                "forearm_L": {"rot": (35.0, 0.0, 0.0)},
                "arm_R": {"rot": (s * 22.0 + 16.0, 0.0, 10.0)},
                "forearm_R": {"rot": (24.0, 0.0, 0.0)},
                "sword": {"rot": (10.0, 0.0, 0.0)},
                "ribbon_L": {"rot": (math.sin(p) * 14.0, math.cos(p) * 12.0, 0.0)},
                "ribbon_R": {"rot": (math.cos(p) * 14.0, -math.sin(p) * 12.0, 0.0)},
                "slash_arc": {"scale": (0.01, 0.01, 0.01)},
            })
        return n_frames

    if action_name == "idle":
        n_frames = 6
        for i in range(n_frames):
            f = i + 1
            p = (float(i) / float(n_frames)) * 2.0 * math.pi
            s = math.sin(p)
            _set_pose(arm, f, {
                "pelvis": {"loc": (0.0, 0.0, s * 0.025)},
                "chest": {"rot": (-s * 3.0, 0.0, 0.0)},
                "head": {"rot": (s * 2.5, 0.0, 0.0)},
                "thigh_L": {"rot": (8.0, 0.0, -6.0)},
                "shin_L": {"rot": (-8.0, 0.0, 0.0)},
                "thigh_R": {"rot": (-6.0, 0.0, 6.0)},
                "shin_R": {"rot": (-6.0, 0.0, 0.0)},
                "arm_L": {"rot": (4.0 + s * 3.0, 0.0, -12.0)},
                "arm_R": {"rot": (16.0 - s * 4.0, 0.0, 10.0)},
                "sword": {"rot": (8.0 + s * 4.0, 0.0, 0.0)},
                "ribbon_L": {"rot": (s * 10.0, math.cos(p) * 10.0, 0.0)},
                "ribbon_R": {"rot": (-s * 10.0, math.sin(p) * 10.0, 0.0)},
                "slash_arc": {"scale": (0.01, 0.01, 0.01)},
            })
        return n_frames

    slash_obj.hide_render = False
    atk_poses = [
        {"pelvis": {"rot": (-6, -24, 0)}, "chest": {"rot": (-6, -34, 0)}, "head": {"rot": (8, 22, 0)}, "arm_R": {"rot": (48, 0, 38)}, "forearm_R": {"rot": (30, 0, 0)}, "sword": {"rot": (12, 0, 0)}, "thigh_L": {"rot": (22, 0, -8)}, "thigh_R": {"rot": (-22, 0, 8)}, "slash_arc": {"scale": (0.01, 0.01, 0.01)}},
        {"pelvis": {"loc": (0, -0.08, -0.04), "rot": (-14, 24, 0)}, "chest": {"rot": (-12, 40, 0)}, "head": {"rot": (14, -18, 0)}, "arm_R": {"rot": (62, 0, 22)}, "forearm_R": {"rot": (18, 0, 0)}, "sword": {"rot": (28, 0, -40)}, "thigh_L": {"rot": (-30, 0, -6)}, "thigh_R": {"rot": (32, 0, 6)}, "shin_R": {"rot": (-24, 0, 0)}, "slash_arc": {"loc": (0, -0.08, 0), "rot": (0, 18, 0), "scale": (1.0, 1.0, 1.0)}},
        {"pelvis": {"loc": (0, -0.10, -0.04), "rot": (-12, 42, 0)}, "chest": {"rot": (-10, 52, 0)}, "head": {"rot": (12, -26, 0)}, "arm_R": {"rot": (52, 0, -34)}, "sword": {"rot": (24, 0, -60)}, "thigh_L": {"rot": (-28, 0, -6)}, "thigh_R": {"rot": (30, 0, 6)}, "slash_arc": {"loc": (0, -0.10, 0), "rot": (0, -24, 0), "scale": (1.12, 1.12, 1.0)}},
        {"pelvis": {"loc": (0, -0.06, -0.02), "rot": (-8, 30, 0)}, "chest": {"rot": (-8, 34, 0)}, "head": {"rot": (10, -16, 0)}, "arm_R": {"rot": (38, 0, -20)}, "sword": {"rot": (18, 0, -42)}, "slash_arc": {"scale": (0.01, 0.01, 0.01)}},
        {"pelvis": {"loc": (0, -0.02, 0.0), "rot": (-4, 14, 0)}, "chest": {"rot": (-4, 16, 0)}, "arm_R": {"rot": (24, 0, 0)}, "sword": {"rot": (10, 0, -16)}, "slash_arc": {"scale": (0.01, 0.01, 0.01)}},
        {"pelvis": {"rot": (0, 0, 0)}, "chest": {"rot": (0, 0, 0)}, "arm_R": {"rot": (16, 0, 10)}, "sword": {"rot": (8, 0, 0)}, "slash_arc": {"scale": (0.01, 0.01, 0.01)}},
    ]
    for i, pose in enumerate(atk_poses):
        _set_pose(arm, i + 1, pose)
    return len(atk_poses)


def _build_wolf_rig():
    ink = _make_ink_mat((0.05, 0.10, 0.12, 1.0))
    m_fur = _make_toon_mat("WolfSilver", (0.86, 0.93, 0.98), (0.52, 0.66, 0.78))
    m_belly = _make_toon_mat("WolfBelly", (0.96, 0.98, 1.0), (0.64, 0.76, 0.86))
    m_mane = _make_toon_mat("WolfMane", (0.10, 0.72, 0.66), (0.05, 0.34, 0.48))
    m_mane_tip = _make_toon_mat("WolfManeTip", (0.16, 0.50, 0.92), (0.08, 0.24, 0.58))
    m_gold = _make_toon_mat("WolfHalo", (0.96, 0.76, 0.22), (0.72, 0.46, 0.10))
    m_flame = _make_toon_mat("WolfFlame", (0.20, 0.92, 0.80), (0.10, 0.54, 0.52))
    m_eye = _make_toon_mat("WolfEye", (0.28, 1.0, 0.88), emissive=1.5)

    arm = _create_armature("WolfBossRig", [
        ("root", None, (0, 0, 0.0), (0, 0, 0.20)),
        ("pelvis", "root", (0, 0.45, 0.92), (0, 0.15, 0.94)),
        ("spine_mid", "pelvis", (0, 0.15, 0.94), (0, -0.22, 0.96)),
        ("chest", "spine_mid", (0, -0.22, 0.96), (0, -0.58, 1.04)),
        ("neck", "chest", (0, -0.56, 1.08), (0, -0.78, 1.38)),
        ("head", "neck", (0, -0.78, 1.38), (0, -1.16, 1.38)),
        ("jaw", "head", (0, -0.84, 1.30), (0, -1.12, 1.24)),
        ("tail_1", "pelvis", (0, 0.50, 0.95), (0, 0.92, 1.18)),
        ("tail_2", "tail_1", (0, 0.92, 1.18), (0, 1.24, 1.54)),
        ("halo", "chest", (0, 0.02, 1.56), (0, 0.02, 1.98)),
        ("fl_upper", "chest", (-0.22, -0.46, 0.90), (-0.22, -0.48, 0.50)),
        ("fl_lower", "fl_upper", (-0.22, -0.48, 0.50), (-0.22, -0.50, 0.10)),
        ("fr_upper", "chest", (0.22, -0.46, 0.90), (0.22, -0.48, 0.50)),
        ("fr_lower", "fr_upper", (0.22, -0.48, 0.50), (0.22, -0.50, 0.10)),
        ("bl_upper", "pelvis", (-0.21, 0.46, 0.88), (-0.21, 0.54, 0.48)),
        ("bl_lower", "bl_upper", (-0.21, 0.54, 0.48), (-0.21, 0.48, 0.10)),
        ("br_upper", "pelvis", (0.21, 0.46, 0.88), (0.21, 0.54, 0.48)),
        ("br_lower", "br_upper", (0.21, 0.54, 0.48), (0.21, 0.48, 0.10)),
    ])

    def attach(part, bone):
        _bind_to_bone(part, arm, bone)

    # Body segments
    attach(_create_part("WolfRump", "sphere", (0, 0.34, 0.92), (0.58, 0.74, 0.56), mat=m_fur, ink_mat=ink, outline=0.028), "pelvis")
    attach(_create_part("WolfWaist", "sphere", (0, -0.02, 0.93), (0.50, 0.64, 0.48), mat=m_fur, ink_mat=ink, outline=0.026), "spine_mid")
    attach(_create_part("WolfChest", "sphere", (0, -0.42, 0.98), (0.68, 0.78, 0.66), mat=m_belly, ink_mat=ink, outline=0.028), "chest")

    # Cyan-blue flowing mane tufts around shoulders/neck + smaller elevated halo ring
    attach(_create_part("ManeCore", "cone", (0, -0.52, 1.18), (0.78, 0.68, 0.76), rot=(math.radians(-42), 0, 0), mat=m_mane, ink_mat=ink, outline=0.024, radius1=0.62, radius2=0.14, depth=1.0), "chest")
    attach(_create_part("ManeCrestL", "cone", (-0.24, -0.18, 1.24), (0.26, 0.22, 0.68), rot=(math.radians(-58), 0, math.radians(18)), mat=m_mane_tip, ink_mat=ink, outline=0.020, radius1=0.55, radius2=0.06, depth=1.0), "chest")
    attach(_create_part("ManeCrestR", "cone", (0.24, -0.18, 1.24), (0.26, 0.22, 0.68), rot=(math.radians(-58), 0, math.radians(-18)), mat=m_mane_tip, ink_mat=ink, outline=0.020, radius1=0.55, radius2=0.06, depth=1.0), "chest")
    attach(_create_part("HaloRing", "torus", (0, 0.04, 1.72), (0.44, 0.44, 0.44), rot=(math.radians(70), 0, 0), mat=m_gold, ink_mat=ink, outline=0.018, radius1=1.0, radius2=0.13), "halo")

    # Neck, head, snout, ears, eyes, jaw
    attach(_create_part("WolfNeck", "cylinder", (0, -0.66, 1.22), (0.42, 0.42, 0.48), rot=(math.radians(32), 0, 0), mat=m_mane, ink_mat=ink, outline=0.024, radius1=0.52, depth=1.0), "neck")
    attach(_create_part("WolfSkull", "sphere", (0, -0.82, 1.40), (0.46, 0.50, 0.42), mat=m_fur, ink_mat=ink, outline=0.024), "head")
    attach(_create_part("WolfSnout", "cone", (0, -1.08, 1.38), (0.24, 0.22, 0.46), rot=(math.radians(-90), 0, 0), mat=m_fur, ink_mat=ink, outline=0.020, radius1=0.58, radius2=0.22, depth=1.0), "head")
    attach(_create_part("WolfJaw", "cone", (0, -1.02, 1.27), (0.19, 0.14, 0.38), rot=(math.radians(-90), 0, 0), mat=m_belly, ink_mat=ink, outline=0.018, radius1=0.55, radius2=0.20, depth=1.0), "jaw")
    attach(_create_part("EarL", "cone", (-0.18, -0.74, 1.64), (0.14, 0.14, 0.32), rot=(math.radians(10), math.radians(-18), 0), mat=m_mane, ink_mat=ink, outline=0.018, radius1=0.55, radius2=0.06, depth=1.0), "head")
    attach(_create_part("EarR", "cone", (0.18, -0.74, 1.64), (0.14, 0.14, 0.32), rot=(math.radians(10), math.radians(18), 0), mat=m_mane, ink_mat=ink, outline=0.018, radius1=0.55, radius2=0.06, depth=1.0), "head")
    attach(_create_part("EyeL", "sphere", (-0.14, -1.00, 1.44), (0.08, 0.05, 0.06), mat=m_eye, outline=0.0), "head")
    attach(_create_part("EyeR", "sphere", (0.14, -1.00, 1.44), (0.08, 0.05, 0.06), mat=m_eye, outline=0.0), "head")

    # Continuous overlapping azure tail
    attach(_create_part("TailRoot", "sphere", (0, 0.56, 0.96), (0.36, 0.38, 0.32), mat=m_mane, ink_mat=ink, outline=0.022), "tail_1")
    attach(_create_part("TailBase", "cone", (0, 0.78, 1.09), (0.34, 0.30, 0.64), rot=(math.radians(-54), 0, 0), mat=m_mane, ink_mat=ink, outline=0.022, radius1=0.58, radius2=0.40, depth=1.0), "tail_1")
    attach(_create_part("TailTip", "cone", (0, 1.06, 1.34), (0.30, 0.28, 0.68), rot=(math.radians(-30), 0, 0), mat=m_mane_tip, ink_mat=ink, outline=0.022, radius1=0.58, radius2=0.06, depth=1.0), "tail_2")

    # 4 articulated legs + cyan ankle flames
    leg_specs = [
        ("FL", -0.22, -0.46, "fl_upper", "fl_lower"),
        ("FR", 0.22, -0.46, "fr_upper", "fr_lower"),
        ("BL", -0.21, 0.48, "bl_upper", "bl_lower"),
        ("BR", 0.21, 0.48, "br_upper", "br_lower"),
    ]
    for tag, lx, ly, bu, bl in leg_specs:
        attach(_create_part(f"{tag}_Upper", "cone", (lx, ly, 0.70), (0.20, 0.22, 0.46), mat=m_fur, ink_mat=ink, outline=0.020, radius1=0.45, radius2=0.65, depth=1.0), bu)
        attach(_create_part(f"{tag}_Lower", "cylinder", (lx, ly, 0.30), (0.14, 0.15, 0.40), mat=m_fur, ink_mat=ink, outline=0.018, radius1=0.48, depth=1.0), bl)
        attach(_create_part(f"{tag}_Paw", "sphere", (lx, ly - 0.04, 0.08), (0.16, 0.24, 0.13), mat=m_belly, ink_mat=ink, outline=0.018), bl)
        attach(_create_part(f"{tag}_Flame", "torus", (lx, ly, 0.18), (0.12, 0.12, 0.22), mat=m_flame, ink_mat=ink, outline=0.010, radius1=0.95, radius2=0.22), bl)

    return arm


def _animate_wolf(arm: bpy.types.Object, action_name: str) -> int:
    _reset_pose(arm)

    if action_name == "run":
        n_frames = 8
        for i in range(n_frames):
            f = i + 1
            p = (float(i) / float(n_frames)) * 2.0 * math.pi
            fl = math.sin(p)
            fr = math.sin(p + 0.95)
            br = math.sin(p + 3.14)
            bl = math.sin(p + 4.10)
            spine_flex = math.cos(p + 0.4)
            bob = math.sin(p + 0.6) * 0.10
            _set_pose(arm, f, {
                "pelvis": {"loc": (0.0, 0.0, bob), "rot": (spine_flex * 14.0, 0.0, 0.0)},
                "spine_mid": {"rot": (-spine_flex * 16.0, 0.0, 0.0)},
                "chest": {"rot": (-spine_flex * 12.0, 0.0, 0.0)},
                "neck": {"rot": (spine_flex * 10.0, 0.0, 0.0)},
                "head": {"rot": (spine_flex * 6.0, 0.0, 0.0)},
                "tail_1": {"rot": (math.sin(p - 0.7) * 16.0, 0.0, math.cos(p) * 8.0)},
                "tail_2": {"rot": (math.sin(p - 1.4) * 20.0, 0.0, math.cos(p - 0.6) * 10.0)},
                "halo": {"loc": (0.0, 0.0, math.sin(p) * 0.05)},
                "fl_upper": {"rot": (fl * 46.0, 0.0, 0.0)},
                "fl_lower": {"rot": (-max(0.0, -math.cos(p)) * 56.0, 0.0, 0.0)},
                "fr_upper": {"rot": (fr * 46.0, 0.0, 0.0)},
                "fr_lower": {"rot": (-max(0.0, -math.cos(p + 0.95)) * 56.0, 0.0, 0.0)},
                "bl_upper": {"rot": (bl * 48.0, 0.0, 0.0)},
                "bl_lower": {"rot": (max(0.0, math.cos(p + 4.10)) * 54.0, 0.0, 0.0)},
                "br_upper": {"rot": (br * 48.0, 0.0, 0.0)},
                "br_lower": {"rot": (max(0.0, math.cos(p + 3.14)) * 54.0, 0.0, 0.0)},
            })
        return n_frames

    if action_name == "windup":
        n_frames = 6
        for i in range(n_frames):
            f = i + 1
            t = float(i) / float(n_frames - 1)
            crouch = math.sin(t * math.pi * 0.65)
            jitter = math.sin(t * 25.0) * 1.8 * t
            _set_pose(arm, f, {
                "pelvis": {"loc": (0.0, -0.18 * crouch, 0.24 * crouch), "rot": (14.0 * crouch, 0.0, jitter)},
                "spine_mid": {"rot": (6.0 * crouch, 0.0, 0.0)},
                "chest": {"rot": (6.0 * crouch, 0.0, 0.0)},
                "neck": {"rot": (-18.0 * crouch, 0.0, 0.0)},
                "head": {"rot": (14.0 * crouch, 0.0, 0.0)},
                "jaw": {"rot": (22.0 * crouch, 0.0, 0.0)},
                "halo": {"loc": (0.0, 0.0, 0.18 * crouch), "scale": (1.0 + 0.18 * crouch,) * 3},
                "fl_upper": {"rot": (30.0 * crouch, 0.0, 0.0)},
                "fl_lower": {"rot": (-56.0 * crouch, 0.0, 0.0)},
                "fr_upper": {"rot": (30.0 * crouch, 0.0, 0.0)},
                "fr_lower": {"rot": (-56.0 * crouch, 0.0, 0.0)},
                "bl_upper": {"rot": (-56.0 * crouch, 0.0, 0.0)},
                "bl_lower": {"rot": (84.0 * crouch, 0.0, 0.0)},
                "br_upper": {"rot": (-56.0 * crouch, 0.0, 0.0)},
                "br_lower": {"rot": (84.0 * crouch, 0.0, 0.0)},
            })
        return n_frames

    if action_name == "pounce":
        n_frames = 6
        pounce_seq = [
            (0.08, -0.22, -20, -48, -44, 52, 48),
            (0.18, -0.34, -10, -58, -52, 60, 56),
            (0.22, -0.36, 4, -52, -46, 50, 46),
            (0.14, -0.16, 14, -34, -26, 28, 22),
            (0.04, 0.06, 6, -16, -12, 14, 10),
            (0.0, 0.0, 0, -6, -4, 6, 4),
        ]
        for i, (ly, lz, sp_p, f_u, f_s, b_u, b_s) in enumerate(pounce_seq):
            _set_pose(arm, i + 1, {
                "pelvis": {"loc": (0.0, ly, lz), "rot": (sp_p, 0.0, 0.0)},
                "chest": {"rot": (-sp_p * 0.5, 0.0, 0.0)},
                "head": {"rot": (10.0, 0.0, 0.0)},
                "jaw": {"rot": (24.0 if i < 4 else 6.0, 0.0, 0.0)},
                "fl_upper": {"rot": (f_u, 0.0, 0.0)},
                "fl_lower": {"rot": (16.0, 0.0, 0.0)},
                "fr_upper": {"rot": (f_s, 0.0, 0.0)},
                "fr_lower": {"rot": (12.0, 0.0, 0.0)},
                "bl_upper": {"rot": (b_u, 0.0, 0.0)},
                "bl_lower": {"rot": (-14.0, 0.0, 0.0)},
                "br_upper": {"rot": (b_s, 0.0, 0.0)},
                "br_lower": {"rot": (-12.0, 0.0, 0.0)},
            })
        return n_frames

    # roar
    n_frames = 6
    for i in range(n_frames):
        f = i + 1
        t = float(i) / float(n_frames - 1)
        arch = math.sin(t * math.pi)
        _set_pose(arm, f, {
            "pelvis": {"loc": (0.0, -0.04 * arch, -0.10 * arch), "rot": (-12.0 * arch, 0.0, 0.0)},
            "chest": {"rot": (-12.0 * arch, 0.0, 0.0)},
            "neck": {"rot": (-14.0 * arch, 0.0, 0.0)},
            "head": {"rot": (26.0 * arch, 0.0, math.sin(t * 14.0) * 4.0)},
            "jaw": {"rot": (34.0 * arch, 0.0, 0.0)},
            "halo": {"loc": (0.0, 0.0, 0.22 * arch), "scale": (1.0 + 0.28 * arch,) * 3},
            "fl_upper": {"rot": (-22.0 * arch, 0.0, -8.0 * arch)},
            "fr_upper": {"rot": (-22.0 * arch, 0.0, 8.0 * arch)},
            "bl_upper": {"rot": (18.0 * arch, 0.0, 0.0)},
            "br_upper": {"rot": (18.0 * arch, 0.0, 0.0)},
        })
    return n_frames


def _load_external_asset(path: str, action_name: str, use_toon: bool):
    ext = os.path.splitext(path)[1].lower()
    if ext in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=path)
    elif ext == ".fbx":
        bpy.ops.import_scene.fbx(filepath=path)
    else:
        raise ValueError(f"Unsupported model extension: {ext}")

    arms = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not arms:
        raise RuntimeError("No Armature found in external model")
    arm = arms[0]

    if action_name and action_name in bpy.data.actions:
        arm.animation_data_create()
        arm.animation_data.action = bpy.data.actions[action_name]
    elif arm.animation_data and arm.animation_data.action:
        pass
    elif len(bpy.data.actions) > 0:
        arm.animation_data_create()
        arm.animation_data.action = bpy.data.actions[0]

    act = arm.animation_data.action if arm.animation_data else None
    start_frame = float(act.frame_range[0]) if act else 1.0
    bpy.context.scene.frame_set(int(round(start_frame)))
    bpy.context.view_layer.update()

    # Normalize model height ~2.0 units centered around X=0, Y=0 resting at Z=0
    pts = [m.matrix_world @ Vector(v) for m in meshes for v in m.bound_box]
    min_z = min(p.z for p in pts)
    max_z = max(p.z for p in pts)
    h = max(0.01, max_z - min_z)
    scale_f = 2.0 / h
    arm.scale = (arm.scale.x * scale_f, arm.scale.y * scale_f, arm.scale.z * scale_f)
    bpy.context.view_layer.update()

    pts = [m.matrix_world @ Vector(v) for m in meshes for v in m.bound_box]
    min_z = min(p.z for p in pts)
    cx = 0.5 * (min(p.x for p in pts) + max(p.x for p in pts))
    cy = 0.5 * (min(p.y for p in pts) + max(p.y for p in pts))
    arm.location.x -= cx
    arm.location.y -= cy
    arm.location.z -= min_z
    bpy.context.view_layer.update()

    if use_toon:
        _toonify_external_materials(meshes)
        ink = _make_ink_mat()
        for m in meshes:
            ws = m.matrix_world.to_scale()
            avg_s = max(0.001, (abs(ws.x) + abs(ws.y) + abs(ws.z)) / 3.0)
            _add_outline(m, ink, 0.024 / avg_s)

    span = max(1.0, float(act.frame_range[1] - act.frame_range[0])) if act else 8.0
    return arm, meshes, start_frame, span


def _render_8dir_sheet(
    arm: bpy.types.Object,
    n_frames: int,
    cell_size: int,
    out_png: str,
    start_frame: float = 1.0,
    frame_step: float = 1.0,
    yaw_offset: float = 0.0,
    pin_meshes: list[bpy.types.Object] | None = None,
) -> None:
    scene = bpy.context.scene
    tmp_dir = out_png + "_tmp_frames"
    os.makedirs(tmp_dir, exist_ok=True)
    os.makedirs(os.path.dirname(out_png), exist_ok=True)

    turntable = bpy.data.objects.new("Turntable", None)
    scene.collection.objects.link(turntable)
    turntable.location = (0.0, 0.0, 0.0)
    turntable.rotation_mode = "XYZ"
    arm.parent = turntable
    arm.matrix_parent_inverse = Matrix.Identity(4)

    frame_centers: list[tuple[float, float]] = [(0.0, 0.0)] * n_frames
    if pin_meshes:
        turntable.rotation_euler = (0.0, 0.0, 0.0)
        for col in range(n_frames):
            turntable.location = (0.0, 0.0, 0.0)
            scene.frame_set(int(round(start_frame + col * frame_step)))
            bpy.context.view_layer.update()
            dg = bpy.context.evaluated_depsgraph_get()
            pts = [
                m_eval.matrix_world @ Vector(v)
                for m in pin_meshes
                for m_eval in [m.evaluated_get(dg)]
                for v in m_eval.bound_box
            ]
            cx = 0.5 * (min(p.x for p in pts) + max(p.x for p in pts))
            cy = 0.5 * (min(p.y for p in pts) + max(p.y for p in pts))
            frame_centers[col] = (cx, cy)

    # Row order matches Godot CharacterRig octants: 0=E, 1=SE, 2=S, 3=SW, 4=W, 5=NW, 6=N, 7=NE
    sheet = np.zeros((cell_size * 8, cell_size * n_frames, 4), dtype=np.float32)

    for row in range(8):
        yaw_deg = 90.0 - float(row) * 45.0 + yaw_offset
        yaw_rad = math.radians(yaw_deg)
        turntable.rotation_euler = (0.0, 0.0, yaw_rad)
        c_y, s_y = math.cos(yaw_rad), math.sin(yaw_rad)
        for col in range(n_frames):
            if pin_meshes:
                cx, cy = frame_centers[col]
                turntable.location = (-(cx * c_y - cy * s_y), -(cx * s_y + cy * c_y), 0.0)
            f = int(round(start_frame + col * frame_step))
            scene.frame_set(f)
            bpy.context.view_layer.update()
            cell_path = os.path.join(tmp_dir, f"r{row}_c{col}.png")
            scene.render.filepath = cell_path
            bpy.ops.render.render(write_still=True)

            img = bpy.data.images.load(cell_path, check_existing=False)
            px = np.array(img.pixels[:], dtype=np.float32).reshape((cell_size, cell_size, 4))
            px = np.flipud(px)
            sheet[row * cell_size : (row + 1) * cell_size, col * cell_size : (col + 1) * cell_size, :] = px
            bpy.data.images.remove(img)

    out_img = bpy.data.images.new("PackedSheet", width=cell_size * n_frames, height=cell_size * 8, alpha=True)
    out_img.pixels.foreach_set(np.flipud(sheet).ravel())
    out_img.filepath_raw = out_png
    out_img.file_format = "PNG"
    out_img.save()
    bpy.data.images.remove(out_img)

    for fn in os.listdir(tmp_dir):
        os.remove(os.path.join(tmp_dir, fn))
    os.rmdir(tmp_dir)

    meta = {
        "cols": n_frames,
        "rows": 8,
        "cell_width": cell_size,
        "cell_height": cell_size,
        "directions": ["E", "SE", "S", "SW", "W", "NW", "N", "NE"],
    }
    with open(os.path.splitext(out_png)[0] + ".json", "w", encoding="utf-8") as fp:
        json.dump(meta, fp, ensure_ascii=False, indent=2)
    print(f"Baked 8-dir sheet -> {out_png} ({cell_size * n_frames}x{cell_size * 8})")


def main() -> None:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--builtin", choices=["hero", "wolf_boss"], default=None)
    ap.add_argument("--input", default=None)
    ap.add_argument("--action", default="")
    ap.add_argument("--out", default="")
    ap.add_argument("--out-dir", default="")
    ap.add_argument("--cell-size", type=int, default=128)
    ap.add_argument("--frames", type=int, default=8)
    ap.add_argument("--yaw-offset", type=float, default=0.0)
    ap.add_argument("--toon", action="store_true")
    args = ap.parse_args(argv)

    if args.builtin == "hero":
        _clear_scene()
        _setup_render(args.cell_size)
        _setup_lights_and_camera(ortho_scale=2.55, cam_dist=8.0, target_z=1.02, elev_deg=32.0)
        arm, slash_obj = _build_hero_rig()
        out_dir = args.out_dir or os.path.dirname(args.out)
        for act in ("run", "idle", "attack"):
            nf = _animate_hero(arm, slash_obj, act)
            _render_8dir_sheet(arm, nf, args.cell_size, os.path.join(out_dir, f"anim_hero_8dir_{act}.png"))
    elif args.builtin == "wolf_boss":
        _clear_scene()
        _setup_render(args.cell_size)
        _setup_lights_and_camera(ortho_scale=3.15, cam_dist=9.0, target_z=0.95, elev_deg=30.0)
        arm = _build_wolf_rig()
        out_dir = args.out_dir or os.path.dirname(args.out)
        for act in ("run", "windup", "pounce", "roar"):
            nf = _animate_wolf(arm, act)
            _render_8dir_sheet(arm, nf, args.cell_size, os.path.join(out_dir, f"anim_wolf_boss_8dir_{act}.png"))
    elif args.input:
        _clear_scene()
        _setup_render(args.cell_size)
        _setup_lights_and_camera(ortho_scale=2.55, cam_dist=8.0, target_z=1.02, elev_deg=32.0)
        arm, ext_meshes, start_frame, span = _load_external_asset(args.input, args.action, args.toon)
        step = span / float(max(1, args.frames))
        _render_8dir_sheet(
            arm,
            args.frames,
            args.cell_size,
            args.out,
            start_frame=start_frame,
            frame_step=step,
            yaw_offset=args.yaw_offset,
            pin_meshes=ext_meshes,
        )


if __name__ == "__main__":
    main()
