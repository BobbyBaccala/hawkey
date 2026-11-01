import bpy, sys, os
root = sys.argv[sys.argv.index("--") + 1]
out = os.path.join(root, "out")
print("BLENDER", bpy.app.version_string)
bpy.ops.wm.read_factory_settings(use_empty=True)
base = os.path.join(root, "input", "player-base-v1.glb")
bpy.ops.import_scene.gltf(filepath=base)
arm = [o for o in bpy.data.objects if o.type == "ARMATURE"]
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
print("ARMATURES", len(arm), "BONES", len(arm[0].data.bones) if arm else 0)
for m in meshes:
    print("MESH", m.name, len(m.data.vertices), "verts", len(m.vertex_groups), "groups", [a.name for a in m.data.attributes][:12])
# quick workbench render of the body
scene = bpy.context.scene
cam_data = bpy.data.cameras.new("cam"); cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam); scene.camera = cam
cam.location = (0, -4.2, 1.0); cam.rotation_euler = (1.5708, 0, 0)
scene.render.engine = "BLENDER_WORKBENCH"
scene.render.resolution_x, scene.render.resolution_y = 640, 800
scene.render.filepath = os.path.join(out, "hello.png")
bpy.ops.render.render(write_still=True)
bpy.ops.export_scene.gltf(filepath=os.path.join(out, "hello_roundtrip.glb"), export_format="GLB")
print("HELLO_OK")
