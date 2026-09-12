extends SceneTree
func _initialize() -> void:call_deferred("run")
func capture(path:String) -> void:
	for i in 15:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/"+path+".png")
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
	camera.position=center+Vector3(48,22,68)
	camera.look_at(center+Vector3(0,4,0))
	await capture("continental-town")
	for gender in 2:
		g.player.apply_profile({"gender":gender})
		g.player.position=center+Vector3(0,.4,18)
		g.player.visual.rotation.y=0
		camera.position=g.player.position+Vector3(2.6,1.9,-3.8)
		camera.look_at(g.player.position+Vector3(0,1.1,0))
		for clip in ["idle","slash_a","roll","cast","sit","hurt","death"]:
			g.player.rig.position.y=g.player.saddle_height() if clip=="sit" else 0.0
			g.player.rig.pose(clip,.5,0,0)
			if clip=="sit":
				g.player.rig.riding_pose(0,.2)
				g.horse.position=g.player.position
				g.horse.rotation.y=0
			else:g.horse.position=center+Vector3(50,0,0)
			await capture("continental-%d-%s"%[gender,clip])
	var dungeon:Dictionary=WorldAtlas.dungeons[0]
	for foe in g.enemies:
		if foe.home.distance_to(dungeon.center)<80:foe.ensure_visual()
	g.player.position=dungeon.center+Vector3(0,.4,65)
	g.world.stream.update_centers([dungeon.center],true)
	camera.position=dungeon.center+Vector3(6,3,48)
	camera.look_at(dungeon.center+Vector3(0,2,4))
	await capture("continental-dungeon")
	g.set_mode("map")
	await capture("continental-map")
	g.set_mode("character")
	await capture("continental-creation")
	FileAccess.open("res://art/continental-runtime.json",FileAccess.WRITE).store_string(JSON.stringify({"unique_models":PublicAssets.used.size(),"used":PublicAssets.used,"npcs":g.npcs.size(),"enemies":g.enemies.size()},"  "))
	quit()
