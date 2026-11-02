# Night shift item 3, step 3 (bridge job night_helmet_v7_0407): sharp edges above 35 deg (vent rims,
# shell edges) + weighted normals keeping them; helmet-v7-35.glb = assets/gear/helmet-v2.glb.
import bpy, json, math
from mathutils import Vector
SRC="C:/Users/lange/Documents/Hawkey/art/night/helmet/helmet-v6c-0344.blend"
OUT="C:/Users/lange/Documents/Hawkey/art/night/helmet/"
def crease(o):
    me=o.data; me.calc_loop_triangles(); a=[]
    for t in me.loop_triangles:
        fn=t.normal
        for li in t.loops:
            a.append(math.degrees(math.acos(min(1,abs(me.corner_normals[li].vector.dot(fn))))))
    a.sort(); return a[len(a)//2]
res={}
for ang in (35,50):
    bpy.ops.wm.open_mainfile(filepath=SRC)
    for name in ("helmet_shell","helmet_fittings"):
        o=bpy.data.objects[name]
        for oo in bpy.context.view_layer.objects: oo.select_set(False)
        o.select_set(True); bpy.context.view_layer.objects.active=o
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(ang),keep_sharp_edges=False)
        m=o.modifiers.new("wn","WEIGHTED_NORMAL"); m.keep_sharp=True; m.weight=50
        bpy.ops.object.modifier_apply(modifier="wn")
    sh=bpy.data.objects["helmet_shell"]
    res[ang]={"crease":crease(sh),"tris":len(sh.data.loop_triangles)}
    print("V7",ang,res[ang])
    tag="v7-%d"%ang
    for o in bpy.data.objects: o.select_set(o.name in ("helmet_shell","helmet_fittings","helmet_visor"))
    bpy.ops.export_scene.gltf(filepath=OUT+"helmet-"+tag+".glb",use_selection=True,export_format='GLB',export_vertex_color='ACTIVE',export_apply=True)
    bpy.ops.wm.save_as_mainfile(filepath=OUT+"helmet-"+tag+"-0407.blend")
    sc=bpy.context.scene; sc.render.engine='BLENDER_WORKBENCH'; sc.display.shading.light='STUDIO'; sc.display.shading.color_type='VERTEX'
    sc.render.resolution_x=600; sc.render.resolution_y=600
    cd=bpy.data.cameras.new("QC"); cam=bpy.data.objects.new("QC",cd); sc.collection.objects.link(cam); sc.camera=cam; cd.lens=85
    tgt=Vector((0,0,0.06)); dv=Vector((-0.7,-0.8,0.35)).normalized()*1.1; cam.location=tgt+dv
    cam.rotation_euler=(tgt-cam.location).to_track_quat('-Z','Y').to_euler()
    sc.render.filepath=OUT+"helmet-"+tag+"-three_q.png"; bpy.ops.render.render(write_still=True)
json.dump(res,open(OUT+"helmet-v7-report.json","w"),indent=1)
print("NIGHT_HELMET_V7_OK")
