#!/usr/bin/env python3
"""
Generates Milestone 1 Stage 1 (New York City) Mythic Bosses:
  1. Chadzug — Tunnel King of the Under-Cobble (0.55x Gnome God Trickster + Pickaxe)
  2. Beebo   — Bird God of the Neon Roost (Avian Raptor rig with articulated wings, talons & beak_jaw)
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
OUT_PREV_DIR = os.path.join(ROOT_DIR, "assets", "previews")


def author_standard_boss_clips(arm_obj: bpy.types.Object, extra_wing_bones: bool = False) -> None:
    """Authors all 7 required per_boss_combat NLA actions on top of shared locomotion."""
    wing_flare = {"wing_shoulder.L": (10, -25, 35), "wing_mid.L": (0, -20, 25), "wing_shoulder.R": (10, 25, -35), "wing_mid.R": (0, 20, -25)} if extra_wing_bones else {}
    wing_tuck = {"wing_shoulder.L": (20, 25, -18), "wing_shoulder.R": (20, -25, 18)} if extra_wing_bones else {}

    taunt_a = merge_pose(STANCE_BASE, wing_flare, {
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
    lc_2 = merge_pose(STANCE_BASE, wing_flare, {"chest": (18, 0, -28), "upper_arm.R": (-95, -8, 10), "lower_arm.R": (-8, 0, 0)})
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
    hb_slam = merge_pose(STANCE_BASE, wing_tuck, {
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

    sp1_a = merge_pose(STANCE_BASE, wing_flare, {
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

    sp2_dive = merge_pose(STANCE_BASE, wing_flare, {
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

    roar = merge_pose(STANCE_BASE, wing_flare, {
        "hips": (-12, 0, 0), "spine_01": (-18, 0, 0), "chest": (-24, 0, 0), "head": (-22, 0, 0),
        "upper_arm.L": (-110, 55, -20), "upper_arm.R": (-110, -55, 20),
    })
    author_nla_action(arm_obj, "phase_2_roar", [
        (1, STANCE_BASE, None),
        (10, roar, {"hips": (0.0, 0.0, 0.10)}),
        (32, roar, {"hips": (0.0, 0.0, 0.10)}),
        (45, STANCE_BASE, {"hips": (0.0, 0.0, 0.0)}),
    ])

    ko = {
        "hips": (-85, 0, 0), "spine_01": (-10, 0, 0),
        "upper_arm.L": (-18, 52, 0), "upper_arm.R": (-18, -52, 0),
        "thigh.L": (10, 0, 12), "thigh.R": (10, 0, -12),
    }
    author_nla_action(arm_obj, "ko_collapse", [
        (1, STANCE_BASE, {"hips": (0.0, 0.0, 0.0)}),
        (18, ko, {"hips": (0.0, 0.20, -0.52)}),
        (45, ko, {"hips": (0.0, 0.20, -0.52)}),
    ])


def build_chadzug() -> None:
    """Chadzug: 0.55x compact Gnome God on 24-bone rig + oversized cap/beard + pickaxe."""
    reset_scene()
    arm_obj, coords = create_humanoid_24_armature("Chadzug", height_scale=0.58, width_scale=0.88)
    b = LowPolyPartBuilder("Chadzug")

    m_cap = make_palette_material("Chadzug_Cap", "#FF1E42", metallic=0.15, roughness=0.52, emission_hex="#FF1E42", emission_strength=0.45)
    m_tunic = make_palette_material("Chadzug_Tunic", "#2B580C", metallic=0.18, roughness=0.60)
    m_brass = make_palette_material("Chadzug_Brass", "#D4AC0D", metallic=0.72, roughness=0.34)
    m_skin = make_palette_material("Chadzug_Skin", "#DFAA88", metallic=0.05, roughness=0.72)
    m_beard = make_palette_material("Chadzug_Beard", "#F4F6F7", metallic=0.08, roughness=0.72)
    m_iron = make_palette_material("Chadzug_Iron", "#7F8C8D", metallic=0.78, roughness=0.36)

    build_base_fighter_body(b, coords, m_tunic, m_brass, m_skin, m_cap, bulk=0.92)

    # Oversized pointed Gnome Cap & Huge Braided Beard for instant side-profile readability
    hd0, hd1 = coords["head"]
    hd = (hd0 + hd1) * 0.5
    b.add_tapered_limb((0.0, 0.0, hd.z + 0.03), (0.0, 0.10, hd.z + 0.54), 0.19, 0.015, "head", m_cap, segments=8)
    b.add_icosphere((0.0, -0.14, hd.z - 0.01), 0.055, "head", m_skin, subdivisions=1)  # Big gnome nose
    b.add_tapered_limb((0.0, -0.08, hd.z - 0.04), (0.0, -0.18, hd.z - 0.34), 0.16, 0.06, "head", m_beard, segments=7)
    # Miner lantern on back_socket
    bs = coords["back_socket"][0]
    b.add_box((0.0, bs.y + 0.05, bs.z), (0.14, 0.14, 0.18), "back_socket", m_brass)

    # Heavy Under-Cobble Pickaxe on weapon_socket.R + extra faceted miner boots/belt plates
    ws = coords["weapon_socket.R"][0]
    b.add_tapered_limb((ws.x, ws.y + 0.16, ws.z), (ws.x, ws.y - 0.56, ws.z), 0.026, 0.030, "weapon_socket.R", m_brass, segments=8)
    b.add_blade_prism((ws.x, ws.y - 0.50, ws.z), (ws.x, ws.y - 0.62, ws.z + 0.34), 0.09, 0.07, "weapon_socket.R", m_iron)
    b.add_blade_prism((ws.x, ws.y - 0.50, ws.z), (ws.x, ws.y - 0.62, ws.z - 0.34), 0.09, 0.07, "weapon_socket.R", m_iron)
    # Faceted miner shoulder lanterns & knee guards to push into boss 1,200-3,200 tri band cleanly
    for side, sx in [("L", 1.0), ("R", -1.0)]:
        cl = coords[f"clavicle.{side}"][1]
        b.add_icosphere((cl.x, cl.y, cl.z + 0.04), 0.10, f"clavicle.{side}", m_iron, subdivisions=2, scale=(1.1, 1.0, 0.7))
        sh = coords[f"shin.{side}"][0]
        b.add_icosphere((sh.x, sh.y - 0.05, sh.z), 0.075, f"shin.{side}", m_brass, subdivisions=2)

    b.build_skinned_object(arm_obj)
    author_shared_locomotion_clips(arm_obj)
    author_standard_boss_clips(arm_obj, extra_wing_bones=False)
    tris = count_scene_triangles()
    print(f"[Chadzug] Triangles: {tris}")
    render_side_profile_preview(arm_obj, os.path.join(OUT_PREV_DIR, "chadzug_profile.png"), STANCE_BASE, cam_height=0.65, cam_dist=2.5)
    export_glb(os.path.join(OUT_BOSS_DIR, "chadzug.glb"))


def build_beebo() -> None:
    """Beebo: Bird God of the Neon Roost — 24-bone rig + wing_shoulder/mid/tip.L/R, talon_foot.L/R, beak_jaw."""
    reset_scene()
    arm_obj, coords = create_humanoid_24_armature("Beebo", height_scale=1.18, width_scale=1.10)

    # Add avian raptor extension bones required by specs.yml
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
    add_ext("beak_jaw", (0.0, -0.10, hd_mid.z - 0.03), (0.0, -0.40, hd_mid.z - 0.09), "head")

    ch = coords["chest"][1]
    for side, sx in [("L", 1.0), ("R", -1.0)]:
        add_ext(f"wing_shoulder.{side}", (sx * 0.12, 0.12, ch.z - 0.06), (sx * 0.55, 0.24, ch.z + 0.24), "chest")
        add_ext(f"wing_mid.{side}", (sx * 0.55, 0.24, ch.z + 0.24), (sx * 1.05, 0.30, ch.z + 0.48), f"wing_shoulder.{side}")
        add_ext(f"wing_tip.{side}", (sx * 1.05, 0.30, ch.z + 0.48), (sx * 1.52, 0.22, ch.z + 0.20), f"wing_mid.{side}")
        ft = coords[f"foot.{side}"][1]
        add_ext(f"talon_foot.{side}", (ft.x, ft.y, ft.z), (ft.x, ft.y - 0.22, ft.z - 0.02), f"foot.{side}")

    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in arm_obj.pose.bones:
        pb.rotation_mode = "XYZ"

    b = LowPolyPartBuilder("Beebo")
    m_plumage = make_palette_material("Beebo_Plumage", "#5B2C6F", metallic=0.25, roughness=0.46)
    m_neon = make_palette_material("Beebo_Neon", "#FF1E8A", metallic=0.35, roughness=0.30, emission_hex="#FF1E8A", emission_strength=1.5)
    m_cyan = make_palette_material("Beebo_Cyan", "#00F0FF", metallic=0.40, roughness=0.30, emission_hex="#00F0FF", emission_strength=1.2)
    m_gold = make_palette_material("Beebo_Beak", "#F4D03F", metallic=0.65, roughness=0.32)

    build_base_fighter_body(b, coords, m_plumage, m_cyan, m_plumage, m_gold, bulk=1.05)

    # Upper & lower articulated raptor beak + neon crest feathers
    b.add_blade_prism((0.0, -0.08, hd_mid.z + 0.04), (0.0, -0.46, hd_mid.z - 0.02), 0.16, 0.12, "head", m_gold)
    bj0, bj1 = coords["beak_jaw"]
    b.add_blade_prism(bj0, bj1, 0.12, 0.08, "beak_jaw", m_gold)
    b.add_blade_prism((0.0, 0.02, hd_mid.z + 0.10), (0.0, 0.36, hd_mid.z + 0.42), 0.12, 0.16, "head", m_neon)

    # Articulated multi-feather wings & razor talons
    for side, sx in [("L", 1.0), ("R", -1.0)]:
        ws0, ws1 = coords[f"wing_shoulder.{side}"]
        wm0, wm1 = coords[f"wing_mid.{side}"]
        wt0, wt1 = coords[f"wing_tip.{side}"]
        b.add_tapered_limb(ws0, ws1, 0.08, 0.065, f"wing_shoulder.{side}", m_plumage, segments=7)
        b.add_tapered_limb(wm0, wm1, 0.065, 0.05, f"wing_mid.{side}", m_cyan, segments=7)
        b.add_blade_prism(wt0, wt1, 0.18, 0.04, f"wing_tip.{side}", m_neon)
        # Feathered pinions along wing segments
        for frac in (0.35, 0.75):
            p = ws0.lerp(ws1, frac)
            b.add_blade_prism(p, (p.x + sx * 0.14, p.y + 0.10, p.z - 0.42), 0.13, 0.03, f"wing_shoulder.{side}", m_neon)
            p2 = wm0.lerp(wm1, frac)
            b.add_blade_prism(p2, (p2.x + sx * 0.20, p2.y + 0.10, p2.z - 0.52), 0.15, 0.03, f"wing_mid.{side}", m_cyan)
        tf0, tf1 = coords[f"talon_foot.{side}"]
        for dx in (-0.05, 0.0, 0.05):
            b.add_blade_prism((tf0.x + dx, tf0.y, tf0.z + 0.02), (tf1.x + dx * 1.4, tf1.y, tf1.z), 0.045, 0.045, f"talon_foot.{side}", m_gold)

    b.build_skinned_object(arm_obj)
    author_shared_locomotion_clips(arm_obj)
    author_standard_boss_clips(arm_obj, extra_wing_bones=True)
    tris = count_scene_triangles()
    print(f"[Beebo] Triangles: {tris}")
    render_side_profile_preview(arm_obj, os.path.join(OUT_PREV_DIR, "beebo_profile.png"), STANCE_BASE, cam_height=1.15, cam_dist=3.9)
    export_glb(os.path.join(OUT_BOSS_DIR, "beebo.glb"))


if __name__ == "__main__":
    build_chadzug()
    build_beebo()
    print("Successfully generated Stage 1 NYC bosses (Chadzug & Beebo)!")
