"""
Shared Blender 5.2 Low-Poly Arcade Rigging, Mesh Construction, Animation & GLB Export Library.
Implements the Virtua Fighter / Tekken 2-3 faceted low-poly standard from specs.yml.
"""
import math
import os
import bmesh
import bpy
from mathutils import Euler, Matrix, Vector


def reset_scene(fps: int = 60) -> bpy.types.Scene:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.fps = fps
    scene.frame_start = 1
    scene.frame_end = 60
    return scene


def hex_to_rgba(hex_str: str, alpha: float = 1.0) -> tuple[float, float, float, float]:
    h = hex_str.lstrip("#")
    r = int(h[0:2], 16) / 255.0
    g = int(h[2:4], 16) / 255.0
    b = int(h[4:6], 16) / 255.0
    # sRGB to linear approximation for Blender Principled BSDF
    def to_lin(c: float) -> float:
        return ((c + 0.055) / 1.055) ** 2.4 if c > 0.04045 else c / 12.92
    return (to_lin(r), to_lin(g), to_lin(b), alpha)


def make_palette_material(
    name: str,
    hex_color: str,
    metallic: float = 0.15,
    roughness: float = 0.58,
    emission_hex: str | None = None,
    emission_strength: float = 0.0,
) -> bpy.types.Material:
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = hex_to_rgba(hex_color)
        bsdf.inputs["Metallic"].default_value = metallic
        bsdf.inputs["Roughness"].default_value = roughness
        if emission_hex and emission_strength > 0.0:
            if "Emission Color" in bsdf.inputs:
                bsdf.inputs["Emission Color"].default_value = hex_to_rgba(emission_hex)
                bsdf.inputs["Emission Strength"].default_value = emission_strength
    return mat


