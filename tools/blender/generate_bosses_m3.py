#!/usr/bin/env python3
"""
Generates Milestone 3 (Stages 5-7: London, Tokyo, Rome) Mythic Bosses:
  1. Baba    — Crone of the Mortar & Pestle (London Mid-Boss)
  2. Devil   — Brimstone Brawler of the Thames (London Stage Boss, Infernal Triad #1)
  3. Satan   — High-Voltage Arch-Demon of Shibuya (Tokyo Stage Boss, Infernal Triad #2)
  4. Lucifer — Supreme Seraph of the Colosseum (Rome Final Boss, Infernal Triad #3)
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


def author_standard_boss_clips_m3(arm_obj: bpy.types.Object, has_wings: bool = False, has_tail: bool = False) -> None:
    wing_flare = {"wing_bat.L": (10, -25, 35), "wing_bat.R": (10, 25, -35)} if has_wings else {}
    wing_tuck = {"wing_bat.L": (20, 25, -18), "wing_bat.R": (20, -25, 18)} if has_wings else {}
    tail_whip = {"tail_02": (15, 0, 30), "tail_03": (-20, 0, 45)} if has_tail else {}

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
        "thigh.L": (40, 0, 0), "shin.L": (-55, 0, 0),
        "thigh.R": (40, 0, 0), "shin.R": (-55, 0, 0),
        "upper_arm.R": (-145, 0, 15), "upper_arm.L": (-145, 0, -15),
    })
    author_nla_action(arm_obj, "signature_special_2", [
        (1, STANCE_BASE, None),
        (12, sp2_dive, {"hips": (0.0, 0.25, 0.40)}),
        (22, sp2_dive, {"hips": (0.0, -0.30, 0.0)}),
        (32, hb_slam, {"hips": (0.0, -0.30, -0.10)}),
        (44, STANCE_BASE, {"hips": (0.0, 0.0, 0.0)}),
    ])

    roar_pose = merge_pose(STANCE_BASE, wing_flare, {
        "hips": (-10, 0, 0), "spine_01": (-20, 0, 0), "chest": (-25, 0, 0), "head": (-30, 0, 0),
        "upper_arm.L": (-140, 35, -25), "upper_arm.R": (-140, -35, 25),
    })
    author_nla_action(arm_obj, "phase_2_roar", [
        (1, STANCE_BASE, None),
        (10, roar_pose, {"hips": (0.0, 0.0, 0.05)}),
        (30, roar_pose, {"hips": (0.0, 0.0, 0.05)}),
        (45, STANCE_BASE, {"hips": (0.0, 0.0, 0.0)}),
    ])

    ko_fall = merge_pose(STANCE_BASE, {"hips": (-45, 0, 0), "chest": (-35, 0, 0), "head": (-20, 0, 0)})
    ko_ground = merge_pose(STANCE_BASE, {"hips": (-88, 0, 0), "chest": (-88, 0, 0), "head": (-85, 0, 0)})
    author_nla_action(arm_obj, "ko_collapse", [
        (1, STANCE_BASE, None),
        (15, ko_fall, {"hips": (0.0, 0.15, -0.35)}),
        (28, ko_ground, {"hips": (0.0, 0.35, -0.75)}),
        (60, ko_ground, {"hips": (0.0, 0.35, -0.75)}),
    ])

    hl = merge_pose(STANCE_BASE, {"chest": (-18, 0, 0), "head": (-15, 0, 0)})
    author_nla_action(arm_obj, "hit_light", [
        (1, STANCE_BASE, None),
        (5, hl, {"hips": (0.0, 0.08, 0.0)}),
        (14, STANCE_BASE, {"hips": (0.0, 0.0, 0.0)}),
    ])

    arc_up = merge_pose(STANCE_BASE, {"hips": (45, 0, 0), "chest": (35, 0, 0), "head": (25, 0, 0)})
    author_nla_action(arm_obj, "hit_launch_arc", [
        (1, STANCE_BASE, None),
        (12, arc_up, {"hips": (0.0, 0.20, 0.30)}),
        (26, ko_ground, {"hips": (0.0, 0.30, -0.70)}),
    ])


def build_baba() -> None:
    """Baba: Crone God of the Pestle & Chicken-Hut (London Mid-Boss)."""
    reset_scene()
    arm_obj, coords = create_humanoid_24_armature("Baba", height_scale=0.88, width_scale=0.92)

    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_obj.data.edit_bones

    # Mortar bowl base bone parented to hips
    hp = coords["hips"][0]
    mb = eb.new("mortar_base")
    mb.head = Vector((0.0, 0.0, hp.z * 0.5))
    mb.tail = Vector((0.0, 0.0, 0.05))
    mb.parent = eb["hips"]
    coords["mortar_base"] = (mb.head.copy(), mb.tail.copy())

    # Curved Pestle staff in right hand
    hr = coords["hand.R"][1]
    ps = eb.new("pestle_staff")
    ps.head = Vector((hr.x, hr.y - 0.25, hr.z + 0.55))
    ps.tail = Vector((hr.x, hr.y + 0.15, hr.z - 0.45))
    ps.parent = eb["hand.R"]
    coords["pestle_staff"] = (ps.head.copy(), ps.tail.copy())

    # Chicken claw spurs on feet
    for side, sx in [("L", 1.0), ("R", -1.0)]:
        ft = coords[f"foot.{side}"][1]
        cl = eb.new(f"claw_toe.{side}")
        cl.head = Vector((ft.x, ft.y, ft.z))
        cl.tail = Vector((ft.x + sx * 0.08, ft.y - 0.20, ft.z - 0.05))
        cl.parent = eb[f"foot.{side}"]
        coords[f"claw_toe.{side}"] = (cl.head.copy(), cl.tail.copy())

    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in arm_obj.pose.bones:
        pb.rotation_mode = "XYZ"

    b = LowPolyPartBuilder("Baba")
    m_robe = make_palette_material("Baba_Robe", "#273746", metallic=0.15, roughness=0.75)
    m_shawl = make_palette_material("Baba_Shawl", "#1E8449", metallic=0.10, roughness=0.80)
    m_skin = make_palette_material("Baba_Skin", "#D5D8DC", metallic=0.05, roughness=0.60)
    m_wood = make_palette_material("Baba_Wood", "#5D4037", metallic=0.25, roughness=0.55)
    m_amber = make_palette_material("Baba_Amber", "#F39C12", metallic=0.30, roughness=0.30, emission_hex="#F39C12", emission_strength=1.6)

    build_base_fighter_body(b, coords, m_robe, m_shawl, m_skin, m_amber, bulk=0.88)

    # Draped crone shawl & hood on head
    hd_mid = (coords["head"][0] + coords["head"][1]) * 0.5
    b.add_box((0.0, 0.05, hd_mid.z + 0.08), (0.28, 0.32, 0.26), "head", m_shawl, bevel_amt=0.03)
    b.add_icosphere((0.0, -0.16, hd_mid.z - 0.02), 0.06, "head", m_amber, subdivisions=1) # Hook nose / eye glow

    # Large carved wooden mortar cauldron encircling lower body
    m0, m1 = coords["mortar_base"]
    b.add_tapered_limb(m0, m1, 0.40, 0.32, "mortar_base", m_wood, segments=10)

    # Heavy wooden pestle club
    p0, p1 = coords["pestle_staff"]
    b.add_tapered_limb(p0, p1, 0.065, 0.055, "pestle_staff", m_wood, segments=8)
    b.add_box((p0.x, p0.y, p0.z - 0.1), (0.20, 0.20, 0.28), "pestle_staff", m_amber, bevel_amt=0.02) # Pestle hammer head

    # Chicken claw spurs
    for side, _sx in [("L", 1.0), ("R", -1.0)]:
        c0, c1 = coords[f"claw_toe.{side}"]
        b.add_blade_prism(c0, c1, 0.12, 0.04, f"claw_toe.{side}", m_amber)

    b.build_skinned_object(arm_obj)
    author_shared_locomotion_clips(arm_obj)
    author_standard_boss_clips_m3(arm_obj)
    tris = count_scene_triangles()
    print(f"[Baba] Triangles: {tris}")
    render_side_profile_preview(arm_obj, os.path.join(OUT_PREV_DIR, "baba_profile.png"), STANCE_BASE, cam_height=1.05, cam_dist=3.6)
    export_glb(os.path.join(OUT_BOSS_DIR, "baba.glb"))


def build_devil() -> None:
    """Devil: Lord of the Brimstone Thames (London Stage Boss, Infernal Triad #1)."""
    reset_scene()
    arm_obj, coords = create_humanoid_24_armature("Devil", height_scale=1.24, width_scale=1.20)

    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_obj.data.edit_bones

    # Curved demon horns on head
    head = coords["head"][0]
    for side, sx in [("L", 1.0), ("R", -1.0)]:
        hn = eb.new(f"horn.{side}")
        hn.head = Vector((sx * 0.12, -0.06, head.z + 0.16))
        hn.tail = Vector((sx * 0.38, 0.14, head.z + 0.44))
        hn.parent = eb["head"]
        coords[f"horn.{side}"] = (hn.head.copy(), hn.tail.copy())

    # Leathery bat wings on chest
    ch = coords["chest"][1]
    for side, sx in [("L", 1.0), ("R", -1.0)]:
        w = eb.new(f"wing_bat.{side}")
        w.head = Vector((sx * 0.14, 0.12, ch.z + 0.05))
        w.tail = Vector((sx * 0.95, 0.32, ch.z + 0.58))
        w.parent = eb["chest"]
        coords[f"wing_bat.{side}"] = (w.head.copy(), w.tail.copy())

    # 3-segment barbed devil tail
    tail_parent = eb["hips"]
    prev_pos = Vector((0.0, 0.12, coords["hips"][0].z))
    for i in range(1, 4):
        tname = f"tail_{i:02d}"
        bn = eb.new(tname)
        next_pos = Vector((0.0, 0.22 + float(i) * 0.22, prev_pos.z - 0.15 + float(i) * 0.06))
        bn.head = prev_pos
        bn.tail = next_pos
        bn.parent = tail_parent
        coords[tname] = (bn.head.copy(), bn.tail.copy())
        tail_parent = bn
        prev_pos = next_pos

    # Three-pronged pitchfork in right weapon socket
    wr = coords["weapon_socket.R"][1]
    pf = eb.new("pitchfork")
    pf.head = Vector((wr.x, wr.y - 0.35, wr.z + 0.70))
    pf.tail = Vector((wr.x, wr.y + 0.25, wr.z - 0.50))
    pf.parent = eb["weapon_socket.R"]
    coords["pitchfork"] = (pf.head.copy(), pf.tail.copy())

    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in arm_obj.pose.bones:
        pb.rotation_mode = "XYZ"

    b = LowPolyPartBuilder("Devil")
    m_skin = make_palette_material("Devil_Skin", "#922B21", metallic=0.35, roughness=0.55)
    m_armor = make_palette_material("Devil_Armor", "#17202A", metallic=0.75, roughness=0.30)
    m_wing = make_palette_material("Devil_Wing", "#5B140E", metallic=0.20, roughness=0.65)
    m_gold = make_palette_material("Devil_Gold", "#F1C40F", metallic=0.85, roughness=0.25, emission_hex="#F1C40F", emission_strength=1.4)

    build_base_fighter_body(b, coords, m_skin, m_armor, m_skin, m_gold, bulk=1.18)

    # Horns & brow
    for side, _sx in [("L", 1.0), ("R", -1.0)]:
        h0, h1 = coords[f"horn.{side}"]
        b.add_blade_prism(h0, h1, 0.14, 0.08, f"horn.{side}", m_armor)
        # Bat wings
        w0, w1 = coords[f"wing_bat.{side}"]
        b.add_blade_prism(w0, w1, 0.34, 0.03, f"wing_bat.{side}", m_wing)

    # Barbed tail chain
    for i in range(1, 4):
        tname = f"tail_{i:02d}"
        t0, t1 = coords[tname]
        b.add_tapered_limb(t0, t1, 0.06 - float(i) * 0.012, 0.045 - float(i) * 0.012, tname, m_skin, segments=6)
    # Spade arrowhead tip on tail_03
    t3_tail = coords["tail_03"][1]
    b.add_box((t3_tail.x, t3_tail.y + 0.08, t3_tail.z), (0.16, 0.16, 0.04), "tail_03", m_armor, bevel_amt=0.02)

    # Golden 3-pronged pitchfork
    p0, p1 = coords["pitchfork"]
    b.add_tapered_limb(p0, p1, 0.045, 0.045, "pitchfork", m_gold, segments=6)
    b.add_box((p0.x, p0.y, p0.z), (0.26, 0.04, 0.06), "pitchfork", m_gold)
    b.add_blade_prism((p0.x - 0.10, p0.y, p0.z), (p0.x - 0.10, p0.y - 0.24, p0.z + 0.18), 0.06, 0.03, "pitchfork", m_gold)
    b.add_blade_prism((p0.x, p0.y, p0.z), (p0.x, p0.y - 0.28, p0.z + 0.22), 0.07, 0.035, "pitchfork", m_gold)
    b.add_blade_prism((p0.x + 0.10, p0.y, p0.z), (p0.x + 0.10, p0.y - 0.24, p0.z + 0.18), 0.06, 0.03, "pitchfork", m_gold)

    b.build_skinned_object(arm_obj)
    author_shared_locomotion_clips(arm_obj)
    author_standard_boss_clips_m3(arm_obj, has_wings=True, has_tail=True)
    tris = count_scene_triangles()
    print(f"[Devil] Triangles: {tris}")
    render_side_profile_preview(arm_obj, os.path.join(OUT_PREV_DIR, "devil_profile.png"), STANCE_BASE, cam_height=1.2, cam_dist=4.0)
    export_glb(os.path.join(OUT_BOSS_DIR, "devil.glb"))


def build_satan() -> None:
    """Satan: High-Voltage Arch-Demon of Shibuya (Tokyo Stage Boss, Infernal Triad #2)."""
    reset_scene()
    arm_obj, coords = create_humanoid_24_armature("Satan", height_scale=1.36, width_scale=1.16)

    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_obj.data.edit_bones

    # Jagged lightning horns on head
    head = coords["head"][0]
    for side, sx in [("L", 1.0), ("R", -1.0)]:
        jh = eb.new(f"horn_jagged.{side}")
        jh.head = Vector((sx * 0.14, -0.08, head.z + 0.18))
        jh.tail = Vector((sx * 0.42, 0.18, head.z + 0.52))
        jh.parent = eb["head"]
        coords[f"horn_jagged.{side}"] = (jh.head.copy(), jh.tail.copy())

        # Electric plasma claws on hands
        hn = coords[f"hand.{side}"][1]
        pc = eb.new(f"plasma_claw.{side}")
        pc.head = Vector((hn.x, hn.y, hn.z))
        pc.tail = Vector((hn.x + sx * 0.18, hn.y - 0.32, hn.z - 0.08))
        pc.parent = eb[f"hand.{side}"]
        coords[f"plasma_claw.{side}"] = (pc.head.copy(), pc.tail.copy())

    # High-voltage dorsal spine conduct fins on chest
    ch = coords["chest"][1]
    df1 = eb.new("dorsal_fin.01")
    df1.head = Vector((0.0, 0.12, ch.z + 0.05))
    df1.tail = Vector((0.0, 0.45, ch.z + 0.22))
    df1.parent = eb["chest"]
    coords["dorsal_fin.01"] = (df1.head.copy(), df1.tail.copy())

    df2 = eb.new("dorsal_fin.02")
    df2.head = Vector((0.0, 0.14, ch.z - 0.16))
    df2.tail = Vector((0.0, 0.42, ch.z - 0.05))
    df2.parent = eb["chest"]
    coords["dorsal_fin.02"] = (df2.head.copy(), df2.tail.copy())

    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in arm_obj.pose.bones:
        pb.rotation_mode = "XYZ"

    b = LowPolyPartBuilder("Satan")
    m_body = make_palette_material("Satan_Body", "#0B0C10", metallic=0.60, roughness=0.35)
    m_chassis = make_palette_material("Satan_Chassis", "#1F2833", metallic=0.75, roughness=0.25)
    m_cyan = make_palette_material("Satan_Plasma", "#66FCF1", metallic=0.40, roughness=0.20, emission_hex="#66FCF1", emission_strength=2.2)
    m_crimson = make_palette_material("Satan_Crimson", "#C70039", metallic=0.50, roughness=0.40, emission_hex="#C70039", emission_strength=1.5)

    build_base_fighter_body(b, coords, m_body, m_chassis, m_body, m_crimson, bulk=1.14)

    # Jagged lightning horns
    for side, _sx in [("L", 1.0), ("R", -1.0)]:
        j0, j1 = coords[f"horn_jagged.{side}"]
        b.add_blade_prism(j0, j1, 0.15, 0.07, f"horn_jagged.{side}", m_cyan)
        # Dual plasma energy blades on hands
        c0, c1 = coords[f"plasma_claw.{side}"]
        b.add_blade_prism(c0, c1, 0.18, 0.03, f"plasma_claw.{side}", m_cyan)

    # Dorsal electric conductor fins
    for df_name in ["dorsal_fin.01", "dorsal_fin.02"]:
        d0, d1 = coords[df_name]
        b.add_blade_prism(d0, d1, 0.24, 0.04, df_name, m_cyan)

    # Angular shoulder coils
    for side, sx in [("L", 1.0), ("R", -1.0)]:
        cl = coords[f"clavicle.{side}"][1]
        b.add_box((cl.x + sx * 0.06, cl.y, cl.z + 0.08), (0.24, 0.30, 0.18), f"clavicle.{side}", m_chassis, bevel_amt=0.03)

    b.build_skinned_object(arm_obj)
    author_shared_locomotion_clips(arm_obj)
    author_standard_boss_clips_m3(arm_obj)
    tris = count_scene_triangles()
    print(f"[Satan] Triangles: {tris}")
    render_side_profile_preview(arm_obj, os.path.join(OUT_PREV_DIR, "satan_profile.png"), STANCE_BASE, cam_height=1.25, cam_dist=4.1)
    export_glb(os.path.join(OUT_BOSS_DIR, "satan.glb"))


def build_lucifer() -> None:
    """Lucifer: Supreme Seraph of the Colosseum (Rome Final Boss, Infernal Triad #3)."""
    reset_scene()
    arm_obj, coords = create_humanoid_24_armature("Lucifer", height_scale=1.30, width_scale=1.10)

    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_obj.data.edit_bones

    # Floating radiant halo above head
    hd = coords["head"][0]
    hl = eb.new("halo")
    hl.head = Vector((0.0, 0.0, hd.z + 0.28))
    hl.tail = Vector((0.0, 0.0, hd.z + 0.42))
    hl.parent = eb["head"]
    coords["halo"] = (hl.head.copy(), hl.tail.copy())

    # 6 Seraphic Wings on chest (Upper, Mid, Lower pairs)
    ch = coords["chest"][1]
    wing_configs = [
        ("seraph_upper", 0.10, 0.95, 0.58),
        ("seraph_mid",   0.14, 0.85, 0.18),
        ("seraph_lower", 0.12, 0.70, -0.22),
    ]
    for w_base, z_off, span_x, span_z in wing_configs:
        for side, sx in [("L", 1.0), ("R", -1.0)]:
            wname = f"{w_base}.{side}"
            bn = eb.new(wname)
            bn.head = Vector((sx * 0.10, 0.12, ch.z + z_off))
            bn.tail = Vector((sx * span_x, 0.25, ch.z + span_z))
            bn.parent = eb["chest"]
            coords[wname] = (bn.head.copy(), bn.tail.copy())

    # Celestial rapier in right weapon socket
    wr = coords["weapon_socket.R"][1]
    sb = eb.new("celestial_blade")
    sb.head = Vector((wr.x, wr.y - 0.15, wr.z + 0.35))
    sb.tail = Vector((wr.x, wr.y - 0.90, wr.z - 0.25))
    sb.parent = eb["weapon_socket.R"]
    coords["celestial_blade"] = (sb.head.copy(), sb.tail.copy())

    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in arm_obj.pose.bones:
        pb.rotation_mode = "XYZ"

    b = LowPolyPartBuilder("Lucifer")
    m_marble = make_palette_material("Lucif_Marble", "#FDFEFE", metallic=0.25, roughness=0.35)
    m_gold = make_palette_material("Lucif_Gold", "#F4D03F", metallic=0.85, roughness=0.20, emission_hex="#F4D03F", emission_strength=1.8)
    m_crimson = make_palette_material("Lucif_Crimson", "#78281F", metallic=0.40, roughness=0.45)
    m_wing = make_palette_material("Lucif_Wing", "#E5E8E8", metallic=0.15, roughness=0.40)
    m_azure = make_palette_material("Lucif_Azure", "#00D4FF", metallic=0.30, roughness=0.20, emission_hex="#00D4FF", emission_strength=2.0)

    build_base_fighter_body(b, coords, m_marble, m_gold, m_marble, m_azure, bulk=1.08)

    # Floating golden halo ring
    h_mid = (coords["halo"][0] + coords["halo"][1]) * 0.5
    b.add_icosphere(h_mid, 0.28, "halo", m_gold, subdivisions=2, scale=(1.0, 1.0, 0.15))

    # 6 Seraphic feathered wings
    for w_base, _, _, _ in wing_configs:
        for side, _sx in [("L", 1.0), ("R", -1.0)]:
            wname = f"{w_base}.{side}"
            w0, w1 = coords[wname]
            b.add_blade_prism(w0, w1, 0.26, 0.03, wname, m_wing)

    # Imperial golden cuirass & pauldrons
    for side, sx in [("L", 1.0), ("R", -1.0)]:
        cl = coords[f"clavicle.{side}"][1]
        b.add_box((cl.x + sx * 0.05, cl.y, cl.z + 0.06), (0.22, 0.28, 0.16), f"clavicle.{side}", m_gold, bevel_amt=0.02)

    # Celestial rapier blade
    s0, s1 = coords["celestial_blade"]
    b.add_tapered_limb(s0, s1, 0.038, 0.018, "celestial_blade", m_azure, segments=6)
    b.add_box(s0, (0.18, 0.18, 0.08), "celestial_blade", m_gold) # Guard

    b.build_skinned_object(arm_obj)
    author_shared_locomotion_clips(arm_obj)
    author_standard_boss_clips_m3(arm_obj, has_wings=True)
    tris = count_scene_triangles()
    print(f"[Lucifer] Triangles: {tris}")
    render_side_profile_preview(arm_obj, os.path.join(OUT_PREV_DIR, "lucifer_profile.png"), STANCE_BASE, cam_height=1.2, cam_dist=4.0)
    export_glb(os.path.join(OUT_BOSS_DIR, "lucifer.glb"))


def main() -> None:
    os.makedirs(OUT_BOSS_DIR, exist_ok=True)
    os.makedirs(OUT_PREV_DIR, exist_ok=True)
    print("=== Generating Milestone 3 Mythic Bosses (London, Tokyo, Rome) ===")
    build_baba()
    build_devil()
    build_satan()
    build_lucifer()
    print("=== Milestone 3 Boss Generation Complete! ===")


if __name__ == "__main__":
    main()
