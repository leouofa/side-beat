#!/usr/bin/env python3
"""
Generates Milestone 2 (Stages 2-4: LA, Madrid, Moscow) Mythic Bosses + Drone Fly minion:
  1. Chupar    — Glutton Sovereign of the Boulevard (Sumo brawler + belly_jiggle)
  2. Bar       — Bird God of the Carrion Gale (Avian raptor + sonic wings/beak)
  3. Dadur     — Iron-Hide Bull of the Courtyard (Bovine wrestler + horn.L/R)
  4. Baphomet  — Idol of the Brazen Horn (Armored bovine juggernaut + brazen horns)
  5. Andruas   — Fang of the Frozen Conduit (Serpentine naga + tail_01..tail_08 + hood)
  6. Beezelbub — Lord of the Plague Swarm (Insectoid 4-wing fly god + mandibles)
  + Drone Fly  — Compact fly minion summoned by Beezelbub
"""
import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

import bpy
from mathutils import Vector
from rig_common import (
    LowPolyPartBuilder,
    STANCE_BASE,
    author_nla_action,
    author_shared_locomotion_clips,
    build_base_fighter_body,
    count_scene_triangles,
    create_humanoid_24_armature,
    export_glb,
    make_palette_material,
    merge_pose,
    render_side_profile_preview,
    reset_scene,
)

ROOT_DIR = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))
OUT_BOSS_DIR = os.path.join(ROOT_DIR, "assets", "bosses")
OUT_ENEMY_DIR = os.path.join(ROOT_DIR, "assets", "enemies")
OUT_PREV_DIR = os.path.join(ROOT_DIR, "assets", "previews")