class LowPolyPartBuilder:
    """Builds faceted low-poly parts directly in armature space with bone vertex weights and material indices."""

    def __init__(self, name: str):
        self.name = name
        self.materials: list[bpy.types.Material] = []
        self.mat_map: dict[str, int] = {}
        self.parts: list[tuple[bmesh.types.BMesh, str, int]] = []

    def add_material(self, mat: bpy.types.Material) -> int:
        if mat.name in self.mat_map:
            return self.mat_map[mat.name]
        idx = len(self.materials)
        self.materials.append(mat)
        self.mat_map[mat.name] = idx
        return idx

    def add_tapered_limb(
        self,
        p0: tuple[float, float, float],
        p1: tuple[float, float, float],
        r0: float,
        r1: float,
        bone_name: str,
        mat: bpy.types.Material,
        segments: int = 8,
        scale_xy: tuple[float, float] = (1.0, 1.0),
    ) -> None:
        bm = bmesh.new()
        v0 = Vector(p0)
        v1 = Vector(p1)
        vec = v1 - v0
        length = max(vec.length, 0.001)
        bmesh.ops.create_cone(
            bm,
            cap_ends=True,
            cap_tris=True,
            segments=segments,
            radius1=r0,
            radius2=r1,
            depth=length,
        )
        for v in bm.verts:
            v.co.x *= scale_xy[0]
            v.co.y *= scale_xy[1]
        mid = (v0 + v1) * 0.5
        rot = Vector((0.0, 0.0, 1.0)).rotation_difference(vec.normalized()).to_matrix().to_4x4()
        xform = Matrix.Translation(mid) @ rot
        bmesh.ops.transform(bm, matrix=xform, verts=bm.verts)
        self._push_bm(bm, bone_name, mat)

    def add_box(
        self,
        center: tuple[float, float, float],
        size: tuple[float, float, float],
        bone_name: str,
        mat: bpy.types.Material,
        rot_deg: tuple[float, float, float] = (0.0, 0.0, 0.0),
        taper_top: float = 1.0,
        bevel_amt: float = 0.0,
    ) -> None:
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            if v.co.z > 0.0:
                v.co.x *= taper_top
                v.co.y *= taper_top
            v.co.x *= size[0]
            v.co.y *= size[1]
            v.co.z *= size[2]
        if bevel_amt > 0.0:
            geom = list(bm.verts) + list(bm.edges)
            bmesh.ops.bevel(bm, geom=geom, offset=bevel_amt, segments=1, affect="EDGES")
        eul = Euler([math.radians(a) for a in rot_deg], "XYZ")
        xform = Matrix.Translation(Vector(center)) @ eul.to_matrix().to_4x4()
        bmesh.ops.transform(bm, matrix=xform, verts=bm.verts)
        self._push_bm(bm, bone_name, mat)

    def add_icosphere(
        self,
        center: tuple[float, float, float],
        radius: float,
        bone_name: str,
        mat: bpy.types.Material,
        subdivisions: int = 1,
        scale: tuple[float, float, float] = (1.0, 1.0, 1.0),
        rot_deg: tuple[float, float, float] = (0.0, 0.0, 0.0),
    ) -> None:
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=subdivisions, radius=radius)
        for v in bm.verts:
            v.co.x *= scale[0]
            v.co.y *= scale[1]
            v.co.z *= scale[2]
        eul = Euler([math.radians(a) for a in rot_deg], "XYZ")
        xform = Matrix.Translation(Vector(center)) @ eul.to_matrix().to_4x4()
        bmesh.ops.transform(bm, matrix=xform, verts=bm.verts)
        self._push_bm(bm, bone_name, mat)

    def add_blade_prism(
        self,
        base_pos: tuple[float, float, float],
        tip_pos: tuple[float, float, float],
        width: float,
        thickness: float,
        bone_name: str,
        mat: bpy.types.Material,
    ) -> None:
        """Sharp 4-sided diamond cross-section low-poly blade/spear/horn."""
        bm = bmesh.new()
        v0 = Vector(base_pos)
        v1 = Vector(tip_pos)
        axis = v1 - v0
        length = max(axis.length, 0.01)
        # Build along +Z from 0 to length
        ring0 = [
            bm.verts.new((width * 0.5, 0.0, 0.0)),
            bm.verts.new((0.0, thickness * 0.5, 0.0)),
            bm.verts.new((-width * 0.5, 0.0, 0.0)),
            bm.verts.new((0.0, -thickness * 0.5, 0.0)),
        ]
        ring1 = [
            bm.verts.new((width * 0.36, 0.0, length * 0.72)),
            bm.verts.new((0.0, thickness * 0.36, length * 0.72)),
            bm.verts.new((-width * 0.36, 0.0, length * 0.72)),
            bm.verts.new((0.0, -thickness * 0.36, length * 0.72)),
        ]
        tip = bm.verts.new((0.0, 0.0, length))
        base_cap = bm.verts.new((0.0, 0.0, -0.02))
        for i in range(4):
            ni = (i + 1) % 4
            bm.faces.new((ring0[i], ring0[ni], ring1[ni], ring1[i]))
            bm.faces.new((ring1[i], ring1[ni], tip))
            bm.faces.new((ring0[ni], ring0[i], base_cap))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        rot = Vector((0.0, 0.0, 1.0)).rotation_difference(axis.normalized()).to_matrix().to_4x4()
        xform = Matrix.Translation(v0) @ rot
        bmesh.ops.transform(bm, matrix=xform, verts=bm.verts)
        self._push_bm(bm, bone_name, mat)

    def _push_bm(self, bm: bmesh.types.BMesh, bone_name: str, mat: bpy.types.Material) -> None:
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        mat_idx = self.add_material(mat)
        self.parts.append((bm, bone_name, mat_idx))

    def build_skinned_object(self, arm_obj: bpy.types.Object) -> bpy.types.Object:
        mesh = bpy.data.meshes.new(f"{self.name}_Mesh")
        obj = bpy.data.objects.new(f"{self.name}_Body", mesh)
        bpy.context.scene.collection.objects.link(obj)
        for mat in self.materials:
            obj.data.materials.append(mat)

        merged = bmesh.new()
        dlayer = merged.verts.layers.deform.verify()

        bone_group_idx: dict[str, int] = {}
        for _, bname, _ in self.parts:
            if bname not in bone_group_idx:
                vg = obj.vertex_groups.new(name=bname)
                bone_group_idx[bname] = vg.index

        for part_bm, bname, mat_idx in self.parts:
            vg_idx = bone_group_idx[bname]
            vert_map = {}
            for v in part_bm.verts:
                nv = merged.verts.new(v.co)
                nv[dlayer][vg_idx] = 1.0
                vert_map[v.index] = nv
            for f in part_bm.faces:
                try:
                    nf = merged.faces.new([vert_map[v.index] for v in f.verts])
                    nf.material_index = mat_idx
                    nf.smooth = False
                except ValueError:
                    pass
            part_bm.free()

        merged.to_mesh(mesh)
        merged.free()

        for poly in mesh.polygons:
            poly.use_smooth = False
        mesh.update()

        obj.parent = arm_obj
        mod = obj.modifiers.new(name="Armature", type="ARMATURE")
        mod.object = arm_obj
        return obj


