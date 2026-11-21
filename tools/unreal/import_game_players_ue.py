"""Hawkey: import the in-game players (Godot export -> Blender FBX) into the Unreal
project, place them in the v3 studio beside Codex's reference hero, render a check."""
import unreal as u, os, sys, time
R = 'C:/Users/lange/Documents/Hawkey'
SRC = R + '/art/game-export/fbx'
OUT = R + '/art/previews/game-export'
os.makedirs(OUT, exist_ok=True)
sys.path.append(R + '/unreal/Content/Python')
from hawkey_materials import material
tools = u.AssetToolsHelpers.get_asset_tools()
lib = u.MaterialEditingLibrary
levels = u.get_editor_subsystem(u.LevelEditorSubsystem)
actors = u.get_editor_subsystem(u.EditorActorSubsystem)
assert levels.load_level('/Game/Hawkey/Maps/HawkeyReference_v3')
world = u.get_editor_subsystem(u.UnrealEditorSubsystem).get_editor_world()
u.SystemLibrary.execute_console_command(world, 'Interchange.FeatureFlags.Import.FBX 0')
DEST = '/Game/Hawkey/GameExport'

def vc_material(name, rough=0.55):
    """Substrate slab whose base colour is the mesh's vertex colour."""
    path = DEST + '/' + name
    m = u.load_asset(path) or tools.create_asset(name, DEST, u.Material, u.MaterialFactoryNew())
    lib.delete_all_material_expressions(m)
    slab = lib.create_material_expression(m, u.MaterialExpressionSubstrateShadingModels)
    vc = lib.create_material_expression(m, u.MaterialExpressionVertexColor)
    # Godot writes the kit colours as sRGB numbers: decode to linear here.
    pw = lib.create_material_expression(m, u.MaterialExpressionPower)
    pw.set_editor_property('const_exponent', 2.2)
    assert lib.connect_material_expressions(vc, '', pw, 'Base')
    assert lib.connect_material_expressions(pw, '', slab, 'BaseColor')
    lib.connect_material_property(pw, '', u.MaterialProperty.MP_BASE_COLOR)
    for pin, val, prop in (('Roughness', rough, u.MaterialProperty.MP_ROUGHNESS), ('Specular', .35, u.MaterialProperty.MP_SPECULAR)):
        n = lib.create_material_expression(m, u.MaterialExpressionConstant); n.set_editor_property('r', val)
        assert lib.connect_material_expressions(n, '', slab, pin); lib.connect_material_property(n, '', prop)
    assert lib.connect_material_property(slab, '', u.MaterialProperty.MP_FRONT_MATERIAL)
    lib.recompile_material(m); u.EditorAssetLibrary.save_loaded_asset(m, False)
    return m

vc = vc_material('M_GameExport_VertexColour')
# Face: the game's scanned-head base colour.
t = u.AssetImportTask(); t.filename = SRC + '/T_hawkey_skater_face.png'; t.destination_path = '/Game/Hawkey/Textures'
t.destination_name = 'T_GameExport_Face'; t.automated = True; t.replace_existing = True; t.save = True
tools.import_asset_tasks([t])
face = material('GameExport_Face', (.6, .45, .38), .6, base_color_texture='T_GameExport_Face')
visor = u.load_asset('/Game/Hawkey/Materials/Hawkey_Visor') or material('Hawkey_Visor', (.6, .72, .8), .1)

