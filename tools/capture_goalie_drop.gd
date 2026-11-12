extends SceneTree
## Continuous goalie drop and recovery, sampled from the live per-frame update
## (no settling between samples): butterfly moves at the match's own rates
## (match.gd: down 6/s, up 2/s), the pose updates every 1/60 s, and a frame is
## grabbed every STEP updates from a fixed side-three-quarter camera. Writes
## <out>-strip.png (time order left to right, top to bottom) and prints the
## largest per-frame jump of the pad, thigh rise and skate (pops show here).
## Options: --out=<prefix> --clay
## xvfb-run -a -s "-screen 0 1728x1080x24" godot --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1728x1080 --script tools/capture_goalie_drop.gd
const STEP := 4
func _initialize()->void:call_deferred("run")

func clay(node: Node, mat: Material) -> void:
	if node is MeshInstance3D: (node as MeshInstance3D).material_override = mat
	for c in node.get_children(): clay(c, mat)

func marks(v) -> Array:
	var out := []
	for i in range(2):
		out.append(v.pad_visuals[i].global_transform * Vector3(0, -0.3, 0.05))
		out.append(v.thigh_rises[i].global_transform * Vector3(0, 0.3, 0))
		out.append(v.skates[i].global_transform * Vector3(0, 0, 0.15))
		out.append(v.rig.global_transform * (v.skeleton.transform * Vector3(v.knees[i])))
	return out
const MARK_NAMES := ["pad bottom L","rise top L","skate toe L","knee L","pad bottom R","rise top R","skate toe R","knee R"]

func run()->void:
	var out:="/tmp/hawkey-gdrop"
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
	scene.add_child(v)
	v.rotation.y=PI
	if "--clay" in OS.get_cmdline_user_args():
		var m:=StandardMaterial3D.new()
		m.albedo_color=Color(0.72,0.72,0.72)
		clay(v,m)
	scene.camera.position=Vector3(1.25,0.8,1.65)
	scene.camera.look_at(Vector3(0,0.42,0))
	scene.camera.fov=46.0
	for k in range(30):
		v.set_save("",Vector2(0,0.8),1.0/60)
		v.animate(0,1.0/60,0,false)
	var tiles:=[]
	var prev:=marks(v)
	var worst:=0.0
	var worst_at:=""
	var per:=[0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0]
	var frame:=0
	# Down at 6/s, hold 0.25 s, up at 2/s, hold.
	var plan:=[[1.0,6.0,20],[1.0,0.0,15],[0.0,2.0,40],[0.0,0.0,8]]
	for leg in plan:
		for k in range(int(leg[2])):
			if leg[1]>0.0: v.butterfly=move_toward(v.butterfly,leg[0],leg[1]/60.0)
			v.set_save("",Vector2(0,0.8),1.0/60)
			v.animate(0,1.0/60,0,false)
			var now:=marks(v)
			for j in range(now.size()):
				var d:float=(now[j] as Vector3).distance_to(prev[j])
				per[j]=maxf(per[j],d)
				if d>worst:
					worst=d
					worst_at="frame %d butterfly %.2f %s" % [frame,v.butterfly,MARK_NAMES[j]]
			prev=now
			if frame%STEP==0:
				await process_frame
				await RenderingServer.frame_post_draw
				var img:=get_root().get_texture().get_image()
				img.resize(432,270)
				img.convert(Image.FORMAT_RGBA8)
				tiles.append(img)
			frame+=1
	var cols:=6
	var rows:=int(ceil(tiles.size()/float(cols)))
	var sheet:=Image.create(432*cols,270*rows,false,Image.FORMAT_RGBA8)
	for t in range(tiles.size()):
		sheet.blit_rect(tiles[t],Rect2i(0,0,432,270),Vector2i((t%cols)*432,(t/cols)*270))
	sheet.save_png(out+"-strip.png")
	for j in range(per.size()): print("  max step %-13s %.3f m" % [MARK_NAMES[j], per[j]])
	print("FRAMES ",frame," TILES ",tiles.size()," LARGEST_STEP %.4f m at %s" % [worst,worst_at])
	quit()
