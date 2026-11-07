#!/usr/bin/env python3
"""
Generates the lean shared Wave Enemy rigged .glb (res://assets/enemies/enemy_base.glb)
scaled and recolored at runtime for Street Thugs, Bruisers/Enforcers, and Cult Elites.
"""
import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

import bpy
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
OUT_ENEMY_DIR = os.path.join(ROOT_DIR, "assets", "enemies")
OUT_PREV_DIR = os.path.join(ROOT_DIR, "assets", "previews")


def build_enemy_base() -> None:
    reset_scene()
    arm_obj, coords = create_humanoid_24_armature("EnemyBase", height_scale=1.0, width_scale=1.04)
    b = LowPolyPartBuilder("EnemyBase")

    # Neutral high-contrast slots so Godot surface material overrides tint Jacket / Pants / Visor cleanly
    m_jacket = make_palette_material("Enemy_Jacket", "#D0D7DE", metallic=0.15, roughness=0.60)
    m_pants = make_palette_material("Enemy_Pants", "#4A5568", metallic=0.10, roughness=0.68)
    m_skin = make_palette_material("Enemy_Skin", "#D8A886", metallic=0.05, roughness=0.72)
    m_visor = make_palette_material("Enemy_Accent", "#FF1E42", metallic=0.35, roughness=0.35, emission_hex="#FF1E42", emission_strength=1.2)

    build_base_fighter_body(b, coords, m_jacket, m_pants, m_skin, m_visor, bulk=1.04)

    # Street-punk mohawk crest + glowing threat visor + spiked shoulder/knuckle brawler silhouette
    hd = (coords["head"][0] + coords["head"][1]) * 0.5
    b.add_box((0.0, -0.11, hd.z + 0.02), (0.20, 0.07, 0.055), "head", m_visor)
    b.add_box((0.0, 0.02, hd.z + 0.13), (0.055, 0.24, 0.11), "head", m_visor, taper_top=0.75)

    for side, sx in [("L", 1.0), ("R", -1.0)]:
        cl = coords[f"clavicle.{side}"][1]
        b.add_blade_prism((cl.x, cl.y, cl.z + 0.04), (cl.x + sx * 0.12, cl.y, cl.z + 0.16), 0.08, 0.08, f"clavicle.{side}", m_jacket)

    # Compact street baton / knuckle bar on weapon_socket.R
    ws = coords["weapon_socket.R"][0]
    b.add_tapered_limb((ws.x, ws.y + 0.06, ws.z), (ws.x, ws.y - 0.38, ws.z), 0.026, 0.032, "weapon_socket.R", m_visor, segments=6)

    b.build_skinned_object(arm_obj)
    author_shared_locomotion_clips(arm_obj)

    # Enemy combat clips: light_1, light_2, heavy_ground, ranged_cast, ko_collapse
    l1 = merge_pose(STANCE_BASE, {"chest": (12, 0, 20), "upper_arm.L": (-88, 6, 0), "lower_arm.L": (-8, 0, 0)})
    author_nla_action(arm_obj, "light_1", [
        (1, STANCE_BASE, None),
        (6, l1, {"hips": (0.0, -0.06, 0.0)}),
        (12, l1, {"hips": (0.0, -0.06, 0.0)}),
        (20, STANCE_BASE, {"hips": (0.0, 0.0, 0.0)}),
    ])

    l2 = merge_pose(STANCE_BASE, {"chest": (16, 0, -24), "upper_arm.R": (-92, -6, -12), "lower_arm.R": (-10, 0, 0)})
    author_nla_action(arm_obj, "light_2", [
        (1, STANCE_BASE, None),
        (7, l2, {"hips": (0.0, -0.10, 0.0)}),
        (14, l2, {"hips": (0.0, -0.10, 0.0)}),
        (24, STANCE_BASE, {"hips": (0.0, 0.0, 0.0)}),
    ])

    hv_wind = merge_pose(STANCE_BASE, {"chest": (-16, 0, 14), "upper_arm.R": (-150, -18, 12)})
    hv_hit = merge_pose(STANCE_BASE, {"hips": (20, 0, -18), "chest": (24, 0, -20), "upper_arm.R": (-42, -8, -10), "lower_arm.R": (-10, 0, 0)})
    author_nla_action(arm_obj, "heavy_ground", [
        (1, hv_wind, {"hips": (0.0, 0.05, 0.03)}),
        (12, hv_hit, {"hips": (0.0, -0.20, -0.08)}),
        (22, hv_hit, {"hips": (0.0, -0.20, -0.08)}),
        (36, STANCE_BASE, {"hips": (0.0, 0.0, 0.0)}),
    ])

    cast_pose = merge_pose(STANCE_BASE, {
        "chest": (10, 0, 0),
        "upper_arm.L": (-88, 18, -10), "lower_arm.L": (-10, 0, 0),
        "upper_arm.R": (-88, -18, 10), "lower_arm.R": (-10, 0, 0),
    })
    author_nla_action(arm_obj, "ranged_cast", [
        (1, STANCE_BASE, None),
        (10, cast_pose, None),
        (22, cast_pose, None),
        (32, STANCE_BASE, None),
    ])

    ko_pose = {
        "hips": (-86, 0, 8), "spine_01": (-8, 0, 0),
        "upper_arm.L": (-15, 55, 0), "upper_arm.R": (-15, -55, 0),
        "thigh.L": (6, 0, 10), "thigh.R": (6, 0, -10),
    }
    author_nla_action(arm_obj, "ko_collapse", [
        (1, STANCE_BASE, {"hips": (0.0, 0.0, 0.0)}),
        (14, ko_pose, {"hips": (0.0, -0.76, 0.18)}),
        (36, ko_pose, {"hips": (0.0, -0.76, 0.18)}),
    ])

    tris = count_scene_triangles()
    print(f"[EnemyBase] Triangles: {tris}")
    render_side_profile_preview(arm_obj, os.path.join(OUT_PREV_DIR, "enemy_base_profile.png"), STANCE_BASE)
    export_glb(os.path.join(OUT_ENEMY_DIR, "enemy_base.glb"))


if __name__ == "__main__":
    build_enemy_base()