def author_standard_boss_clips_m2(arm_obj: bpy.types.Object, has_wings: bool = False, has_tail: bool = False) -> None:
    wing_flare = {"wing_shoulder.L": (10, -25, 35), "wing_mid.L": (0, -20, 25), "wing_shoulder.R": (10, 25, -35), "wing_mid.R": (0, 20, -25)} if has_wings else {}
    wing_tuck = {"wing_shoulder.L": (20, 25, -18), "wing_shoulder.R": (20, -25, 18)} if has_wings else {}
    tail_whip = {"tail_03": (15, 0, 30), "tail_05": (-20, 0, 45), "tail_07": (25, 0, 60)} if has_tail else {}

    taunt_a = merge_pose(STANCE_BASE, wing_flare, tail_whip, {
        "chest": (-14, 0, 0), "head": (-16, 0, 0),
        "upper_arm.L": (-125, 38, -20), "upper_arm.R": (-135, -38, 20),
    })
    author_nla_action(arm_obj, "boss_intro_taunt", [
        (1, STANCE_BASE, None),
        (14, taunt_a, {"hips": (0.0, 0.0, 0.08)}),
        (34, taunt_a, {"hips": (0.0, 0.0, 0.08)}),
        (48, STANCE_BASE, {"hips": (0.0, 0.0, 0.0)}),
    ])

    lc_1 = merge_pose(STANCE_BASE, wing_tuck, {"chest": (14, 0, 24), "upper_arm.L": (-90, 8, -10), "lower_arm.L": (-10, 0, 0)})
    lc_2 = merge_pose(STANCE_BASE, wing_flare, tail_whip, {"chest": (18, 0, -28), "upper_arm.R": (-95, -8, 10), "lower_arm.R": (-8, 0, 0)})
    author_nla_action(arm_obj, "light_combo", [
        (1, STANCE_BASE, None),
        (7, lc_1, {"hips": (0.0, -0.08, 0.0)}),
        (16, lc_2, {"hips": (0.0, -0.16, 0.0)}),
        (24, lc_2, {"hips": (0.0, -0.16, 0.0)}),
        (34, STANCE_BASE, {"hips": (0.0, 0.0, 0.0)}),
    ])

    hb_wind = merge_pose(STANCE_BASE, wing_flare, {
        "spine_01": (-16, 0, 15), "chest": (-20, 0, 20),
        "upper_arm.R": (-155, -22, 14), "upper_arm.L": (-130, 22, -14),
    })
    hb_slam = merge_pose(STANCE_BASE, wing_tuck, tail_whip, {
        "hips": (24, 0, -20), "chest": (28, 0, -24),
        "upper_arm.R": (-38, -8, -12), "lower_arm.R": (-8, 0, 0),
        "thigh.L": (-50, 0, 8), "shin.L": (58, 0, 0),
    })
    author_nla_action(arm_obj, "heavy_armor_breaker", [
        (1, STANCE_BASE, None),
        (12, hb_wind, {"hips": (0.0, 0.06, 0.06)}),
        (20, hb_slam, {"hips": (0.0, -0.24, -0.10)}),
        (30, hb_slam, {"hips": (0.0, -0.24, -0.10)}),
        (44, STANCE_BASE, {"hips": (0.0, 0.0, 0.0)}),
    ])

    sp1_a = merge_pose(STANCE_BASE, wing_flare, tail_whip, {
        "hips": (20, 0, 45), "chest": (20, 0, 45),
        "upper_arm.R": (-88, -35, 0), "lower_arm.R": (-5, 0, 0),
        "upper_arm.L": (-88, 35, 0), "lower_arm.L": (-5, 0, 0),
    })
    sp1_b = merge_pose(sp1_a, {"hips": (20, 0, -55), "chest": (20, 0, -55)})
    author_nla_action(arm_obj, "signature_special_1", [
        (1, STANCE_BASE, None),
        (10, sp1_a, {"hips": (0.0, -0.10, -0.06)}),
        (20, sp1_b, {"hips": (0.0, -0.22, -0.06)}),
        (30, sp1_a, {"hips": (0.0, -0.16, -0.06)}),
        (42, STANCE_BASE, {"hips": (0.0, 0.0, 0.0)}),
    ])

    sp2_dive = merge_pose(STANCE_BASE, wing_flare, tail_whip, {
        "hips": (36, 0, 0), "chest": (18, 0, 0),
        "thigh.L": (-55, 0, 12), "thigh.R": (-48, 0, -12),
        "upper_arm.R": (-120, -25, 10), "upper_arm.L": (-120, 25, -10),
    })
    author_nla_action(arm_obj, "signature_special_2", [
        (1, STANCE_BASE, None),
        (9, sp2_dive, {"hips": (0.0, -0.14, 0.22)}),
        (24, sp2_dive, {"hips": (0.0, -0.26, -0.04)}),
        (38, STANCE_BASE, {"hips": (0.0, 0.0, 0.0)}),
    ])

    roar = merge_pose(STANCE_BASE, wing_flare, tail_whip, {
        "hips": (-12, 0, 0), "spine_01": (-18, 0, 0), "chest": (-24, 0, 0), "head": (-22, 0, 0),
        "upper_arm.L": (-110, 55, -20), "upper_arm.R": (-110, -55, 20),
    })
    author_nla_action(arm_obj, "phase_2_roar", [
        (1, STANCE_BASE, None),
        (10, roar, {"hips": (0.0, 0.0, 0.10)}),
        (32, roar, {"hips": (0.0, 0.0, 0.10)}),
        (45, STANCE_BASE, {"hips": (0.0, 0.0, 0.0)}),
    ])

    hips_rest_z = arm_obj.pose.bones["hips"].head.z if "hips" in arm_obj.pose.bones else 0.94
    dy = -(hips_rest_z - 0.18)
    ko = {
        "hips": (-85, 0, 0), "spine_01": (-10, 0, 0),
        "upper_arm.L": (-18, 52, 0), "upper_arm.R": (-18, -52, 0),
        "thigh.L": (10, 0, 12), "thigh.R": (10, 0, -12),
    }
    author_nla_action(arm_obj, "ko_collapse", [
        (1, STANCE_BASE, {"hips": (0.0, 0.0, 0.0)}),
        (18, ko, {"hips": (0.0, dy, 0.18)}),
        (45, ko, {"hips": (0.0, dy, 0.18)}),
    ])


