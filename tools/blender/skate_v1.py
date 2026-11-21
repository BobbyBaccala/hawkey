import bpy, bmesh, json
# Builds assets/gear/skate-v1.glb from the owner's art/incoming/hockey_skate.glb (HKY, CC-BY 4.0; not in the repo).
# Run through the Blender bridge (tools/blender/README.md); outputs land in Hawkey/art/night/skates/.
from mathutils import Vector, Matrix
R='C:/Users/lange/Documents/Hawkey'; OUT=R+'/art/night/skates'
# Item 2 slice 2: split boot/cuff BEFORE decimating (clean cut edges), then decimate each.
bpy.ops.wm.read_factory_settings(use_empty=True)
s=bpy.context.scene
bpy.ops.import_scene.gltf(filepath=R+'/art/incoming/hockey_skate.glb')
parts=[]
for o in [o for o in s.objects if o.type=='MESH']:
    pts=[o.matrix_world@v.co for v in o.data.vertices]
    if sum(p.y for p in pts)/len(pts)>.8:
        bpy.data.objects.remove(o,do_unlink=True); continue
    o.parent=None; o.matrix_world=Matrix.Identity(4)
    for v,p in zip(o.data.vertices,pts): v.co=((p.y+.53)*.05+.185,-(p.x+1.35)*.05,(p.z+.1122775)*.043+.005)
    parts.append(o)
for o in parts:
    m=o.data.materials[0] if o.data.materials else None
    col=(0.05,0.05,0.05,1)
    if m and m.node_tree:
        for n in m.node_tree.nodes:
            if n.type=='BSDF_PRINCIPLED': col=tuple(n.inputs['Base Color'].default_value)
    a=o.data.color_attributes.new('Col','FLOAT_COLOR','POINT')
    for d in a.data: d.color=col
    o.data.materials.clear()
keep=[o for o in parts if not o.name.upper().startswith('EYELET')]
for o in parts:
    if o not in keep: bpy.data.objects.remove(o,do_unlink=True)
bpy.ops.object.select_all(action='DESELECT')
for o in keep: o.select_set(True)
bpy.context.view_layer.objects.active=keep[0]
bpy.ops.object.join()
sk=bpy.context.view_layer.objects.active; sk.name='skate_L'
bm=bmesh.new(); bm.from_mesh(sk.data); bmesh.ops.remove_doubles(bm,verts=bm.verts,dist=0.0004); bm.to_mesh(sk.data); bm.free()
# same frame as night_skate_0150 + 0157: overall length 0.31, runner bottom z=-0.06, centre 0.07 forward
vs=[v.co for v in sk.data.vertices]
zmin=min(v.z for v in vs)
blade=[v for v in vs if v.z<zmin+0.012]
bx=sum(v.x for v in blade)/len(blade)
ymin=min(v.y for v in vs); ymax=max(v.y for v in vs); k=0.31/(ymax-ymin); yc=(ymin+ymax)/2
for v in sk.data.vertices:
    v.co=Vector(((v.co.x-bx)*k,(v.co.y-yc)*k-0.07,(v.co.z-zmin)*k-0.06))