def create_humanoid_24_armature(
    name: str,
    height_scale: float = 1.0,
    width_scale: float = 1.0,
    include_legs: bool = True,
) -> tuple[bpy.types.Object, dict[str, tuple[Vector, Vector]]]:
    """
    Creates the standardized 24-bone fighting-game skeleton facing -Y (Blender Front),
    with .L on +X and .R on -X.
    """
    arm_data = bpy.data.armatures.new(f"{name}_ArmatureData")
    arm_obj = bpy.data.objects.new(name, arm_data)
    bpy.context.scene.collection.objects.link(arm_obj)
    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode="EDIT")

    hs = height_scale
    ws = width_scale
    eb = arm_data.edit_bones
    coords: dict[str, tuple[Vector, Vector]] = {}

    def add_b(bname: str, head: tuple[float, float, float], tail: tuple[float, float, float], parent_name: str | None = None, connect: bool = False):
        b = eb.new(bname)
        b.head = Vector(head)
        b.tail = Vector(tail)
        b.align_roll(Vector((0.0, 1.0, 0.0)))
        if parent_name and parent_name in eb:
            b.parent = eb[parent_name]
            b.use_connect = connect
        coords[bname] = (b.head.copy(), b.tail.copy())
        return b

    add_b("root", (0.0, 0.0, 0.0), (0.0, 0.0, 0.22 * hs))
    add_b("hips", (0.0, 0.0, 0.94 * hs), (0.0, 0.0, 1.08 * hs), "root")
    add_b("spine_01", (0.0, 0.0, 1.08 * hs), (0.0, 0.0, 1.24 * hs), "hips", True)
    add_b("spine_02", (0.0, 0.0, 1.24 * hs), (0.0, 0.0, 1.38 * hs), "spine_01", True)
    add_b("chest", (0.0, 0.0, 1.38 * hs), (0.0, 0.0, 1.54 * hs), "spine_02", True)
    add_b("neck", (0.0, 0.0, 1.54 * hs), (0.0, 0.0, 1.63 * hs), "chest", True)
    add_b("head", (0.0, 0.0, 1.63 * hs), (0.0, 0.0, 1.86 * hs), "neck", True)
    add_b("back_socket", (0.0, 0.14 * ws, 1.44 * hs), (0.0, 0.28 * ws, 1.44 * hs), "chest")

    for side, sx in [("L", 1.0), ("R", -1.0)]:
        add_b(f"clavicle.{side}", (sx * 0.07 * ws, 0.0, 1.50 * hs), (sx * 0.22 * ws, 0.0, 1.50 * hs), "chest")
        add_b(f"upper_arm.{side}", (sx * 0.22 * ws, 0.0, 1.50 * hs), (sx * 0.27 * ws, 0.02, 1.21 * hs), f"clavicle.{side}", True)
        add_b(f"lower_arm.{side}", (sx * 0.27 * ws, 0.02, 1.21 * hs), (sx * 0.29 * ws, -0.04, 0.95 * hs), f"upper_arm.{side}", True)
        add_b(f"hand.{side}", (sx * 0.29 * ws, -0.04, 0.95 * hs), (sx * 0.30 * ws, -0.07, 0.84 * hs), f"lower_arm.{side}", True)
        add_b(f"weapon_socket.{side}", (sx * 0.30 * ws, -0.07, 0.87 * hs), (sx * 0.30 * ws, -0.25, 0.87 * hs), f"hand.{side}")

        if include_legs:
            add_b(f"thigh.{side}", (sx * 0.13 * ws, 0.0, 0.94 * hs), (sx * 0.14 * ws, -0.02, 0.52 * hs), "hips")
            add_b(f"shin.{side}", (sx * 0.14 * ws, -0.02, 0.52 * hs), (sx * 0.14 * ws, 0.02, 0.11 * hs), f"thigh.{side}", True)
            add_b(f"foot.{side}", (sx * 0.14 * ws, 0.02, 0.11 * hs), (sx * 0.14 * ws, -0.13, 0.03 * hs), f"shin.{side}", True)
            add_b(f"toe.{side}", (sx * 0.14 * ws, -0.13, 0.03 * hs), (sx * 0.14 * ws, -0.22, 0.02 * hs), f"foot.{side}", True)

    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in arm_obj.pose.bones:
        pb.rotation_mode = "XYZ"
    return arm_obj, coords