meshes = {}
for name in ('hawkey_skater', 'hawkey_skater_away', 'hawkey_goalie'):
    t = u.AssetImportTask(); t.filename = SRC + '/' + name + '.fbx'; t.destination_path = DEST
    t.destination_name = 'SM_' + name; t.automated = True; t.replace_existing = True; t.save = True
    t.factory = u.FbxFactory()
    opt = u.FbxImportUI(); opt.import_mesh = True; opt.import_as_skeletal = False; opt.import_materials = False; opt.import_textures = False
    opt.set_editor_property('automated_import_should_detect_type', False); opt.mesh_type_to_import = u.FBXImportType.FBXIT_STATIC_MESH
    opt.static_mesh_import_data.combine_meshes = True; opt.static_mesh_import_data.generate_lightmap_u_vs = False
    opt.static_mesh_import_data.auto_generate_collision = False
    opt.static_mesh_import_data.vertex_color_import_option = u.VertexColorImportOption.REPLACE
    t.options = opt; tools.import_asset_tasks([t])
    mesh = next(a for a in t.get_objects() if isinstance(a, u.StaticMesh))
    slots = mesh.get_editor_property('static_materials')
    names = []
    for i, slot in enumerate(slots):
        sname = str(slot.material_slot_name); names.append(sname)
        mesh.set_material(i, face if 'FACE' in sname else (visor if 'VISOR' in sname else vc))
    u.EditorAssetLibrary.save_loaded_asset(mesh, False)
    b = mesh.get_bounds()
    u.log('GX_UE_MESH %s slots %d extent %s' % (name, len(slots), str(b.box_extent)))
    meshes[name] = mesh

# Place them beside the v3 hero (or the origin), facing the capture camera.
hero = next((a for a in actors.get_all_level_actors() if a.get_actor_label() == 'Hawkey v3 / rigged hero'), None)
base = hero.get_actor_location() if hero else u.Vector(0, 0, 0)
for a in actors.get_all_level_actors():
    if a.get_actor_label().startswith('Hawkey game / '):
        actors.destroy_actor(a)
placed = []
for i, name in enumerate(('hawkey_skater', 'hawkey_skater_away', 'hawkey_goalie')):
    loc = u.Vector(base.x + 105 + i * 105, base.y, base.z)
    a = actors.spawn_actor_from_class(u.StaticMeshActor, loc, u.Rotator(0, 0, 0))
    a.set_actor_label('Hawkey game / ' + name)
    a.static_mesh_component.set_static_mesh(meshes[name])
    origin, extent = a.get_actor_bounds(False)
    a.set_actor_location(u.Vector(loc.x, loc.y, loc.z + (loc.z - (origin.z - extent.z))), False, False)  # feet on the floor
    placed.append(a)
levels.save_current_level()
mid = u.Vector(base.x + 150, base.y, base.z + 92)

SCRIPT_FILE = __file__; START = time.monotonic(); FRAME = 0; CB = None
u.EditorPythonScripting.set_keep_python_script_alive(True)
def capture(tag, cam_loc):
    a = actors.spawn_actor_from_class(u.SceneCapture2D, cam_loc, u.MathLibrary.find_look_at_rotation(cam_loc, mid))
    c = a.get_component_by_class(u.SceneCaptureComponent2D)
    rt = u.RenderingLibrary.create_render_target2d(world, 1600, 1000, u.TextureRenderTargetFormat.RTF_RGBA8)
    c.set_editor_property('texture_target', rt); c.set_editor_property('capture_source', u.SceneCaptureSource.SCS_FINAL_COLOR_LDR)
    c.set_editor_property('fov_angle', 42)
    flags = []
    for n in ('Materials', 'Lighting', 'PostProcessing', 'Tonemapper', 'Fog'):
        f = u.EngineShowFlagsSetting(); f.set_editor_property('show_flag_name', n); f.set_editor_property('enabled', True); flags.append(f)
    c.set_editor_property('show_flag_settings', flags)
    c.capture_scene()
    u.RenderingLibrary.export_render_target(world, rt, OUT, 'unreal-game-players-%s.png' % tag)
    actors.destroy_actor(a)
def tick(delta):
    global FRAME
    FRAME += 1
    if time.monotonic() - START < 10 or FRAME < 40:
        return
    try:
        capture('front', u.Vector(mid.x, mid.y - 560, mid.z + 25))
        capture('three-q', u.Vector(mid.x + 330, mid.y - 450, mid.z + 35))
        u.log('HAWKEY_GX_UE_OK ' + str(FRAME))
    finally:
        u.unregister_slate_post_tick_callback(CB); u.EditorPythonScripting.set_keep_python_script_alive(False)
CB = u.register_slate_post_tick_callback(tick)
