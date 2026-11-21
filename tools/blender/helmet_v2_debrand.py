import bpy, bmesh, json, math
from mathutils import Vector, Matrix
R='C:/Users/lange/Documents/Hawkey'; OUT=R+'/art/night/helmet'
# Item 3 slice 2: strip every texture (Capitals wordmark/logo, NHL shield, maker marks, "8", signature),
# rebuild as vertex colours (white = team-colour shell mask, darks = trim/straps), clear visor separate,
# reorient (front -> Blender -Y = Godot +Z), scale to metres, decimate opaque <= 2.7k tris.
bpy.ops.wm.read_factory_settings(use_empty=True)
s=bpy.context.scene
bpy.ops.import_scene.gltf(filepath=R+'/art/incoming/hockey_helmet_washington_capitals.glb')
ROLE={'defaultMaterial':'shell','defaultMaterial.001':'shell','defaultMaterial.005':'shell',
      'defaultMaterial.002':'trim','defaultMaterial.004':'pad','defaultMaterial.003':'visor',
      'defaultMaterial.007':'hw','defaultMaterial.011':'hw','defaultMaterial.012':'hw',
      'defaultMaterial.006':'hw','defaultMaterial.008':'hw','defaultMaterial.009':'strap','defaultMaterial.010':'strap'}
COL={'shell':(1,1,1,1),'trim':(0.06,0.065,0.07,1),'pad':(0.12,0.12,0.13,1),'hw':(0.18,0.19,0.2,1),'strap':(0.04,0.04,0.045,1),'visor':(0.85,0.9,0.95,1)}
M=Matrix.Rotation(-math.pi/2,4,'Z')
opaque=[]; visor=[]
for o in [o for o in s.objects if o.type=='MESH']:
    role=ROLE.get(o.name,'hw')
    pts=[M@(o.matrix_world@v.co) for v in o.data.vertices]
    o.parent=None; o.matrix_world=Matrix.Identity(4)
    for v,p in zip(o.data.vertices,pts): v.co=p
    a=o.data.color_attributes.new('Col','FLOAT_COLOR','POINT')
    for d in a.data: d.color=COL[role]
    o.data.materials.clear()
    for uv in list(o.data.uv_layers): o.data.uv_layers.remove(uv)
    (visor if role=='visor' else opaque).append(o)
for im in list(bpy.data.images): bpy.data.images.remove(im)
def join(objs,name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active=objs[0]; bpy.ops.object.join()
    o=bpy.context.view_layer.objects.active; o.name=name; return o
shell=join(opaque,'helmet_shell'); vis=join(visor,'helmet_visor')
# metres: shell front-back length -> 0.27 m (adult helmet); origin at the shell's centre at brow height
vs=[v.co for v in shell.data.vertices]
L=max(v.y for v in vs)-min(v.y for v in vs); k=0.27/L
sh=[v.co for v in shell.data.vertices if v.co.z>-0.35]
c=Vector(((max(v.x for v in sh)+min(v.x for v in sh))/2,(max(v.y for v in sh)+min(v.y for v in sh))/2,min(v.z for v in sh)))
for o in (shell,vis):
    for v in o.data.vertices: v.co=(v.co-c)*k
    bm=bmesh.new(); bm.from_mesh(o.data); bmesh.ops.remove_doubles(bm,verts=bm.verts,dist=0.0002); bm.to_mesh(o.data); bm.free()
src=sum(len(p.vertices)-2 for p in shell.data.polygons)
md=shell.modifiers.new('dec','DECIMATE'); md.decimate_type='COLLAPSE'; md.ratio=min(1,2700/src); md.use_collapse_triangulate=True
bpy.context.view_layer.objects.active=shell; bpy.ops.object.modifier_apply(modifier='dec')
for o in (shell,vis):
    for p in o.data.polygons: p.use_smooth=True
rep={'scale':k,'src_opaque_tris':src}
for o in (shell,vis):
    vs=[v.co for v in o.data.vertices]
    rep[o.name]={'tris':sum(len(p.vertices)-2 for p in o.data.polygons),'min':[round(min(v[i] for v in vs),4) for i in range(3)],'max':[round(max(v[i] for v in vs),4) for i in range(3)]}
json.dump(rep,open(OUT+'/helmet-v2-report.json','w'),indent=1); print('HELMET2',json.dumps(rep))
bpy.ops.object.select_all(action='DESELECT'); shell.select_set(True); vis.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT+'/helmet-v2.glb',use_selection=True,export_format='GLB',export_vertex_color='ACTIVE',export_all_vertex_colors=False,export_texcoords=False)
bpy.ops.wm.save_as_mainfile(filepath=OUT+'/helmet-v2-0302.blend')
# preview with a team colour on the shell mask
for d in shell.data.color_attributes['Col'].data:
    if d.color[0]>0.9: d.color=(0.09,0.36,0.45,1)
s.render.engine='BLENDER_WORKBENCH'; s.display.shading.light='STUDIO'; s.display.shading.color_type='VERTEX'; s.display.shading.show_cavity=True
s.render.resolution_x,s.render.resolution_y=600,600
cd=bpy.data.cameras.new('NC'); cd.type='ORTHO'; cd.ortho_scale=0.42
cam=bpy.data.objects.new('NC',cd); s.collection.objects.link(cam); s.camera=cam
for name,d in {'front':(0,-1,0.15),'side':(1,0,0.1),'back':(0,1,0.15),'three_q':(1,-1,0.45),'top':(0,0.01,1)}.items():
    d=Vector(d).normalized(); cam.location=Vector((0,0,0.0))+d*2; cam.rotation_euler=(-d).to_track_quat('-Z','Y').to_euler()
    s.render.filepath=OUT+'/helmet-v2-'+name+'.png'; bpy.ops.render.render(write_still=True)
print('NIGHT_HELMET_DEBRAND_OK')
