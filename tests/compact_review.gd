extends SceneTree
func _initialize() -> void:call_deferred("run")
func capture(file:String) -> void:
	for i in 20:await process_frame
	root.get_child(root.get_child_count()-1).toast_time=0
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/"+file+".png")
func run() -> void:
	var g=load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await process_frame
	g.test_mode=true
	g.set_mode("play")
	for foe in g.enemies:foe.set_physics_process(false)
	g.player.set_physics_process(false)
	var camera=Camera3D.new()
	g.add_child(camera)
	camera.current=true
	camera.far=650
	var center:Vector3=WorldAtlas.settlements[0].center
	g.player.position=center+Vector3(0,.4,18)
	g.world.stream.update_centers([center],true)
	camera.position=center+Vector3(80,40,95)
	camera.look_at(center+Vector3(0,2,0))
	await capture("compact-town")
	center=WorldAtlas.camps[0].center
	g.player.position=center+Vector3(0,.4,14)
	g.world.stream.update_centers([center],true)
	camera.position=center+Vector3(16,8,25)
	camera.look_at(center+Vector3(0,1,-2))
	await capture("compact-roadside")
	g.hud.atlas_view=true
	g.set_mode("map")
	await capture("compact-map")
	quit()