def build_base_fighter_body(
    builder: LowPolyPartBuilder,
    coords: dict[str, tuple[Vector, Vector]],
    mat_primary: bpy.types.Material,
    mat_secondary: bpy.types.Material,
    mat_skin: bpy.types.Material,
    mat_accent: bpy.types.Material,
    bulk: float = 1.0,
    include_legs: bool = True,
) -> None:
    """Constructs crisp Virtua-Fighter faceted torso, limbs, gauntlets, boots, and head."""
    def seg(bname: str) -> tuple[Vector, Vector]:
        return coords[bname]

    # Pelvis & Spine/Chest
    h0, h1 = seg("hips")
    builder.add_tapered_limb(h0, h1, 0.16 * bulk, 0.14 * bulk, "hips", mat_secondary, segments=10, scale_xy=(1.18, 0.82))
    s10, s11 = seg("spine_01")
    builder.add_tapered_limb(s10, s11, 0.14 * bulk, 0.16 * bulk, "spine_01", mat_primary, segments=10, scale_xy=(1.16, 0.82))
    s20, s21 = seg("spine_02")
    builder.add_tapered_limb(s20, s21, 0.16 * bulk, 0.19 * bulk, "spine_02", mat_primary, segments=10, scale_xy=(1.22, 0.85))
    c0, c1 = seg("chest")
    builder.add_tapered_limb(c0, c1, 0.19 * bulk, 0.22 * bulk, "chest", mat_primary, segments=10, scale_xy=(1.28, 0.86))
    builder.add_box((0.0, -0.14 * bulk, (c0.z + c1.z) * 0.5), (0.30 * bulk, 0.08 * bulk, 0.14), "chest", mat_secondary, bevel_amt=0.015)
    # Belt buckle accent
    builder.add_box((0.0, -0.13 * bulk, (h0.z + h1.z) * 0.5), (0.12 * bulk, 0.06, 0.08), "hips", mat_accent, bevel_amt=0.01)

    # Neck & Head
    n0, n1 = seg("neck")
    builder.add_tapered_limb(n0, n1, 0.068 * bulk, 0.062 * bulk, "neck", mat_skin, segments=8)
    hd0, hd1 = seg("head")
    head_mid = (hd0 + hd1) * 0.5
    head_r = (hd1 - hd0).length * 0.54
    builder.add_icosphere(head_mid, head_r, "head", mat_skin, subdivisions=2, scale=(0.90, 0.98, 1.08))

    for side, sx in [("L", 1.0), ("R", -1.0)]:
        ua0, ua1 = seg(f"upper_arm.{side}")
        la0, la1 = seg(f"lower_arm.{side}")
        ha0, ha1 = seg(f"hand.{side}")
        builder.add_icosphere(ua0, 0.082 * bulk, f"clavicle.{side}", mat_secondary, subdivisions=1)
        builder.add_tapered_limb(ua0, ua1, 0.074 * bulk, 0.062 * bulk, f"upper_arm.{side}", mat_skin, segments=9)
        builder.add_icosphere(la0, 0.064 * bulk, f"lower_arm.{side}", mat_accent, subdivisions=1)
        builder.add_tapered_limb(la0, la1, 0.066 * bulk, 0.056 * bulk, f"lower_arm.{side}", mat_secondary, segments=9)
        builder.add_box(((ha0.x + ha1.x) * 0.5, (ha0.y + ha1.y) * 0.5, (ha0.z + ha1.z) * 0.5), (0.075 * bulk, 0.085 * bulk, 0.095 * bulk), f"hand.{side}", mat_accent, bevel_amt=0.008)

        if include_legs:
            th0, th1 = seg(f"thigh.{side}")
            sh0, sh1 = seg(f"shin.{side}")
            ft0, ft1 = seg(f"foot.{side}")
            to0, to1 = seg(f"toe.{side}")
            builder.add_tapered_limb(th0, th1, 0.105 * bulk, 0.082 * bulk, f"thigh.{side}", mat_secondary, segments=10)
            builder.add_icosphere(sh0, 0.082 * bulk, f"shin.{side}", mat_accent, subdivisions=1)
            builder.add_tapered_limb(sh0, sh1, 0.084 * bulk, 0.064 * bulk, f"shin.{side}", mat_primary, segments=10)
            builder.add_box(((ft0.x + ft1.x) * 0.5, (ft0.y + ft1.y) * 0.5, (ft0.z + ft1.z) * 0.5), (0.095 * bulk, 0.16 * bulk, 0.08), f"foot.{side}", mat_accent, bevel_amt=0.008)
            builder.add_box(((to0.x + to1.x) * 0.5, (to0.y + to1.y) * 0.5, (to0.z + to1.z) * 0.5), (0.09 * bulk, 0.10 * bulk, 0.055), f"toe.{side}", mat_secondary)