def build_chupar() -> None:
    """Chupar: Overweight Humanoid God (1.35x wide sumo brawler + belly_jiggle)."""
    reset_scene()
    arm_obj, coords = create_humanoid_24_armature("Chupar", height_scale=1.05, width_scale=1.40)

    # Add belly_jiggle bone attached to spine_01
    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_obj.data.edit_bones
    bj = eb.new("belly_jiggle")
    bj.head = Vector((0.0, -0.15, 1.15))
    bj.tail = Vector((0.0, -0.45, 1.15))
    bj.parent = eb["spine_01"]
    coords["belly_jiggle"] = (bj.head.copy(), bj.tail.copy())
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in arm_obj.pose.bones:
        pb.rotation_mode = "XYZ"

    b = LowPolyPartBuilder("Chupar")
    m_skin = make_palette_material("Chupar_Skin", "#F5CBA7", metallic=0.08, roughness=0.68)
    m_mawashi = make_palette_material("Chupar_Mawashi", "#FFA801", metallic=0.32, roughness=0.45, emission_hex="#FFA801", emission_strength=0.8)
    m_black = make_palette_material("Chupar_Hair", "#1E272E", metallic=0.20, roughness=0.55)
    m_gold = make_palette_material("Chupar_Gold", "#FFD700", metallic=0.75, roughness=0.30)

    build_base_fighter_body(b, coords, m_skin, m_mawashi, m_skin, m_gold, bulk=1.45)

    # Massive elastic belly attached to belly_jiggle bone
    bj0, bj1 = coords["belly_jiggle"]
    b.add_icosphere(bj0.lerp(bj1, 0.5), 0.38, "belly_jiggle", m_skin, subdivisions=2, scale=(1.25, 0.95, 1.1))
    # Sumo mawashi belt rope & apron
    b.add_box((0.0, -0.22, 1.05), (0.42, 0.12, 0.28), "hips", m_mawashi, bevel_amt=0.02)
    # Sumo topknot hair
    hd_mid = (coords["head"][0] + coords["head"][1]) * 0.5
    b.add_icosphere((0.0, 0.08, hd_mid.z + 0.14), 0.10, "head", m_black, subdivisions=1)
    b.add_box((0.0, 0.14, hd_mid.z + 0.22), (0.07, 0.16, 0.08), "head", m_gold)

    b.build_skinned_object(arm_obj)
    author_shared_locomotion_clips(arm_obj)
    author_standard_boss_clips_m2(arm_obj)
    tris = count_scene_triangles()
    print(f"[Chupar] Triangles: {tris}")
    render_side_profile_preview(arm_obj, os.path.join(OUT_PREV_DIR, "chupar_profile.png"), STANCE_BASE, cam_height=1.05, cam_dist=3.6)
    export_glb(os.path.join(OUT_BOSS_DIR, "chupar.glb"))


