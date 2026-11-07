#!/usr/bin/env python3
"""
Generates the 4 Playable Mythic Gods (Endor, Ir, Osiris, Horus) as low-poly rigged .glb assets
with 24-bone skeletons, signature weapons, 23 fighting-game NLA animations (60 FPS), and preview sheets.
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
OUT_CHAR_DIR = os.path.join(ROOT_DIR, "assets", "characters")
OUT_PREV_DIR = os.path.join(ROOT_DIR, "assets", "previews")


def author_god_combat_clips(arm_obj: bpy.types.Object, god_id: str) -> None:
    """Authors all 12 per_god_combat NLA actions with Startup / Active / Recovery frame windows."""
    # light_1: crisp lead jab / quick slash (strict 2.5D planar profile)
    l1_wind = merge_pose(STANCE_BASE, {
        "chest": (-4, 0, 0), "upper_arm.L": (-25, 15, 0), "lower_arm.L": (-95, 0, 0),
    })
    l1_hit = merge_pose(STANCE_BASE, {
        "hips": (-8, 0, 0), "spine_01": (-14, 0, 0), "chest": (-18, 0, 0),
        "upper_arm.L": (-90, 0, 0), "lower_arm.L": (-6, 0, 0),
    })
    author_nla_action(arm_obj, "light_1", [
        (1, l1_wind, None),
        (4, l1_hit, {"hips": (0.0, -0.08, 0.0)}),
        (9, l1_hit, {"hips": (0.0, -0.08, 0.0)}),
        (16, STANCE_BASE, {"hips": (0.0, 0.0, 0.0)}),
    ])

    # light_2: cross weapon/fist strike
    l2_wind = merge_pose(STANCE_BASE, {
        "chest": (4, 0, 0), "upper_arm.R": (15, -20, 0), "lower_arm.R": (-70, 0, 0),
    })
    l2_hit = merge_pose(STANCE_BASE, {
        "hips": (-10, 0, 0), "spine_01": (-16, 0, 0), "chest": (-20, 0, 0),
        "upper_arm.R": (-95, -6, 0), "lower_arm.R": (-10, 0, 0),
    })
    author_nla_action(arm_obj, "light_2", [
        (1, l2_wind, None),
        (5, l2_hit, {"hips": (0.0, -0.12, 0.0)}),
        (11, l2_hit, {"hips": (0.0, -0.12, 0.0)}),
        (19, STANCE_BASE, {"hips": (0.0, 0.0, 0.0)}),
    ])

    # light_3: combo ender sweep / wide cleave
    l3_wind = merge_pose(STANCE_BASE, {
        "chest": (4, 0, 0), "upper_arm.R": (-65, -35, 0), "lower_arm.R": (-35, 0, 0),
    })
    l3_hit = merge_pose(STANCE_BASE, {
        "hips": (-14, 0, 0), "spine_01": (-20, 0, 0), "chest": (-24, 0, 0),
        "upper_arm.R": (-90, 15, 0), "lower_arm.R": (-8, 0, 0),
        "thigh.L": (-45, 0, 0), "shin.L": (50, 0, 0),
    })
    author_nla_action(arm_obj, "light_3", [
        (1, l3_wind, None),
        (6, l3_hit, {"hips": (0.0, -0.18, -0.04)}),
        (13, l3_hit, {"hips": (0.0, -0.18, -0.04)}),
        (24, STANCE_BASE, {"hips": (0.0, 0.0, 0.0)}),
    ])

    # heavy_ground: high-impact overhead / thrust guard-breaker (leaned forward & driving down)
    hv_wind = merge_pose(STANCE_BASE, {
        "spine_01": (8, 0, 0), "chest": (10, 0, 0), "head": (-6, 0, 0),
        "upper_arm.R": (-165, -15, 0), "lower_arm.R": (-30, 0, 0),
        "upper_arm.L": (-140, 15, 0), "lower_arm.L": (-20, 0, 0),
    })
    hv_slam = merge_pose(STANCE_BASE, {
        "hips": (-14, 0, 0), "spine_01": (-24, 0, 0), "chest": (-28, 0, 0), "head": (12, 0, 0),
        "upper_arm.R": (-85, -8, 0), "lower_arm.R": (-12, 0, 0),
        "upper_arm.L": (-40, 12, 0), "lower_arm.L": (-10, 0, 0),
        "thigh.L": (-52, 0, 0), "shin.L": (60, 0, 0),
        "thigh.R": (25, 0, 0), "shin.R": (15, 0, 0),
    })
    author_nla_action(arm_obj, "heavy_ground", [
        (1, STANCE_BASE, None),
        (8, hv_wind, {"hips": (0.0, 0.08, 0.04)}),
        (13, hv_slam, {"hips": (0.0, -0.26, -0.12)}),
        (21, hv_slam, {"hips": (0.0, -0.26, -0.12)}),
        (34, STANCE_BASE, {"hips": (0.0, 0.0, 0.0)}),
    ])

    # launcher_up: rising uppercut / skyward scoop
    up_crouch = merge_pose(STANCE_BASE, {
        "hips": (-16, 0, 0), "spine_01": (-16, 0, 0),
        "upper_arm.R": (20, -10, 0), "lower_arm.R": (-90, 0, 0),
        "thigh.L": (-52, 0, 0), "shin.L": (72, 0, 0),
    })
    up_rise = merge_pose(STANCE_BASE, {
        "hips": (-6, 0, 0), "spine_01": (-10, 0, 0), "chest": (-12, 0, 0),
        "upper_arm.R": (-160, -6, 0), "lower_arm.R": (-12, 0, 0),
        "thigh.R": (-45, 0, 0), "shin.R": (55, 0, 0),
    })
    author_nla_action(arm_obj, "launcher_up", [
        (1, up_crouch, {"hips": (0.0, 0.0, -0.16)}),
        (7, up_rise, {"hips": (0.0, -0.10, 0.20)}),
        (15, up_rise, {"hips": (0.0, -0.10, 0.22)}),
        (28, STANCE_BASE, {"hips": (0.0, 0.0, 0.0)}),
    ])

    # air_combo_1
    ac1_hit = merge_pose(STANCE_BASE, {
        "spine_01": (-12, 0, 0), "chest": (-14, 0, 0),
        "thigh.L": (-62, 0, 0), "shin.L": (72, 0, 0),
        "upper_arm.L": (-95, 10, 0), "lower_arm.L": (-10, 0, 0),
        "upper_arm.R": (-35, -20, 0),
    })
    author_nla_action(arm_obj, "air_combo_1", [
        (1, STANCE_BASE, None),
        (4, ac1_hit, None),
        (10, ac1_hit, None),
        (17, STANCE_BASE, None),
    ])

    # air_combo_2
    ac2_hit = merge_pose(STANCE_BASE, {
        "spine_01": (-14, 0, 0), "chest": (-18, 0, 0),
        "thigh.R": (-78, 0, 0), "shin.R": (12, 0, 0),
        "upper_arm.R": (-105, -8, 0), "lower_arm.R": (-8, 0, 0),
    })
    author_nla_action(arm_obj, "air_combo_2", [
        (1, ac1_hit, None),
        (5, ac2_hit, None),
        (12, ac2_hit, None),
        (20, STANCE_BASE, None),
    ])

    # air_dive_or_slam (Horus Falcon Dive / Endor Hammer Drop / Ir Dive Slash / Osiris Flail Drop)
    dive_pose = merge_pose(STANCE_BASE, {
        "hips": (-20, 0, 0), "spine_01": (-24, 0, 0), "chest": (-24, 0, 0),
        "thigh.R": (-42, 0, 0), "shin.R": (5, 0, 0),
        "thigh.L": (22, 0, 0), "shin.L": (68, 0, 0),
        "upper_arm.R": (-135 if god_id != "horus" else 35, -20, 0),
        "upper_arm.L": (35, 20, 0),
    })
    author_nla_action(arm_obj, "air_dive_or_slam", [
        (1, STANCE_BASE, None),
        (5, dive_pose, None),
        (18, dive_pose, None),
        (26, STANCE_BASE, None),
    ])

    # pantheon_special_1
    sp1_wind = merge_pose(STANCE_BASE, {
        "spine_01": (10, 0, 0), "chest": (12, 0, 0),
        "upper_arm.R": (-150, -25, 0), "upper_arm.L": (-110, 25, 0),
    })
    sp1_release = merge_pose(STANCE_BASE, {
        "hips": (-16, 0, 0), "spine_01": (-22, 0, 0), "chest": (-26, 0, 0),
        "upper_arm.R": (-80, 15, 0), "lower_arm.R": (-5, 0, 0),
        "upper_arm.L": (-65, 20, 0),
        "thigh.L": (-50, 0, 0), "shin.L": (58, 0, 0),
    })
    author_nla_action(arm_obj, "pantheon_special_1", [
        (1, sp1_wind, {"hips": (0.0, 0.06, 0.04)}),
        (8, sp1_release, {"hips": (0.0, -0.22, -0.08)}),
        (20, sp1_release, {"hips": (0.0, -0.22, -0.08)}),
        (32, STANCE_BASE, {"hips": (0.0, 0.0, 0.0)}),
    ])

    # pantheon_special_2 (Counter stance for Ir, Tackle for Endor, Spin for Osiris, Dive/Ascent for Horus)
    sp2_a = merge_pose(STANCE_BASE, {
        "hips": (-12, 0, 0), "spine_01": (-16, 0, 0), "chest": (-18, 0, 0),
        "upper_arm.L": (-88, 12, 0), "lower_arm.L": (-45, 0, 0),
        "upper_arm.R": (-88, -12, 0), "lower_arm.R": (-20, 0, 0),
    })
    sp2_b = merge_pose(STANCE_BASE, {
        "hips": (-18, 0, 0), "spine_01": (-24, 0, 0), "chest": (-28, 0, 0),
        "upper_arm.R": (-96, 8, 0), "lower_arm.R": (-8, 0, 0),
        "upper_arm.L": (-40, 30, 0),
    })
    author_nla_action(arm_obj, "pantheon_special_2", [
        (1, sp2_a, {"hips": (0.0, -0.08, -0.04)}),
        (9, sp2_b, {"hips": (0.0, -0.24, 0.0)}),
        (20, sp2_b, {"hips": (0.0, -0.24, 0.0)}),
        (32, STANCE_BASE, {"hips": (0.0, 0.0, 0.0)}),
    ])

    # pantheon_super (Ascendant mythic invocation + unleash)
    sup_charge = merge_pose(STANCE_BASE, {
        "hips": (10, 0, 0), "spine_01": (14, 0, 0), "chest": (16, 0, 0), "head": (-12, 0, 0),
        "upper_arm.L": (-145, 35, 0), "lower_arm.L": (-25, 0, 0),
        "upper_arm.R": (-145, -35, 0), "lower_arm.R": (-25, 0, 0),
    })
    sup_unleash = merge_pose(STANCE_BASE, {
        "hips": (-18, 0, 0), "spine_01": (-24, 0, 0), "chest": (-28, 0, 0),
        "upper_arm.L": (-88, 18, 0), "lower_arm.L": (-5, 0, 0),
        "upper_arm.R": (-92, -10, 0), "lower_arm.R": (-5, 0, 0),
        "thigh.L": (-48, 0, 0), "shin.L": (54, 0, 0),
    })
    author_nla_action(arm_obj, "pantheon_super", [
        (1, STANCE_BASE, None),
        (10, sup_charge, {"hips": (0.0, 0.0, 0.14)}),
        (20, sup_unleash, {"hips": (0.0, -0.22, -0.04)}),
        (38, sup_unleash, {"hips": (0.0, -0.22, -0.04)}),
        (50, STANCE_BASE, {"hips": (0.0, 0.0, 0.0)}),
    ])

    # morph_entry_pose (Dynamic 10-frame snap pose on Shared-Soul Morph)
    morph_snap = merge_pose(STANCE_BASE, {
        "spine_01": (-10, 0, 0), "chest": (-14, 0, 0),
        "upper_arm.R": (-78, -25, 0), "lower_arm.R": (-35, 0, 0),
        "upper_arm.L": (-55, 28, 0),
    })
    author_nla_action(arm_obj, "morph_entry_pose", [
        (1, morph_snap, {"hips": (0.0, -0.04, 0.02)}),
        (6, morph_snap, {"hips": (0.0, -0.04, 0.02)}),
        (12, STANCE_BASE, {"hips": (0.0, 0.0, 0.0)}),
    ])


def build_endor() -> None:
    reset_scene()
    arm_obj, coords = create_humanoid_24_armature("Endor", height_scale=1.06, width_scale=1.22)
    b = LowPolyPartBuilder("Endor")

    m_cyan = make_palette_material("Endor_Cyan", "#00D4FF", metallic=0.35, roughness=0.35, emission_hex="#00D4FF", emission_strength=1.4)
    m_navy = make_palette_material("Endor_Navy", "#1E3A5F", metallic=0.45, roughness=0.52)
    m_steel = make_palette_material("Endor_Steel", "#C8D6E5", metallic=0.75, roughness=0.38)
    m_skin = make_palette_material("Endor_Skin", "#E0AC8B", metallic=0.05, roughness=0.72)
    m_beard = make_palette_material("Endor_Beard", "#D9A441", metallic=0.1, roughness=0.7)

    build_base_fighter_body(b, coords, m_navy, m_steel, m_skin, m_cyan, bulk=1.22)

    # Horned Asgardian Helm + Braided Beard + Heavy Pauldrons + Cape
    hd = (coords["head"][0] + coords["head"][1]) * 0.5
    b.add_box((0.0, 0.01, hd.z + 0.06), (0.25, 0.27, 0.16), "head", m_steel, taper_top=0.82)
    b.add_blade_prism((0.12, -0.02, hd.z + 0.08), (0.28, -0.10, hd.z + 0.25), 0.07, 0.06, "head", m_cyan)
    b.add_blade_prism((-0.12, -0.02, hd.z + 0.08), (-0.28, -0.10, hd.z + 0.25), 0.07, 0.06, "head", m_cyan)
    b.add_box((0.0, -0.12, hd.z - 0.10), (0.16, 0.11, 0.18), "head", m_beard, taper_top=1.2)

    for side, sx in [("L", 1.0), ("R", -1.0)]:
        cl = coords[f"clavicle.{side}"][1]
        b.add_box((cl.x + sx * 0.04, 0.0, cl.z + 0.04), (0.20, 0.24, 0.14), f"clavicle.{side}", m_steel, rot_deg=(0, sx * -18, 0))
        # Thunder Gauntlet cuffs
        la = (coords[f"lower_arm.{side}"][0] + coords[f"lower_arm.{side}"][1]) * 0.5
        b.add_box((la.x, la.y, la.z), (0.14, 0.15, 0.19), f"lower_arm.{side}", m_cyan, bevel_amt=0.01)

    # Asgardian short battle cape on back_socket
    bs = coords["back_socket"][0]
    b.add_box((0.0, bs.y + 0.06, bs.z - 0.34), (0.44, 0.04, 0.68), "back_socket", m_navy, taper_top=0.78)

    # Signature Weapon: Runic War-Hammer in weapon_socket.R
    ws = coords["weapon_socket.R"][0]
    b.add_tapered_limb((ws.x, ws.y + 0.12, ws.z), (ws.x, ws.y - 0.56, ws.z), 0.028, 0.032, "weapon_socket.R", m_navy, segments=6)
    b.add_box((ws.x, ws.y - 0.54, ws.z), (0.34, 0.24, 0.44), "weapon_socket.R", m_steel, bevel_amt=0.03)
    b.add_box((ws.x, ws.y - 0.54, ws.z), (0.36, 0.08, 0.16), "weapon_socket.R", m_cyan)

    b.build_skinned_object(arm_obj)
    author_shared_locomotion_clips(arm_obj)
    author_god_combat_clips(arm_obj, "endor")
    tris = count_scene_triangles()
    print(f"[Endor] Triangles: {tris}")
    render_side_profile_preview(arm_obj, os.path.join(OUT_PREV_DIR, "endor_profile.png"), STANCE_BASE)
    export_glb(os.path.join(OUT_CHAR_DIR, "endor.glb"))


def build_ir() -> None:
    reset_scene()
    arm_obj, coords = create_humanoid_24_armature("Ir", height_scale=1.0, width_scale=0.96)
    b = LowPolyPartBuilder("Ir")

    m_gold = make_palette_material("Ir_Gold", "#FFE066", metallic=0.65, roughness=0.28, emission_hex="#FFE066", emission_strength=1.1)
    m_white = make_palette_material("Ir_White", "#FFFFFF", metallic=0.12, roughness=0.45)
    m_blue = make_palette_material("Ir_Blue", "#2E5EAA", metallic=0.30, roughness=0.48)
    m_skin = make_palette_material("Ir_Skin", "#EBC19D", metallic=0.05, roughness=0.70)

    build_base_fighter_body(b, coords, m_white, m_blue, m_skin, m_gold, bulk=0.94)

    # Olympian Crest Plume & Laurel Visor
    hd = (coords["head"][0] + coords["head"][1]) * 0.5
    b.add_box((0.0, 0.02, hd.z + 0.13), (0.06, 0.30, 0.16), "head", m_gold, taper_top=1.2)
    b.add_box((0.0, -0.10, hd.z + 0.03), (0.20, 0.08, 0.06), "head", m_gold)
    # Pteruges waist sash
    hp = coords["hips"][0]
    b.add_box((0.0, 0.0, hp.z - 0.08), (0.34, 0.25, 0.18), "hips", m_blue, taper_top=0.85)

    # Twin Olympic Blades (weapon_socket.L & weapon_socket.R) + Aegis Cestus shields
    for side, sx in [("L", 1.0), ("R", -1.0)]:
        la = (coords[f"lower_arm.{side}"][0] + coords[f"lower_arm.{side}"][1]) * 0.5
        b.add_box((la.x + sx * 0.05, la.y, la.z), (0.04, 0.18, 0.22), f"lower_arm.{side}", m_gold)
        ws = coords[f"weapon_socket.{side}"][0]
        b.add_box((ws.x, ws.y - 0.03, ws.z), (0.12, 0.05, 0.05), f"weapon_socket.{side}", m_blue)
        b.add_blade_prism((ws.x, ws.y - 0.05, ws.z), (ws.x, ws.y - 0.72, ws.z), 0.09, 0.035, f"weapon_socket.{side}", m_gold)

    b.build_skinned_object(arm_obj)
    author_shared_locomotion_clips(arm_obj)
    author_god_combat_clips(arm_obj, "ir")
    tris = count_scene_triangles()
    print(f"[Ir] Triangles: {tris}")
    render_side_profile_preview(arm_obj, os.path.join(OUT_PREV_DIR, "ir_profile.png"), STANCE_BASE)
    export_glb(os.path.join(OUT_CHAR_DIR, "ir.glb"))


def build_osiris() -> None:
    reset_scene()
    arm_obj, coords = create_humanoid_24_armature("Osiris", height_scale=1.08, width_scale=1.02)
    b = LowPolyPartBuilder("Osiris")

    m_emerald = make_palette_material("Osiris_Emerald", "#2CE8A2", metallic=0.30, roughness=0.35, emission_hex="#2CE8A2", emission_strength=1.35)
    m_violet = make_palette_material("Osiris_Violet", "#6C3483", metallic=0.25, roughness=0.52)
    m_gold = make_palette_material("Osiris_Gold", "#D4AC0D", metallic=0.72, roughness=0.32)
    m_skin = make_palette_material("Osiris_Skin", "#237A68", metallic=0.10, roughness=0.65)

    build_base_fighter_body(b, coords, m_violet, m_gold, m_skin, m_emerald, bulk=1.0)

    # Tall Atef Crown + Broad Wesekh Collar + Shendyt Kilt
    hd = (coords["head"][0] + coords["head"][1]) * 0.5
    b.add_tapered_limb((0.0, 0.0, hd.z + 0.06), (0.0, 0.02, hd.z + 0.42), 0.11, 0.05, "head", m_gold, segments=7)
    b.add_blade_prism((0.10, 0.0, hd.z + 0.08), (0.16, 0.02, hd.z + 0.36), 0.06, 0.03, "head", m_emerald)
    b.add_blade_prism((-0.10, 0.0, hd.z + 0.08), (-0.16, 0.02, hd.z + 0.36), 0.06, 0.03, "head", m_emerald)
    ch = coords["chest"][1]
    b.add_tapered_limb((0.0, 0.0, ch.z - 0.05), (0.0, 0.0, ch.z + 0.02), 0.28, 0.16, "chest", m_gold, segments=8, scale_xy=(1.2, 0.9))
    hp = coords["hips"][0]
    b.add_tapered_limb((0.0, 0.0, hp.z + 0.02), (0.0, 0.0, hp.z - 0.24), 0.17, 0.24, "hips", m_violet, segments=8)

    # Spectral Crook in weapon_socket.R
    ws_r = coords["weapon_socket.R"][0]
    b.add_tapered_limb((ws_r.x, ws_r.y + 0.15, ws_r.z), (ws_r.x, ws_r.y - 0.58, ws_r.z), 0.024, 0.026, "weapon_socket.R", m_gold, segments=6)
    b.add_box((ws_r.x, ws_r.y - 0.65, ws_r.z + 0.08), (0.05, 0.18, 0.18), "weapon_socket.R", m_emerald, bevel_amt=0.01)
    b.add_box((ws_r.x, ws_r.y - 0.72, ws_r.z - 0.02), (0.05, 0.10, 0.12), "weapon_socket.R", m_emerald)

    # Spectral Flail in weapon_socket.L
    ws_l = coords["weapon_socket.L"][0]
    b.add_tapered_limb((ws_l.x, ws_l.y + 0.08, ws_l.z), (ws_l.x, ws_l.y - 0.36, ws_l.z), 0.024, 0.028, "weapon_socket.L", m_gold, segments=6)
    for dy, dz in [(-0.52, 0.09), (-0.55, 0.0), (-0.52, -0.09)]:
        b.add_blade_prism((ws_l.x, ws_l.y - 0.35, ws_l.z), (ws_l.x, ws_l.y + dy, ws_l.z + dz), 0.06, 0.05, "weapon_socket.L", m_emerald)

    b.build_skinned_object(arm_obj)
    author_shared_locomotion_clips(arm_obj)
    author_god_combat_clips(arm_obj, "osiris")
    tris = count_scene_triangles()
    print(f"[Osiris] Triangles: {tris}")
    render_side_profile_preview(arm_obj, os.path.join(OUT_PREV_DIR, "osiris_profile.png"), STANCE_BASE)
    export_glb(os.path.join(OUT_CHAR_DIR, "osiris.glb"))


def build_horus() -> None:
    reset_scene()
    arm_obj, coords = create_humanoid_24_armature("Horus", height_scale=1.03, width_scale=1.04)
    b = LowPolyPartBuilder("Horus")

    m_amber = make_palette_material("Horus_Amber", "#FF7A00", metallic=0.35, roughness=0.32, emission_hex="#FF7A00", emission_strength=1.35)
    m_gold = make_palette_material("Horus_Gold", "#FFD700", metallic=0.75, roughness=0.28)
    m_crimson = make_palette_material("Horus_Crimson", "#8E1600", metallic=0.28, roughness=0.50)
    m_skin = make_palette_material("Horus_Skin", "#A86438", metallic=0.08, roughness=0.65)

    build_base_fighter_body(b, coords, m_crimson, m_gold, m_skin, m_amber, bulk=0.98)

    # Falcon Beak Helm + Solar Disk Crown
    hd = (coords["head"][0] + coords["head"][1]) * 0.5
    b.add_blade_prism((0.0, -0.08, hd.z - 0.01), (0.0, -0.32, hd.z - 0.06), 0.13, 0.11, "head", m_gold)
    b.add_icosphere((0.0, 0.0, hd.z + 0.22), 0.11, "head", m_amber, subdivisions=1, scale=(1.0, 0.35, 1.0))

    # Winged Solar Crest on back_socket + Falcon Talons on feet
    bs = coords["back_socket"][0]
    for sx in (1.0, -1.0):
        b.add_blade_prism((sx * 0.08, bs.y, bs.z), (sx * 0.62, bs.y + 0.18, bs.z + 0.36), 0.22, 0.04, "back_socket", m_amber)
        b.add_blade_prism((sx * 0.10, bs.y, bs.z - 0.06), (sx * 0.48, bs.y + 0.16, bs.z + 0.10), 0.16, 0.035, "back_socket", m_gold)
    for side in ("L", "R"):
        to = coords[f"toe.{side}"][1]
        b.add_blade_prism((to.x, to.y + 0.04, to.z + 0.02), (to.x, to.y - 0.12, to.z), 0.06, 0.05, f"toe.{side}", m_gold)

    # Signature Weapon: Winged Solar Spear in weapon_socket.R
    ws = coords["weapon_socket.R"][0]
    b.add_tapered_limb((ws.x, ws.y + 0.42, ws.z), (ws.x, ws.y - 0.72, ws.z), 0.022, 0.024, "weapon_socket.R", m_gold, segments=6)
    b.add_blade_prism((ws.x, ws.y - 0.68, ws.z), (ws.x, ws.y - 1.08, ws.z), 0.11, 0.05, "weapon_socket.R", m_amber)
    b.add_blade_prism((ws.x, ws.y - 0.66, ws.z), (ws.x + 0.18, ws.y - 0.58, ws.z + 0.08), 0.08, 0.03, "weapon_socket.R", m_gold)
    b.add_blade_prism((ws.x, ws.y - 0.66, ws.z), (ws.x - 0.18, ws.y - 0.58, ws.z - 0.08), 0.08, 0.03, "weapon_socket.R", m_gold)

    b.build_skinned_object(arm_obj)
    author_shared_locomotion_clips(arm_obj)
    author_god_combat_clips(arm_obj, "horus")
    tris = count_scene_triangles()
    print(f"[Horus] Triangles: {tris}")
    render_side_profile_preview(arm_obj, os.path.join(OUT_PREV_DIR, "horus_profile.png"), STANCE_BASE)
    export_glb(os.path.join(OUT_CHAR_DIR, "horus.glb"))


def main() -> None:
    build_endor()
    build_ir()
    build_osiris()
    build_horus()
    print("Successfully generated all 4 playable mythic gods!")


if __name__ == "__main__":
    main()
