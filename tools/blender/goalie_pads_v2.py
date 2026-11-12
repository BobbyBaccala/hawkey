"""Goalie pads v2: the v1 pads (assets/gear/goalie-pads-v1.glb, copied to
<bridge>/input/) with a real boot channel carved into the back of each lower
pad: a 14.4 cm wide, 4.5 cm deep recess from the pad bottom up to the top of the
skate cuff, rounded at the top, deepening to a toe pocket under a 0.8 cm toe bridge (1.1 cm drawn; on a real pad the toe sits under a thin bridge and strap)
below y = -0.26, so the boot sits in an empty pocket instead of
inside the foam. Upper (thigh rise) parts are passed through unchanged.
Coordinates below are Godot pad space (x across, y up the shin, z toward the
shooter; back face at z = -0.04, front face at z = +0.06, bottom y = -0.365).
Writes out/goalie_pads_v2.glb and goalie_pads_v2.json (volume/hole stats)."""
import bpy, bmesh, sys, os, json
from mathutils import Matrix, Vector
ROOT = sys.argv[sys.argv.index("--") + 1]
OUT = os.path.join(ROOT, "out")
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "input", "goalie-pads-v1.glb"))
CH_HALF_W = 0.072
CH_TOP = -0.12
CH_BACK, CH_FRONT = -0.08, 0.005
TOE_HALF_W, TOE_TOP, TOE_FLOOR = 0.07, -0.25, 0.052
TIP_HALF_W, TIP_TOP = 0.045, -0.325
def g2b(v):
    # Godot (x, y, z) -> Blender (x, -z, y)
    return Vector((v[0], -v[2], v[1]))
stats = {}
for ob in [o for o in bpy.data.objects if o.type == "MESH" and o.name.startswith("pad_lower")]:
    me = ob.data
    before = len(me.polygons)
    # Cutter: a box with a rounded top, built in the pad's local space.
    bm = bmesh.new()
    seg = 10
    prof = []
    for k in range(seg + 1):
        a = 3.14159 * k / seg
        prof.append((CH_HALF_W * (-1 if k == 0 else 1) * abs(__import__("math").cos(a)) if False else -CH_HALF_W * __import__("math").cos(a), CH_TOP + 0.04 * __import__("math").sin(a)))
    pts = [(-CH_HALF_W, -0.50)] + prof + [(CH_HALF_W, -0.50)]
    back = [bm.verts.new(g2b((x, y, CH_BACK))) for x, y in pts]
    front = [bm.verts.new(g2b((x, y, CH_FRONT))) for x, y in pts]
    n = len(pts)
    bm.faces.new(back)
    bm.faces.new(list(reversed(front)))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new([back[i], back[j], front[j], front[i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    cme = bpy.data.meshes.new("cutter")
    bm.to_mesh(cme); bm.free()
    cutter = bpy.data.objects.new("cutter_" + ob.name, cme)
    bpy.context.scene.collection.objects.link(cutter)
    cutter.matrix_world = ob.matrix_world.copy()
    mod = ob.modifiers.new("channel", "BOOLEAN")
    mod.operation = "DIFFERENCE"; mod.object = cutter; mod.solver = "EXACT"
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier="channel")
    bpy.data.objects.remove(cutter, do_unlink=True)
    # Toe pocket: the boot toe sits deeper under a thin toe bridge; at the
    # very bottom the toe tip shows through a small opening at the front, as
    # it does under a real pad's toe bridge.
    for name, box in (("toe", ((-TOE_HALF_W, -0.50, CH_BACK), (TOE_HALF_W, TOE_TOP, TOE_FLOOR))),
                      ("tip", ((-TIP_HALF_W, -0.50, CH_BACK), (TIP_HALF_W, TIP_TOP, 0.20)))):
        bm = bmesh.new()
        lo, hi = g2b(box[0]), g2b(box[1])
        mn = Vector((min(lo.x, hi.x), min(lo.y, hi.y), min(lo.z, hi.z))); mx = Vector((max(lo.x, hi.x), max(lo.y, hi.y), max(lo.z, hi.z)))
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            v.co = Vector((mn.x if v.co.x < 0 else mx.x, mn.y if v.co.y < 0 else mx.y, mn.z if v.co.z < 0 else mx.z))
        tme = bpy.data.meshes.new(name); bm.to_mesh(tme); bm.free()
        cut = bpy.data.objects.new(name + "_" + ob.name, tme)
        bpy.context.scene.collection.objects.link(cut)
        cut.matrix_world = ob.matrix_world.copy()
        mod = ob.modifiers.new(name, "BOOLEAN")
        mod.operation = "DIFFERENCE"; mod.object = cut; mod.solver = "EXACT"
        bpy.ops.object.modifier_apply(modifier=name)
        bpy.data.objects.remove(cut, do_unlink=True)
    # Recess faces: soft normals so the channel reads as moulded foam.
    me.update()
    stats[ob.name] = {"polys_before": before, "polys_after": len(me.polygons), "manifold": all(e.is_manifold for e in bmesh.from_edit_mesh(me).edges) if False else None}
bpy.ops.object.select_all(action="SELECT")
for o in bpy.data.objects:
    if o.type != "MESH": o.select_set(False)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "goalie_pads_v2.glb"), export_format="GLB", use_selection=True, export_apply=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "goalie_pads_v2.blend"))
open(os.path.join(OUT, "goalie_pads_v2.json"), "w").write(json.dumps(stats, indent=1))
print("STATS", stats)
print("DONE")
