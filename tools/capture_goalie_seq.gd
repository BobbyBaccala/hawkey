extends SceneTree
## Goalie drop/recovery contact sheet: the same goalie posed at fixed butterfly
## amounts (0, .25, .5, .75, 1 down, then .5 and 0 back up), each from the
## front-three-quarter and the side, plus left/right pad saves. Fixed cameras,
## FOV, lighting and team so before/after sheets compare directly.
## Writes <out>-<view>-<k>.png and <out>-sheet.png (default /tmp/hawkey-gseq).
## Options: --out=<prefix> --clay (neutral grey materials to judge shape)
## xvfb-run -a -s "-screen 0 1728x1080x24" godot --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1728x1080 --script tools/capture_goalie_seq.gd
func _initialize()->void:call_deferred("run")

func clay(node: Node, mat: Material) -> void:
	if node is MeshInstance3D: (node as MeshInstance3D).material_override = mat
	for c in node.get_children(): clay(c, mat)

func run()->void:
	var out:="/tmp/hawkey-gseq"
	var use_clay:="--clay" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):out=arg.substr(6)
	var scene=load("res://practice.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene.set_physics_process(false)
	for actor in [scene.player,scene.teammate]+scene.goalkeepers:actor.queue_free()
	scene.puck.visible=false
	scene.selection.visible=false
	scene.hud.get_parent().get_parent().visible=false
	var v=load("res://scripts/skater_visual.gd").new()
	v.goalie=true
	v.kit=Color("#b3162c")
	v.accent=Color("#1b2a4a")
	v.number="31"
	v.nameplate_text="HOLT"
	scene.add_child(v)
	v.rotation.y=PI
	if use_clay:
		var m:=StandardMaterial3D.new()
		m.albedo_color=Color(0.72,0.72,0.72)
		m.roughness=0.8
		clay(v,m)
	# [label, butterfly, save kind, target]
	var poses:=[["0",0.0,"",Vector2(0,0.8)],["25",0.25,"",Vector2(0,0.8)],["50",0.5,"",Vector2(0,0.8)],["75",0.75,"",Vector2(0,0.8)],["100",1.0,"",Vector2(0,0.8)],
		["up50",0.5,"",Vector2(0,0.8)],["up0",0.0,"",Vector2(0,0.8)],["padL","pad_left",Vector2(0.9,0.1)],["padR","pad_right",Vector2(-0.9,0.1)]]
	var views:=[["tq",Vector3(1.2,0.75,1.7),Vector3(0,0.42,0),46.0],["side",Vector3(2.0,0.55,0.15),Vector3(0,0.42,0),44.0]]
	var tiles:=[]
	for p in poses:
		var kind:String=p[2] if p.size()>3 else ""
		var target:Vector2=p[3] if p.size()>3 else p[2]
		var bf:float=p[1] if p[1] is float else 0.0
		if p.size()==3:
			kind=String(p[1])
			target=p[2]
			bf=0.0
		for k in range(45):
			v.butterfly=bf
			v.set_save(kind,target,1.0/60)
			v.animate(0,1.0/60,0,false)
		for w in views:
			scene.camera.position=w[1]
			scene.camera.look_at(w[2])
			scene.camera.fov=w[3]
			for f in range(3):
				await process_frame
			await RenderingServer.frame_post_draw
			var img:=get_root().get_texture().get_image()
			img.resize(576,360)
			tiles.append([String(p[0])+" "+String(w[0]),img])
	var cols:=6
	var rows:=int(ceil(tiles.size()/float(cols)))
	var sheet:=Image.create(576*cols,360*rows,false,Image.FORMAT_RGBA8)
	for t in range(tiles.size()):
		var img:Image=tiles[t][1]
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img,Rect2i(0,0,576,360),Vector2i((t%cols)*576,(t/cols)*360))
	sheet.save_png(out+"-sheet.png")
	var order:=PackedStringArray()
	for t in tiles: order.append(t[0])
	print("TILES ", ", ".join(order))
	quit()