def build_bar() -> None:
    """Bar: Bird God of the Carrion Gale — Avian raptor with sonic gale wings, talons, and beak."""
    reset_scene()
    arm_obj, coords = create_humanoid_24_armature("Bar", height_scale=1.15, width_scale=1.12)

    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_obj.data.edit_bones

    def add_ext(bname: str, head: tuple[float, float, float], tail: tuple[float, float, float], parent: str):
        bn = eb.new(bname)
        bn.head = Vector(head)
        bn.tail = Vector(tail)
        bn.align_roll(Vector((0.0, 1.0, 0.0)))
        bn.parent = eb[parent]
        coords[bname] = (bn.head.copy(), bn.tail.copy())

    hd_mid = (coords["head"][0] + coords["head"][1]) * 0.5
    add_ext("beak_jaw", (0.0, -0.10, hd_mid.z - 0.03), (0.0, -0.44, hd_mid.z - 0.10), "head")

    ch = coords["chest"][1]
    for side, sx in [("L", 1.0), ("R", -1.0)]:
        add_ext(f"wing_shoulder.{side}", (sx * 0.12, 0.12, ch.z - 0.06), (sx * 0.58, 0.24, ch.z + 0.24), "chest")
        add_ext(f"wing_mid.{side}", (sx * 0.58, 0.24, ch.z + 0.24), (sx * 1.08, 0.30, ch.z + 0.48), f"wing_shoulder.{side}")
        add_ext(f"wing_tip.{side}", (sx * 1.08, 0.30, ch.z + 0.48), (sx * 1.58, 0.22, ch.z + 0.18), f"wing_mid.{side}")
        ft = coords[f"foot.{side}"][1]
        add_ext(f"talon_foot.{side}", (ft.x, ft.y, ft.z), (ft.x, ft.y - 0.24, ft.z - 0.02), f"foot.{side}")

    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in arm_obj.pose.bones:
        pb.rotation_mode = "XYZ"

    b = LowPolyPartBuilder("Bar")
    m_slate = make_palette_material("Bar_Slate", "#2F3640", metallic=0.35, roughness=0.50)
    m_cyan = make_palette_material("Bar_Cyan", "#00D4FF", metallic=0.45, roughness=0.30, emission_hex="#00D4FF", emission_strength=1.4)
    m_bronze = make_palette_material("Bar_Bronze", "#E1B12C", metallic=0.70, roughness=0.35)
    m_dark = make_palette_material("Bar_Dark", "#192A56", metallic=0.25, roughness=0.60)

    build_base_fighter_body(b, coords, m_slate, m_cyan, m_dark, m_bronze, bulk=1.08)

    # Sharp beak + gale crest
    b.add_blade_prism((0.0, -0.08, hd_mid.z + 0.04), (0.0, -0.50, hd_mid.z - 0.02), 0.16, 0.12, "head", m_bronze)
    bj0, bj1 = coords["beak_jaw"]
    b.add_blade_prism(bj0, bj1, 0.12, 0.08, "beak_jaw", m_bronze)
    b.add_blade_prism((0.0, 0.02, hd_mid.z + 0.10), (0.0, 0.40, hd_mid.z + 0.48), 0.14, 0.18, "head", m_cyan)

    for side, sx in [("L", 1.0), ("R", -1.0)]:
        ws0, ws1 = coords[f"wing_shoulder.{side}"]
        wm0, wm1 = coords[f"wing_mid.{side}"]
        wt0, wt1 = coords[f"wing_tip.{side}"]
        b.add_tapered_limb(ws0, ws1, 0.08, 0.065, f"wing_shoulder.{side}", m_slate, segments=7)
        b.add_tapered_limb(wm0, wm1, 0.065, 0.05, f"wing_mid.{side}", m_cyan, segments=7)
        b.add_blade_prism(wt0, wt1, 0.20, 0.04, f"wing_tip.{side}", m_cyan)
        for frac in (0.35, 0.75):
            p = ws0.lerp(ws1, frac)
            b.add_blade_prism(p, (p.x + sx * 0.15, p.y + 0.10, p.z - 0.45), 0.14, 0.03, f"wing_shoulder.{side}", m_cyan)
            p2 = wm0.lerp(wm1, frac)
            b.add_blade_prism(p2, (p2.x + sx * 0.22, p2.y + 0.10, p2.z - 0.55), 0.16, 0.03, f"wing_mid.{side}", m_bronze)
        tf0, tf1 = coords[f"talon_foot.{side}"]
        for dx in (-0.05, 0.0, 0.05):
            b.add_blade_prism((tf0.x + dx, tf0.y, tf0.z + 0.02), (tf1.x + dx * 1.4, tf1.y, tf1.z), 0.05, 0.05, f"talon_foot.{side}", m_bronze)

    b.build_skinned_object(arm_obj)
    author_shared_locomotion_clips(arm_obj)
    author_standard_boss_clips_m2(arm_obj, has_wings=True)
    tris = count_scene_triangles()
    print(f"[Bar] Triangles: {tris}")
    render_side_profile_preview(arm_obj, os.path.join(OUT_PREV_DIR, "bar_profile.png"), STANCE_BASE, cam_height=1.15, cam_dist=3.9)
    export_glb(os.path.join(OUT_BOSS_DIR, "bar.glb"))