ANKLE=0.0525
def cut(c): return ANKLE+max(0.0,-c.y)*0.8
def piece(name,h,below,target):
    o=sk.copy(); o.data=sk.data.copy(); o.name=name; s.collection.objects.link(o)
    bm=bmesh.new(); bm.from_mesh(o.data)
    for co,no in [((0,0,ANKLE+h),(0,0,1)),((0,0,ANKLE+h),(0,0.8,1))]:
        g=bm.verts[:]+bm.edges[:]+bm.faces[:]
        bmesh.ops.bisect_plane(bm,geom=g,plane_co=co,plane_no=Vector(no).normalized(),dist=1e-5)
    def lo(f):
        c=f.calc_center_median(); return c.z<cut(c)+h
    kill=[f for f in bm.faces if lo(f)!=below]
    bmesh.ops.delete(bm,geom=kill,context='FACES')
    loose=[v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm,geom=loose,context='VERTS')
    if below:  # tuck the boot's overlap band just inside the cuff (no z-fight)
        band=[v for v in bm.verts if v.co.z>cut(v.co)-0.005]
        cx=sum(v.co.x for v in band)/len(band); cy=sum(v.co.y for v in band)/len(band)
        for v in band:
            t=v.co.z-(cut(v.co)-0.005)
            f=1-0.05*min(1,t/0.03); v.co.x=cx+(v.co.x-cx)*f; v.co.y=cy+(v.co.y-cy)*f
    bm.to_mesh(o.data); bm.free()
    src=sum(len(p.vertices)-2 for p in o.data.polygons)
    md=o.modifiers.new('dec','DECIMATE'); md.decimate_type='COLLAPSE'; md.ratio=min(1,target/src); md.use_collapse_triangulate=True
    bpy.context.view_layer.objects.active=o; bpy.ops.object.modifier_apply(modifier='dec')
    if not below:
        for v in o.data.vertices: v.co.z-=ANKLE   # cuff origin at the ankle pivot
    return o,src
boot,bs=piece('boot_L',0.025,True,2400)
cuff,cs=piece('cuff_L',-0.005,False,600)
bpy.data.objects.remove(sk,do_unlink=True)
objs=[boot,cuff]
for o in list(objs):
    bpy.context.view_layer.objects.active=o; o.select_set(True)
    r=o.copy(); r.data=o.data.copy(); r.name=o.name[:-1]+'R'; s.collection.objects.link(r)
    for v in r.data.vertices: v.co.x=-v.co.x
    bm=bmesh.new(); bm.from_mesh(r.data); bmesh.ops.reverse_faces(bm,faces=list(bm.faces)); bm.to_mesh(r.data); bm.free()
    objs.append(r)
for o in objs:
    for p in o.data.polygons: p.use_smooth=True
rep={'src_boot_tris':bs,'src_cuff_tris':cs,'scale':k}
for o in objs:
    vs=[v.co for v in o.data.vertices]
    rep[o.name]={'tris':sum(len(p.vertices)-2 for p in o.data.polygons),'min':[round(min(v[i] for v in vs),4) for i in range(3)],'max':[round(max(v[i] for v in vs),4) for i in range(3)]}
print('SPLIT2',json.dumps(rep)); json.dump(rep,open(OUT+'/skate-v2-split-report.json','w'),indent=1)
bpy.ops.object.select_all(action='DESELECT')
for o in objs: o.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT+'/skate-v2-split.glb',use_selection=True,export_format='GLB',export_vertex_color='ACTIVE',export_all_vertex_colors=False,export_texcoords=False)
bpy.ops.wm.save_as_mainfile(filepath=OUT+'/skate-v2-split-0250.blend')
cuff.location.z=ANKLE
for o in objs: o.hide_render=o.name.endswith('R')
s.render.engine='BLENDER_WORKBENCH'; s.display.shading.light='STUDIO'; s.display.shading.color_type='VERTEX'; s.display.shading.show_cavity=True
s.render.resolution_x,s.render.resolution_y=800,600
cd=bpy.data.cameras.new('NC'); cd.type='ORTHO'; cd.ortho_scale=0.42
cam=bpy.data.objects.new('NC',cd); s.collection.objects.link(cam); s.camera=cam
def view(d,path):
    d=Vector(d).normalized(); cam.location=Vector((0,-0.07,0.09))+d*2; cam.rotation_euler=(-d).to_track_quat('-Z','Y').to_euler()
    s.render.filepath=path; bpy.ops.render.render(write_still=True)
view((1,0,0),OUT+'/skate-v2-split-side.png')
view((1,-0.8,0.5),OUT+'/skate-v2-split-three_q.png')
cuff.location.z=ANKLE+0.08; view((1,0,0),OUT+'/skate-v2-split-exploded.png')
print('NIGHT_SKATE_V2_OK')
