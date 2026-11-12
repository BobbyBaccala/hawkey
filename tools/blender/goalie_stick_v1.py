"""Hawkey goalie stick v1 from the owner's downloaded stick model (art/incoming/
ccm_premier_goaliestick.blend). Brand removal: the two logo images (maker
wordmark and model name) are blanked before baking, so no lettering survives;
only the plain red/black chevron paint is kept. Output: out/goalie_stick_v1.glb
(one mesh "goalie_stick", baked colour texture) and goalie_stick_v1.json.
Frame of the GLB (Godot, Y up): origin at the heel (where shaft line meets the
ice), +Y up the shaft, toe of the blade toward +X, blade bottom near y=0."""
import bpy, bmesh, sys, os, json
from mathutils import Vector, Matrix
ROOT = sys.argv[sys.argv.index("--") + 1]
OUT = os.path.join(ROOT, "out")
SRC = "C:/Users/lange/Documents/Hawkey/art/incoming/ccm_premier_goaliestick.blend"
bpy.ops.wm.open_mainfile(filepath=SRC)
# 1. Blank every logo/lettering image (alpha 0 -> the material shows only the paint).
for im in bpy.data.images:
    if "logo" in im.name.lower():
        n = im.size[0] * im.size[1]
        im.pixels[:] = [0.0] * (n * 4)
        im.update()
# 2. Keep the stick body and the blade tape; drop the scene, the oversize copy and planes.
keep = [bpy.data.objects["Cube"], bpy.data.objects["Cube.002"]]
for o in list(bpy.data.objects):
    if o not in keep:
        bpy.data.objects.remove(o, do_unlink=True)
for o in keep:
    o.select_set(True)
bpy.context.view_layer.objects.active = keep[0]
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
# Cube carries modifiers? apply them.
for o in keep:
    bpy.context.view_layer.objects.active = o
    for m in list(o.modifiers):
        try: bpy.ops.object.modifier_apply(modifier=m.name)
        except Exception as e: print("mod", m.name, e)
bpy.ops.object.select_all(action="DESELECT")
for o in keep: o.select_set(True)
bpy.context.view_layer.objects.active = keep[0]
bpy.ops.object.join()
ob = bpy.context.view_layer.objects.active
ob.name = "goalie_stick"
me = ob.data
# 3. Bake the base colour (with the logos blanked) into one texture on a fresh UV.
bake_uv = me.uv_layers.new(name="bake")
me.uv_layers.active = bake_uv
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.004)
bpy.ops.object.mode_set(mode="OBJECT")
img = bpy.data.images.new("goalie_stick_v1_color", 2048, 2048)
for mat in me.materials:
    nt = mat.node_tree
    n = nt.nodes.new("ShaderNodeTexImage"); n.image = img
    nt.nodes.active = n
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 4
scene.cycles.device = "CPU"
scene.render.bake.use_pass_direct = False
scene.render.bake.use_pass_indirect = False
scene.render.bake.use_pass_color = True
scene.render.bake.margin = 6
bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"}, use_clear=True)
img.filepath_raw = os.path.join(OUT, "goalie_stick_v1_color.png"); img.file_format = "PNG"; img.save()
# One simple material using the bake; drop the other UV maps.
for uv in [u for u in me.uv_layers if u.name != "bake"]:
    me.uv_layers.remove(uv)
mat = bpy.data.materials.new("goalie_stick"); mat.use_nodes = True
bsdf = mat.node_tree.nodes["Principled BSDF"]
tex = mat.node_tree.nodes.new("ShaderNodeTexImage"); tex.image = img
mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.45
me.materials.clear(); me.materials.append(mat)
# 4. Frame: find blade bottom, shaft axis (PCA of the upper half) and the heel.
vs = [v.co.copy() for v in me.vertices]
zmin = min(v.z for v in vs); zmax = max(v.z for v in vs)
top = [v for v in vs if v.z > zmin + 0.55 * (zmax - zmin)]
c = sum(top, Vector()) / len(top)
# principal direction by power iteration
d = Vector((0, 0.3, 1)).normalized()
for _ in range(40):
    acc = Vector()
    for v in top:
        p = v - c; acc += p * p.dot(d)
    d = acc.normalized()
if d.z < 0: d = -d
# heel: shaft line at the blade bottom
t = (zmin - c.z) / d.z
heel = c + d * t
# toe: the far end of the blade bottom away from the heel
low = [v for v in vs if v.z < zmin + 0.04 * (zmax - zmin)]
toe = max(low, key=lambda v: (v - heel).xy.length)
blade_h = max(v.z for v in vs if (v - heel).xy.length > 0.6 * (toe - heel).xy.length) - zmin
# Build basis: Y_godot = shaft (blender Z), X = toe direction orthogonal to shaft.
toe_dir = (toe - heel); toe_dir = (toe_dir - d * toe_dir.dot(d)).normalized()
zb = toe_dir.cross(d)
R = Matrix((toe_dir, zb, d)).transposed()   # columns: new X, new Y(blender), new Z(blender up = shaft)
scale = 0.089 / blade_h   # regulation-ish goalie blade height 8.9 cm
M = Matrix.Scale(scale, 4) @ R.inverted().to_4x4() @ Matrix.Translation(-heel)
me.transform(M)
me.update()
vs2 = [v.co for v in me.vertices]
stats = {"scale": scale, "blade_h_src": blade_h, "shaft_len": max(v.z for v in vs2), "tris": sum(len(p.vertices) - 2 for p in me.polygons),
         "min": [min(v[i] for v in vs2) for i in range(3)], "max": [max(v[i] for v in vs2) for i in range(3)],
         "toe_local": list(M @ toe)}
open(os.path.join(OUT, "goalie_stick_v1.json"), "w").write(json.dumps(stats, indent=1))
print("STATS", stats)
bpy.ops.object.select_all(action="DESELECT"); ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "goalie_stick_v1.glb"), export_format="GLB", use_selection=True,
                          export_yup=True, export_apply=True, export_materials="EXPORT")
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "goalie_stick_v1.blend"))
print("DONE")
