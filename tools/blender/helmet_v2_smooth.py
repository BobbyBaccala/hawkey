# Night shift item 3, step 2 (bridge job night_helmet_v6_0402, variant v6c): from helmet-v2-0302.blend
# (helmet_v2_debrand.py), Taubin-smooth the team-colour shell (removes collapse-decimate lumps without
# shrinking), split helmet_shell / helmet_fittings, weighted normals. Step 3 is helmet_v2_normals.py.
ITERS=25; WEIGHTED=True; TAG='v6c'; RENDER=True
import bpy, bmesh, json, math, sys
from mathutils import Vector
SRC="C:/Users/lange/Documents/Hawkey/art/night/helmet/helmet-v2-0302.blend"
OUT="C:/Users/lange/Documents/Hawkey/art/night/helmet/"
bpy.ops.wm.open_mainfile(filepath=SRC)
rep={}
for o in bpy.data.objects: rep.setdefault("objects",[]).append([o.name,o.type,len(o.data.polygons) if o.type=='MESH' else 0])
shell=bpy.data.objects["helmet_shell"]; visor=bpy.data.objects["helmet_visor"]
me=shell.data
ca=me.color_attributes.active_color if me.color_attributes else None
rep["color_attr"]=[ca.name,ca.domain,ca.data_type] if ca else None
CA_NAME=ca.name; CA_DOM=ca.domain
bm=bmesh.new(); bm.from_mesh(me); bm.verts.ensure_lookup_table(); bm.faces.ensure_lookup_table()
# per-vertex colour (white = shell mask)
def vcol():
    cols={}
    if ca.domain=='POINT':
        for v in bm.verts: cols[v.index]=Vector(ca.data[v.index].color[:3])
    else:
        lay=bm.loops.layers.color.get(ca.name) or bm.loops.layers.float_color.get(ca.name)
        for f in bm.faces:
            for l in f.loops: cols[l.vert.index]=Vector(l[lay][:3])
    return cols
cols=vcol()
white=lambda c: min(c)>0.7
shell_faces=[f for f in bm.faces if sum(1 for v in f.verts if white(cols[v.index]))>=2]
sv=set(v for f in shell_faces for v in f.verts if white(cols[v.index]))
# smooth the shell surface (lumps from collapse decimate), keep borders fixed
border=set(v for v in sv if v.is_boundary or any(not white(cols[n.index]) for e in v.link_edges for n in e.verts))
movable=[v for v in sv if v not in border]
orig={v.index:v.co.copy() for v in movable}
for it in range(ITERS):
    bmesh.ops.smooth_vert(bm,verts=movable,factor=0.5,use_axis_x=True,use_axis_y=True,use_axis_z=True)
    bmesh.ops.smooth_vert(bm,verts=movable,factor=-0.53,use_axis_x=True,use_axis_y=True,use_axis_z=True)
rep["taubin_mean_move"]=sum((v.co-orig[v.index]).length for v in movable)/max(1,len(movable))
bm.to_mesh(me); bm.free()
# split: shell (white faces) vs fittings (rest)
bpy.ops.object.select_all(action='DESELECT'); shell.select_set(True); bpy.context.view_layer.objects.active=shell
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='DESELECT'); bpy.ops.object.mode_set(mode='OBJECT')
cols2={}
if CA_DOM=='POINT':
    for i,d in enumerate(me.color_attributes[CA_NAME].data): cols2[i]=d.color
else:
    for li,l in enumerate(me.loops): cols2[l.vertex_index]=me.color_attributes[CA_NAME].data[li].color
for p in me.polygons:
    p.select = sum(1 for vi in p.vertices if min(cols2[vi][:3])>0.7)>=2
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_mode(type='FACE'); bpy.ops.mesh.separate(type='SELECTED'); bpy.ops.object.mode_set(mode='OBJECT')
parts=[o for o in bpy.context.selected_objects]
newshell=[o for o in parts if o!=shell][0]
shell.name="helmet_fittings"; newshell.name="helmet_shell"
for o in (newshell,shell,visor):
    bpy.context.view_layer.objects.active=o
    for oo in bpy.context.selected_objects: oo.select_set(False)
    o.select_set(True)
    bpy.ops.object.shade_smooth()
    if WEIGHTED:
        m=o.modifiers.new("wn","WEIGHTED_NORMAL"); m.keep_sharp=False; m.weight=50
        bpy.ops.object.modifier_apply(modifier="wn")
for o in (newshell,shell,visor):
    o.data.update()
    bb=[o.matrix_world@Vector(c) for c in o.bound_box]
    rep[o.name]={"tris":sum(len(p.vertices)-2 for p in o.data.polygons),"min":[round(min(b[i] for b in bb),4) for i in range(3)],"max":[round(max(b[i] for b in bb),4) for i in range(3)]}
for o in bpy.data.objects: o.select_set(o in (newshell,shell,visor))
bpy.ops.export_scene.gltf(filepath=OUT+"helmet-"+TAG+".glb",use_selection=True,export_format='GLB',export_vertex_color='ACTIVE',export_apply=True)
bpy.ops.wm.save_as_mainfile(filepath=OUT+"helmet-"+TAG+"-0344.blend")
if RENDER:
    # previews
    sc=bpy.context.scene; sc.render.engine='BLENDER_WORKBENCH'; sc.display.shading.light='STUDIO'; sc.display.shading.color_type='VERTEX'
    sc.render.resolution_x=600; sc.render.resolution_y=600
    cam=bpy.data.objects.get("Camera")
    if cam is None:
        cd=bpy.data.cameras.new("Cam"); cam=bpy.data.objects.new("Camera",cd); sc.collection.objects.link(cam)
    sc.camera=cam; cam.data.lens=85
    tgt=Vector((0,0,0.06))
    for name,d in {"three_q":(-0.7,-0.8,0.35),"side":(1,0,0.1),"front":(0,-1,0.1)}.items():
        dv=Vector(d).normalized()*1.1; cam.location=tgt+dv
        cam.rotation_euler=(tgt-cam.location).to_track_quat('-Z','Y').to_euler()
        sc.render.filepath=OUT+"helmet-"+TAG+"-%s.png"%name; bpy.ops.render.render(write_still=True)
json.dump(rep,open(OUT+"helmet-"+TAG+"-report.json","w"),indent=1)
def crease(o):
    me=o.data; me.calc_loop_triangles() if hasattr(me,'calc_loop_triangles') else None
    a=[]
    for t in me.loop_triangles:
        fn=t.normal
        for li in t.loops:
            n=me.corner_normals[li].vector if hasattr(me,'corner_normals') else me.loops[li].normal
            c=abs(n.dot(fn)); a.append(math.degrees(math.acos(min(1,c))))
    a.sort(); return a[len(a)//2]
rep["crease"]=crease(newshell)
json.dump(rep,open(OUT+"helmet-"+TAG+"-report.json","w"),indent=1)
print("CREASE",TAG,ITERS,WEIGHTED,rep["crease"])