def build_bovine_god(name: str, out_name: str, scale_w: float, scale_h: float, prim_hex: str, horn_hex: str, glow_hex: str) -> None:
    """Shared builder for Bovine Gods: Dadur (Madrid Mid-Boss) & Baphomet (Madrid Stage Boss)."""
    reset_scene()
    arm_obj, coords = create_humanoid_24_armature(name, height_scale=scale_h, width_scale=scale_w)

    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_obj.data.edit_bones

    def add_horn(side: str, sx: float):
        head = coords["head"][0]
        bn = eb.new(f"horn.{side}")
        bn.head = Vector((sx * 0.14 * scale_w, -0.05, head.z + 0.18))
        bn.tail = Vector((sx * 0.45 * scale_w, -0.15, head.z + 0.48))
        bn.parent = eb["head"]
        coords[f"horn.{side}"] = (bn.head.copy(), bn.tail.copy())

    add_horn("L", 1.0)
    add_horn("R", -1.0)

    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in arm_obj.pose.bones:
        pb.rotation_mode = "XYZ"

    b = LowPolyPartBuilder(name)
    m_body = make_palette_material(f"{name}_Body", prim_hex, metallic=0.30, roughness=0.55)
    m_horn = make_palette_material(f"{name}_Horn", horn_hex, metallic=0.75, roughness=0.30, emission_hex=glow_hex, emission_strength=1.2)
    m_armor = make_palette_material(f"{name}_Armor", "#2C3E50", metallic=0.65, roughness=0.35)
    m_skin = make_palette_material(f"{name}_Skin", "#5D4037", metallic=0.10, roughness=0.65)

    build_base_fighter_body(b, coords, m_body, m_armor, m_skin, m_horn, bulk=scale_w * 0.95)

    # Broad bull snout & curved horns
    hd_mid = (coords["head"][0] + coords["head"][1]) * 0.5
    b.add_box((0.0, -0.22, hd_mid.z - 0.05), (0.24, 0.22, 0.16), "head", m_body, bevel_amt=0.02)
    b.add_icosphere((0.0, -0.32, hd_mid.z - 0.10), 0.08, "head", m_horn, subdivisions=1) # Bull ring
    for side, sx in [("L", 1.0), ("R", -1.0)]:
        h0, h1 = coords[f"horn.{side}"]
        b.add_blade_prism(h0, h1, 0.14 * scale_w, 0.10, f"horn.{side}", m_horn)
        # Heavy shoulder plates
        cl = coords[f"clavicle.{side}"][1]
        b.add_box((cl.x + sx * 0.05, cl.y, cl.z + 0.05), (0.28, 0.32, 0.18), f"clavicle.{side}", m_armor, bevel_amt=0.02)

    b.build_skinned_object(arm_obj)
    author_shared_locomotion_clips(arm_obj)
    author_standard_boss_clips_m2(arm_obj)
    tris = count_scene_triangles()
    print(f"[{name}] Triangles: {tris}")
    render_side_profile_preview(arm_obj, os.path.join(OUT_PREV_DIR, f"{out_name}_profile.png"), STANCE_BASE, cam_height=1.2, cam_dist=4.0)
    export_glb(os.path.join(OUT_BOSS_DIR, f"{out_name}.glb"))


