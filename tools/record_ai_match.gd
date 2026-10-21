extends SceneTree
## Continuous production match. Movie Maker advances fixed simulation frames;
## no forced goals, staged passes or puck teleports. The configured warm-up frames are
## removed during encoding, leaving one uninterrupted minute of actual AI play.
const Match=preload("res://scripts/match.gd")
const Settings=preload("res://scripts/game_settings.gd")
var match_scene
var frames:=0
var warmup:=150
var samples: Array=[]
var output_prefix:="res://build/ai-gameplay"
var source_sha:=""
var size:=Vector2i(960,600)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--prefix="): output_prefix=arg.trim_prefix("--prefix=")
		if arg.begins_with("--source-sha="): source_sha=arg.trim_prefix("--source-sha=")
		if arg.begins_with("--warmup-frames="): warmup=int(arg.trim_prefix("--warmup-frames="))
	root.size=size;root.content_scale_size=size
	root.msaa_3d=Viewport.MSAA_DISABLED
	root.screen_space_aa=Viewport.SCREEN_SPACE_AA_DISABLED
	RenderingServer.directional_shadow_atlas_set_size(1024,true)
	DirAccess.make_dir_recursive_absolute("res://build")
	Settings.path="res://build/ai-video-settings.json"
	Match.skip_title=true;Match.return_to_title=false
	seed(42)
	match_scene=load("res://main.tscn").instantiate()
	match_scene.ai_vs_ai=true
	root.add_child(match_scene);current_scene=match_scene
	if match_scene.skaters.size()!=10 or match_scene.hud_node==null:
		push_error("Recording aborted: match did not initialize")
		quit(1);return
	match_scene.set_process_unhandled_input(false)
	for sun in match_scene.find_children("*","DirectionalLight3D",true,false):
		if sun.shadow_enabled:
			sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			sun.directional_shadow_blend_splits=false
	match_scene.camera_mode=2
	match_scene.set_paused(true)
	process_frame.connect(record_tick)
	print("AI_VIDEO_READY ",Engine.get_version_info().string," ",RenderingServer.get_video_adapter_name())
func record_tick() -> void:
	frames+=1
	if frames==warmup:
		match_scene.set_paused(false)
		print("AI_VIDEO_START: continuous computer-controlled match")
	if frames<warmup: return
	var recorded:=frames-warmup
	if recorded%30==0:
		var ai_count:=0
		for actor in match_scene.skaters:
			if actor.has_meta("tactical_target"): ai_count+=1
		samples.append({"second":float(recorded)/30,"clock":match_scene.match_state.clock,"phase":match_scene.match_state.phase,"score":match_scene.match_state.score.duplicate(),"puck":[match_scene.puck.position.x,match_scene.puck.position.y,match_scene.puck.position.z],"ai_actors_with_targets":ai_count,"roster_shots":match_scene.rosters.map(func(team): return team.reduce(func(total,person): return total+int(person.shots),0))})
	if recorded%150==0:
		print("AI_VIDEO_PROGRESS ",recorded/30,"s; clock ",match_scene.match_state.clock_text()," score ",match_scene.match_state.score)
		write_metadata()
	if recorded in [90,900,1770]: call_deferred("save_preview",recorded/30)
func save_preview(second: int) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg(output_prefix+"-%02ds.jpg"%second,0.94)
func write_metadata() -> void:
	var metadata:={"source_sha":source_sha,"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_video_adapter_name(),"capture_profile":"960x600, no MSAA or screen AA; 1024px two-split key shadows. Production models, arena, lights and physics preserved.","output_fps":30,"warmup_frames":warmup,"render_frames_seen":frames,"ai_vs_ai":match_scene.ai_vs_ai,"camera":"Production Broadcast camera","simulation":"Normal production rules, skating, puck, goalie and team AI; no forced game events. Normal match clock_rate=4.0.","rendering":"Fixed-frame offline Movie Maker render; output FPS is not measured real-time hardware performance.","samples":samples}
	FileAccess.open(output_prefix+".json",FileAccess.WRITE).store_string(JSON.stringify(metadata,"\t"))