def reset_pose(arm_obj: bpy.types.Object) -> None:
    for pb in arm_obj.pose.bones:
        pb.location = (0.0, 0.0, 0.0)
        pb.rotation_euler = (0.0, 0.0, 0.0)
        pb.scale = (1.0, 1.0, 1.0)


def apply_pose_dict(
    arm_obj: bpy.types.Object,
    rot_deg_map: dict[str, tuple[float, float, float]],
    loc_map: dict[str, tuple[float, float, float]] | None = None,
) -> None:
    reset_pose(arm_obj)
    for bname, deg in rot_deg_map.items():
        if bname in arm_obj.pose.bones:
            pb = arm_obj.pose.bones[bname]
            pb.rotation_euler = (math.radians(deg[0]), math.radians(deg[1]), math.radians(deg[2]))
    if loc_map:
        for bname, loc in loc_map.items():
            if bname in arm_obj.pose.bones:
                arm_obj.pose.bones[bname].location = loc


def keyframe_all_bones(arm_obj: bpy.types.Object, frame: int) -> None:
    for pb in arm_obj.pose.bones:
        pb.keyframe_insert(data_path="rotation_euler", frame=frame)
        if pb.name in ("root", "hips"):
            pb.keyframe_insert(data_path="location", frame=frame)


def author_nla_action(
    arm_obj: bpy.types.Object,
    action_name: str,
    keyframes: list[tuple[int, dict[str, tuple[float, float, float]], dict[str, tuple[float, float, float]] | None]],
    linear_snap: bool = True,
) -> None:
    """
    Authors a 60fps fighting-game action with explicit Startup / Active / Recovery frames
    and pushes it cleanly onto a dedicated NLA track for Blender 5.2 GLTF export.
    """
    if arm_obj.animation_data is None:
        arm_obj.animation_data_create()

    act = bpy.data.actions.new(name=action_name)
    arm_obj.animation_data.action = act

    for frame, rot_map, loc_map in keyframes:
        apply_pose_dict(arm_obj, rot_map, loc_map)
        keyframe_all_bones(arm_obj, frame)

    slot = arm_obj.animation_data.action_slot
    # Set crisp linear-snap interpolation on channelbag fcurves if accessible
    if linear_snap and hasattr(act, "layers"):
        for layer in act.layers:
            for strip in getattr(layer, "strips", []):
                if hasattr(strip, "channelbag"):
                    cbag = strip.channelbag(slot)
                    if cbag:
                        for fc in cbag.fcurves:
                            for kp in fc.keyframe_points:
                                kp.interpolation = "LINEAR"

    track = arm_obj.animation_data.nla_tracks.new()
    track.name = action_name
    nla_strip = track.strips.new(action_name, 1, act)
    nla_strip.action_slot = slot
    track.mute = False
    arm_obj.animation_data.action = None
    reset_pose(arm_obj)