def build_andruas() -> None:
    """Andruas: Snake God of the Frozen Conduit — Serpentine Naga with tail_01..tail_08 replacing legs."""
    reset_scene()
    arm_obj, coords = create_humanoid_24_armature("Andruas", height_scale=1.10, width_scale=1.15, include_legs=False)

    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_obj.data.edit_bones

    # 8-bone snake tail chain extending from hips downward & coiling
    tail_parent = eb["hips"]
    prev_pos = Vector((0.0, 0.0, 0.94 * 1.10))
    for i in range(1, 9):
        tname = f"tail_{i:02d}"
        bn = eb.new(tname)
        # S-curve coil path
        cur_z = max(0.05, 0.94 * 1.10 - float(i) * 0.16)
        cur_y = 0.12 * ((i % 2) * 2 - 1)
        cur_x = 0.08 * (((i + 1) % 2) * 2 - 1)
        next_pos = Vector((cur_x, cur_y, cur_z))
        bn.head = prev_pos
        bn.tail = next_pos
        bn.align_roll(Vector((0.0, 1.0, 0.0)))
        bn.parent = tail_parent
        coords[tname] = (bn.head.copy(), bn.tail.copy())
        tail_parent = bn
        prev_pos = next_pos

    # Cobra hood flare bones & fang jaw
    hd_mid = (coords["head"][0] + coords["head"][1]) * 0.5
    for side, sx in [("L", 1.0), ("R", -1.0)]:
        hf = eb.new(f"hood_flare.{side}")
        hf.head = Vector((sx * 0.08, 0.05, hd_mid.z))
        hf.tail = Vector((sx * 0.38, 0.10, hd_mid.z + 0.15))
        hf.parent = eb["head"]
        coords[f"hood_flare.{side}"] = (hf.head.copy(), hf.tail.copy())

    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in arm_obj.pose.bones:
        pb.rotation_mode = "XYZ"

    b = LowPolyPartBuilder("Andruas")
    m_scales = make_palette_material("Andruas_Scales", "#2CE8A2", metallic=0.35, roughness=0.40, emission_hex="#2CE8A2", emission_strength=1.1)
    m_violet = make_palette_material("Andruas_Violet", "#6C3483", metallic=0.30, roughness=0.55)
    m_gold = make_palette_material("Andruas_Gold", "#F1C40F", metallic=0.72, roughness=0.30)
    m_skin = make_palette_material("Andruas_Skin", "#1ABC9C", metallic=0.10, roughness=0.60)

    build_base_fighter_body(b, coords, m_scales, m_violet, m_skin, m_gold, bulk=1.10, include_legs=False)

    # Cobra hood flares on head
    for side, sx in [("L", 1.0), ("R", -1.0)]:
        h0, h1 = coords[f"hood_flare.{side}"]
        b.add_blade_prism(h0, h1, 0.22, 0.04, f"hood_flare.{side}", m_scales)

    # 8-bone segmented articulated snake tail
    for i in range(1, 9):
        tname = f"tail_{i:02d}"
        t0, t1 = coords[tname]
        r_start = 0.22 * (1.0 - float(i - 1) * 0.09)
        r_end = 0.22 * (1.0 - float(i) * 0.09)
        mat = m_scales if i % 2 == 1 else m_violet
        b.add_tapered_limb(t0, t1, max(r_start, 0.04), max(r_end, 0.03), tname, mat, segments=8)

    b.build_skinned_object(arm_obj)
    author_shared_locomotion_clips(arm_obj)
    author_standard_boss_clips_m2(arm_obj, has_tail=True)
    tris = count_scene_triangles()
    print(f"[Andruas] Triangles: {tris}")
    render_side_profile_preview(arm_obj, os.path.join(OUT_PREV_DIR, "andruas_profile.png"), STANCE_BASE, cam_height=1.1, cam_dist=3.8)
    export_glb(os.path.join(OUT_BOSS_DIR, "andruas.glb"))


