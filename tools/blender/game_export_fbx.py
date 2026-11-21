"""Hawkey: game export (tools/export_player_gltf.gd) -> Blender check renders + FBX for Unreal
(tools/unreal/import_game_players_ue.py). Run through the bridge; reads art/game-export on the PC."""
import bpy, os, math, sys
from mathutils import Vector
SRC = "C:/Users/lange/Documents/Hawkey/art/game-export"
for name in ("hawkey_skater", "hawkey_skater_away", "hawkey_goalie"):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=f"{SRC}/{name}.glb")
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    zs = [ (o.matrix_world @ Vector(c)).z for o in meshes for c in o.bound_box ]
    xs = [ (o.matrix_world @ Vector(c)).x for o in meshes for c in o.bound_box ]
    print("GX", name, "meshes", len(meshes), "height", round(max(zs) - min(zs), 3), "width", round(max(xs) - min(xs), 3),
          "mats", sorted({s.material.name for o in meshes for s in o.material_slots if s.material}))
    # FBX for Unreal: one object, vertex colours, materials by name (HK_VC / HK_FACE / HK_VISOR), textures copied.
    bpy.ops.object.select_all(action="SELECT")
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = "SM_" + name
    os.makedirs(f"{SRC}/fbx", exist_ok=True)
    bpy.ops.export_scene.fbx(filepath=f"{SRC}/fbx/{name}.fbx", use_selection=True, object_types={"MESH"},
                             apply_unit_scale=True, axis_forward="-Z", axis_up="Y", mesh_smooth_type="FACE",
                             colors_type="LINEAR", path_mode="COPY", embed_textures=False, add_leaf_bones=False, bake_anim=False)
    for img in bpy.data.images:
        if img.has_data or img.packed_file:
            img.filepath_raw = f"{SRC}/fbx/T_{name}_face.png"; img.file_format = "PNG"
            try: img.save(); print("GX face texture", img.name, img.size[:])
            except Exception as e: print("GX tex save failed", e)
    # Check render: vertex colours in Workbench, front and three-quarter.
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "VERTEX"
    scene.display.shading.show_cavity = True
    scene.world = bpy.data.worlds.new("w"); scene.world.color = (0.03, 0.09, 0.12)
    scene.render.resolution_x, scene.render.resolution_y = 800, 1000
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); scene.collection.objects.link(cam); scene.camera = cam
    cz = (max(zs) + min(zs)) / 2
    for tag, loc in (("front", (0, 4.2, cz)), ("34", (2.9, 3.0, cz + 0.3))):
        cam.location = loc
        cam.rotation_euler = (Vector((0, 0, cz)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = f"{SRC}/check_{name}_{tag}.png"
        bpy.ops.render.render(write_still=True)
print("GX_CONVERT_OK")