# ==============================================================================
# STANDARDIZED FIGHTING-GAME POSE LIBRARY (60 FPS)
# Blender Front is -Y:
#   bone X+ rotates limb forward (-Y) or backward (+Y) -> check right-hand rule:
#   Wait: bone tail points DOWN (-Z) for arms/legs or UP (+Z) for spine!
#   Let's keep poses expressive, readable in side-profile (+X/-X camera), and snappy!
# ==============================================================================
STANCE_BASE = {
    "hips": (-4, 0, -14),
    "spine_01": (-8, 0, 6),
    "chest": (-10, 0, 10),
    "head": (12, 0, -12),
    "upper_arm.L": (-46, 18, -15),
    "lower_arm.L": (-68, 0, 0),
    "upper_arm.R": (-28, -18, 15),
    "lower_arm.R": (-56, 0, 0),
    "thigh.L": (-26, 0, 8),
    "shin.L": (34, 0, 0),
    "foot.L": (-8, 0, 0),
    "thigh.R": (18, 0, -8),
    "shin.R": (22, 0, 0),
    "foot.R": (-16, 0, 0),
}


def merge_pose(*dicts: dict[str, tuple[float, float, float]]) -> dict[str, tuple[float, float, float]]:
    out: dict[str, tuple[float, float, float]] = {}
    for d in dicts:
        out.update(d)
    return out