def build_beezelbub() -> None:
    """Beezelbub: Lord of the Plague Swarm — Insectoid 4-winged Fly God with mandibles."""
    reset_scene()
    arm_obj, coords = create_humanoid_24_armature("Beezelbub", height_scale=1.12, width_scale=1.05)

    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_obj.data.edit_bones

    ch = coords["chest"][1]
    for side, sx in [("L", 1.0), ("R", -1.0)]:
        wu = eb.new(f"dorsal_wing_upper.{side}")
        wu.head = Vector((sx * 0.10, 0.12, ch.z + 0.05))
        wu.tail = Vector((sx * 0.85, 0.24, ch.z + 0.55))
        wu.parent = eb["chest"]
        coords[f"dorsal_wing_upper.{side}"] = (wu.head.copy(), wu.tail.copy())

        wl = eb.new(f"dorsal_wing_lower.{side}")
        wl.head = Vector((sx * 0.08, 0.14, ch.z - 0.15))
        wl.tail = Vector((sx * 0.70, 0.22, ch.z + 0.10))
        wl.parent = eb["chest"]
        coords[f"dorsal_wing_lower.{side}"] = (wl.head.copy(), wl.tail.copy())

        # Mandibles on head
        hd = coords["head"][0]
        md = eb.new(f"mandible.{side}")
        md.head = Vector((sx * 0.08, -0.12, hd.z - 0.05))
        md.tail = Vector((sx * 0.24, -0.28, hd.z - 0.12))
        md.parent = eb["head"]
        coords[f"mandible.{side}"] = (md.head.copy(), md.tail.copy())

    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in arm_obj.pose.bones:
        pb.rotation_mode = "XYZ"

    b = LowPolyPartBuilder("Beezelbub")
    m_carapace = make_palette_material("Beez_Carapace", "#1E272E", metallic=0.55, roughness=0.35)
    m_toxin = make_palette_material("Beez_Toxin", "#A3CB38", metallic=0.30, roughness=0.40, emission_hex="#A3CB38", emission_strength=1.5)
    m_eye = make_palette_material("Beez_Eye", "#FF3838", metallic=0.40, roughness=0.25, emission_hex="#FF3838", emission_strength=1.8)
    m_vein = make_palette_material("Beez_Vein", "#00D2D3", metallic=0.20, roughness=0.50)

    build_base_fighter_body(b, coords, m_carapace, m_toxin, m_carapace, m_eye, bulk=1.05)

    # Huge compound fly eyes & sharp mandibles
    hd_mid = (coords["head"][0] + coords["head"][1]) * 0.5
    for side, sx in [("L", 1.0), ("R", -1.0)]:
        b.add_icosphere((sx * 0.14, -0.12, hd_mid.z + 0.02), 0.12, "head", m_eye, subdivisions=2, scale=(1.1, 0.9, 1.2))
        m0, m1 = coords[f"mandible.{side}"]
        b.add_blade_prism(m0, m1, 0.08, 0.04, f"mandible.{side}", m_toxin)

        # 4 insectoid translucent venom wings
        u0, u1 = coords[f"dorsal_wing_upper.{side}"]
        b.add_blade_prism(u0, u1, 0.22, 0.025, f"dorsal_wing_upper.{side}", m_toxin)
        l0, l1 = coords[f"dorsal_wing_lower.{side}"]
        b.add_blade_prism(l0, l1, 0.18, 0.025, f"dorsal_wing_lower.{side}", m_vein)

    b.build_skinned_object(arm_obj)
    author_shared_locomotion_clips(arm_obj)
    author_standard_boss_clips_m2(arm_obj, has_wings=True)
    tris = count_scene_triangles()
    print(f"[Beezelbub] Triangles: {tris}")
    render_side_profile_preview(arm_obj, os.path.join(OUT_PREV_DIR, "beezelbub_profile.png"), STANCE_BASE, cam_height=1.1, cam_dist=3.8)
    export_glb(os.path.join(OUT_BOSS_DIR, "beezelbub.glb"))