def author_shared_locomotion_clips(arm_obj: bpy.types.Object, weapon_bias: str = "right_heavy") -> None:
    """Authors all 11 shared_locomotion NLA actions required by specs.yml."""
    s_idle_b = merge_pose(STANCE_BASE, {
        "spine_01": (11, 0, 6),
        "upper_arm.L": (-42, 20, -15),
        "upper_arm.R": (-28, -20, 15),
    })
    author_nla_action(arm_obj, "idle_fight_stance", [
        (1, STANCE_BASE, {"hips": (0.0, 0.0, 0.0)}),
        (20, s_idle_b, {"hips": (0.0, 0.0, -0.03)}),
        (40, STANCE_BASE, {"hips": (0.0, 0.0, 0.0)}),
    ])

    w1 = merge_pose(STANCE_BASE, {
        "thigh.L": (-36, 0, 4), "shin.L": (20, 0, 0),
        "thigh.R": (28, 0, -4), "shin.R": (36, 0, 0),
        "upper_arm.L": (-15, 14, 0), "upper_arm.R": (-45, -14, 0),
    })
    w2 = merge_pose(STANCE_BASE, {
        "thigh.L": (28, 0, 4), "shin.L": (36, 0, 0),
        "thigh.R": (-36, 0, -4), "shin.R": (20, 0, 0),
        "upper_arm.L": (-45, 14, 0), "upper_arm.R": (-15, -14, 0),
    })
    author_nla_action(arm_obj, "walk_forward", [
        (1, w1, {"hips": (0.0, 0.0, 0.02)}),
        (9, STANCE_BASE, {"hips": (0.0, 0.0, -0.02)}),
        (17, w2, {"hips": (0.0, 0.0, 0.02)}),
        (25, STANCE_BASE, {"hips": (0.0, 0.0, -0.02)}),
        (33, w1, {"hips": (0.0, 0.0, 0.02)}),
    ])

    guard_walk_1 = merge_pose(STANCE_BASE, {
        "upper_arm.L": (-65, 25, -25), "lower_arm.L": (-95, 0, 0),
        "upper_arm.R": (-60, -25, 25), "lower_arm.R": (-95, 0, 0),
        "thigh.L": (18, 0, 4), "thigh.R": (-24, 0, -4),
    })
    guard_walk_2 = merge_pose(guard_walk_1, {
        "thigh.L": (-24, 0, 4), "thigh.R": (18, 0, -4),
    })
    author_nla_action(arm_obj, "walk_back_guard", [
        (1, guard_walk_1, None),
        (15, guard_walk_2, None),
        (30, guard_walk_1, None),
    ])

    dash_1 = merge_pose(STANCE_BASE, {
        "hips": (22, 0, 0), "spine_01": (18, 0, 0), "chest": (16, 0, 0), "head": (-26, 0, 0),
        "thigh.L": (-55, 0, 0), "shin.L": (45, 0, 0),
        "thigh.R": (48, 0, 0), "shin.R": (55, 0, 0),
        "upper_arm.L": (35, 15, 0), "upper_arm.R": (-65, -15, 0),
    })
    dash_2 = merge_pose(dash_1, {
        "thigh.L": (48, 0, 0), "shin.L": (55, 0, 0),
        "thigh.R": (-55, 0, 0), "shin.R": (45, 0, 0),
        "upper_arm.L": (-65, 15, 0), "upper_arm.R": (35, -15, 0),
    })
    author_nla_action(arm_obj, "run_dash", [
        (1, dash_1, {"hips": (0.0, 0.0, -0.05)}),
        (11, dash_2, {"hips": (0.0, 0.0, 0.04)}),
        (21, dash_1, {"hips": (0.0, 0.0, -0.05)}),
    ])

    crouch = merge_pose(STANCE_BASE, {
        "thigh.L": (-52, 0, 8), "shin.L": (78, 0, 0),
        "thigh.R": (-48, 0, -8), "shin.R": (74, 0, 0),
        "spine_01": (20, 0, 0), "upper_arm.L": (25, 18, 0), "upper_arm.R": (25, -18, 0),
    })
    launch_pose = merge_pose(STANCE_BASE, {
        "thigh.L": (-18, 0, 6), "shin.L": (12, 0, 0),
        "thigh.R": (16, 0, -6), "shin.R": (10, 0, 0),
        "upper_arm.L": (-85, 20, 0), "upper_arm.R": (-75, -20, 0),
    })
    author_nla_action(arm_obj, "jump_start", [
        (1, crouch, {"hips": (0.0, 0.0, -0.18)}),
        (6, launch_pose, {"hips": (0.0, 0.0, 0.08)}),
        (12, launch_pose, {"hips": (0.0, 0.0, 0.10)}),
    ])

    air_a = merge_pose(STANCE_BASE, {
        "thigh.L": (-55, 0, 10), "shin.L": (68, 0, 0),
        "thigh.R": (-18, 0, -10), "shin.R": (42, 0, 0),
        "upper_arm.L": (-55, 28, -20), "upper_arm.R": (-45, -28, 20),
    })
    air_b = merge_pose(air_a, {
        "thigh.L": (-48, 0, 10), "thigh.R": (-26, 0, -10),
    })
    author_nla_action(arm_obj, "jump_air_loop", [
        (1, air_a, None),
        (14, air_b, None),
        (28, air_a, None),
    ])

    author_nla_action(arm_obj, "land", [
        (1, air_a, {"hips": (0.0, 0.0, 0.0)}),
        (5, crouch, {"hips": (0.0, 0.0, -0.16)}),
        (12, STANCE_BASE, {"hips": (0.0, 0.0, 0.0)}),
    ])

    block_pose = merge_pose(STANCE_BASE, {
        "spine_01": (-6, 0, 12), "chest": (-4, 0, 16),
        "upper_arm.L": (-78, 32, -35), "lower_arm.L": (-100, 0, 0),
        "upper_arm.R": (-72, -32, 35), "lower_arm.R": (-100, 0, 0),
    })
    author_nla_action(arm_obj, "block_high", [
        (1, STANCE_BASE, None),
        (4, block_pose, {"hips": (0.0, 0.04, -0.04)}),
        (18, block_pose, {"hips": (0.0, 0.04, -0.04)}),
    ])

    hit_recoil = merge_pose(STANCE_BASE, {
        "hips": (-14, 0, 0), "spine_01": (-18, 0, -10), "chest": (-20, 0, -12), "head": (-22, 0, 10),
        "upper_arm.L": (-15, 45, 0), "upper_arm.R": (-10, -45, 0),
    })
    author_nla_action(arm_obj, "hit_light", [
        (1, hit_recoil, {"hips": (0.0, 0.08, 0.0)}),
        (9, hit_recoil, {"hips": (0.0, 0.10, 0.0)}),
        (16, STANCE_BASE, {"hips": (0.0, 0.0, 0.0)}),
    ])

    launch_arc = merge_pose(hit_recoil, {
        "hips": (-48, 0, 0), "spine_01": (-24, 0, 0),
        "thigh.L": (-35, 0, 12), "thigh.R": (-25, 0, -12),
        "upper_arm.L": (-75, 40, 0), "upper_arm.R": (-75, -40, 0),
    })
    author_nla_action(arm_obj, "hit_launch_arc", [
        (1, hit_recoil, {"hips": (0.0, 0.0, 0.05)}),
        (10, launch_arc, {"hips": (0.0, 0.12, 0.15)}),
        (24, launch_arc, {"hips": (0.0, 0.12, 0.05)}),
    ])

    prone = {
        "hips": (-82, 0, 0), "spine_01": (-6, 0, 0),
        "upper_arm.L": (-20, 35, 0), "upper_arm.R": (-20, -35, 0),
        "thigh.L": (8, 0, 6), "thigh.R": (8, 0, -6),
    }
    pushup = {
        "hips": (-35, 0, 0), "spine_01": (25, 0, 0),
        "thigh.L": (-55, 0, 6), "shin.L": (75, 0, 0),
        "upper_arm.R": (-55, -20, 0),
    }
    author_nla_action(arm_obj, "knockdown_getup", [
        (1, prone, {"hips": (0.0, 0.0, -0.68)}),
        (14, prone, {"hips": (0.0, 0.0, -0.68)}),
        (24, pushup, {"hips": (0.0, 0.0, -0.30)}),
        (36, STANCE_BASE, {"hips": (0.0, 0.0, 0.0)}),
    ])