def build_drone_fly() -> None:
    """Lightweight Drone Fly unit (~280 tris) summoned by Beezelbub."""
    reset_scene()
    arm_data = bpy.data.armatures.new("DroneFly_ArmatureData")
    arm_obj = bpy.data.objects.new("DroneFly", arm_data)
    bpy.context.scene.collection.objects.link(arm_obj)
    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_data.edit_bones

    root = eb.new("root")
    root.head = Vector((0.0, 0.0, 0.0))
    root.tail = Vector((0.0, 0.0, 0.2))

    for side, sx in [("L", 1.0), ("R", -1.0)]:
        w = eb.new(f"wing.{side}")
        w.head = Vector((sx * 0.05, 0.02, 0.10))
        w.tail = Vector((sx * 0.35, 0.10, 0.25))
        w.parent = root

    bpy.ops.object.mode_set(mode="OBJECT")

    b = LowPolyPartBuilder("DroneFly")
    m_body = make_palette_material("Drone_Body", "#1E272E", metallic=0.6, roughness=0.4)
    m_eye = make_palette_material("Drone_Eye", "#FF3838", metallic=0.2, roughness=0.3, emission_hex="#FF3838", emission_strength=1.8)
    m_wing = make_palette_material("Drone_Wing", "#A3CB38", metallic=0.1, roughness=0.3, emission_hex="#A3CB38", emission_strength=1.2)

    # Core fly thorax & abdomen
    b.add_icosphere((0.0, 0.0, 0.08), 0.12, "root", m_body, subdivisions=1, scale=(0.9, 1.4, 0.8))
    b.add_icosphere((0.06, -0.10, 0.10), 0.055, "root", m_eye, subdivisions=1)
    b.add_icosphere((-0.06, -0.10, 0.10), 0.055, "root", m_eye, subdivisions=1)

    for side, sx in [("L", 1.0), ("R", -1.0)]:
        b.add_blade_prism((sx * 0.05, 0.02, 0.10), (sx * 0.35, 0.10, 0.25), 0.12, 0.015, f"wing.{side}", m_wing)

    b.build_skinned_object(arm_obj)

    # Author rapid flutter loop
    author_nla_action(arm_obj, "idle_fight_stance", [
        (1, {"wing.L": (0, 0, 35), "wing.R": (0, 0, -35)}, None),
        (5, {"wing.L": (0, 0, -35), "wing.R": (0, 0, 35)}, None),
        (10, {"wing.L": (0, 0, 35), "wing.R": (0, 0, -35)}, None),
    ])
    author_nla_action(arm_obj, "walk_forward", [
        (1, {"wing.L": (0, 0, 45), "wing.R": (0, 0, -45)}, None),
        (4, {"wing.L": (0, 0, -45), "wing.R": (0, 0, 45)}, None),
        (8, {"wing.L": (0, 0, 45), "wing.R": (0, 0, -45)}, None),
    ])
    author_nla_action(arm_obj, "light_1", [
        (1, {}, None),
        (6, {"root": (-25, 0, 0)}, {"root": (0, -0.2, 0)}),
        (12, {}, None),
    ])
    author_nla_action(arm_obj, "ko_collapse", [
        (1, {}, None),
        (10, {"root": (90, 0, 0)}, {"root": (0, 0, -0.5)}),
    ])

    tris = count_scene_triangles()
    print(f"[DroneFly] Triangles: {tris}")
    export_glb(os.path.join(OUT_ENEMY_DIR, "drone_fly.glb"))


def main() -> None:
    build_chupar()
    build_bar()
    build_bovine_god("Dadur", "dadur", 1.25, 1.18, "#795548", "#E67E22", "#E67E22")
    build_bovine_god("Baphomet", "baphomet", 1.45, 1.25, "#2C3E50", "#E74C3C", "#FF1E42")
    build_andruas()
    build_beezelbub()
    build_drone_fly()
    print("Successfully generated all Milestone 2 Bosses and Drone Fly!")


if __name__ == "__main__":
    main()