def export_glb(filepath: str) -> None:
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=filepath,
        export_format="GLB",
        export_yup=True,
        export_apply=False,
        export_animations=True,
        export_animation_mode="NLA_TRACKS",
        export_optimize_animation_size=True,
    )


def count_scene_triangles() -> int:
    total = 0
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH":
            total += sum(max(0, len(p.vertices) - 2) for p in obj.data.polygons)
    return total


def render_side_profile_preview(
    arm_obj: bpy.types.Object,
    output_png: str,
    pose_rot: dict[str, tuple[float, float, float]] | None = None,
    cam_height: float = 1.0,
    cam_dist: float = 3.3,
) -> None:
    """
    Renders a crisp side-profile (+X fighting silhouette matching Godot's +Z/-Z arcade view)
    verification image via BLENDER_EEVEE.
    """
    os.makedirs(os.path.dirname(output_png), exist_ok=True)
    if pose_rot:
        apply_pose_dict(arm_obj, pose_rot)

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 640
    scene.render.resolution_y = 640
    scene.render.film_transparent = False

    world = bpy.data.worlds.new("PreviewWorld")
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.035, 0.04, 0.065, 1.0)
        bg.inputs[1].default_value = 1.0
    scene.world = world

    # Key & Rim lights for sharp silhouette verification
    key_data = bpy.data.lights.new("KeyLight", type="SUN")
    key_data.energy = 3.8
    key_obj = bpy.data.objects.new("KeyLight", key_data)
    scene.collection.objects.link(key_obj)
    key_obj.rotation_euler = (math.radians(48), math.radians(-22), math.radians(55))

    rim_data = bpy.data.lights.new("RimLight", type="SUN")
    rim_data.energy = 2.4
    rim_obj = bpy.data.objects.new("RimLight", rim_data)
    scene.collection.objects.link(rim_obj)
    rim_obj.rotation_euler = (math.radians(65), math.radians(35), math.radians(-125))

    # Arcade side-3/4 profile camera (+X slightly -Y so silhouette & weapon read clearly)
    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.lens = 45.0
    cam_obj = bpy.data.objects.new("PreviewCam", cam_data)
    scene.collection.objects.link(cam_obj)
    cam_pos = Vector((cam_dist * 0.90, -cam_dist * 0.45, cam_height + 0.35))
    target = Vector((0.0, -0.08, cam_height))
    direction = (target - cam_pos).normalized()
    cam_obj.location = cam_pos
    cam_obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam_obj

    scene.render.filepath = output_png
    bpy.ops.render.render(write_still=True)

    # Clean up temporary preview camera/lights before or after export
    bpy.data.objects.remove(cam_obj, do_unlink=True)
    bpy.data.objects.remove(key_obj, do_unlink=True)
    bpy.data.objects.remove(rim_obj, do_unlink=True)
    reset_pose(arm_obj)
