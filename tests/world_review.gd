extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_mode("play")
	for foe in game.enemies:foe.set_physics_process(false)
	game.player.set_physics_process(false)
	var camera=Camera3D.new()
	game.add_child(camera)
	camera.far=650
	camera.fov=65
	camera.current=true
	var shots=[[Vector3(29,14,53),Vector3(0,4,9)],[Vector3(185,22,33),Vector3(145,4,-20)],[Vector3(-87,30,-45),Vector3(-135,8,-124)],[Vector3(150,28,-151),Vector3(103,5,-210)],[Vector3(14,7,-298),Vector3(0,3,-313)]]
	for i in shots.size():
		game.player.position=AureliaWorld.REGIONS[i].center+Vector3(0,.3,5)
		camera.position=shots[i][0]
		camera.look_at(shots[i][1])
		for frame in 20:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://screenshots/expansion-region-%d.png" % (i+1))
	game.player.position=AureliaWorld.ARENA+Vector3(0,.3,10)
	game.player.visual.rotation.y=0
	game.player.locked_target=game.boss
	game.player.spell_page=2
	game.boss.engaged=true
	game.boss.phase=3
	game.boss.hp=900
	game.boss.visual.rotation.y=PI
	game.boss.rig.pose("heavy",.38,0,0)
	game.player.rig.pose("cast",.4,0,0)
	camera.position=AureliaWorld.ARENA+Vector3(12,7,19)
	camera.look_at(AureliaWorld.ARENA+Vector3(0,2,0))
	game.magic.cast(11)
	await create_timer(.85).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/expansion-boss-magic.png")
	game.set_mode("map")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/expansion-map.png")
	var report={"regions":5,"npcs":game.npcs.size(),"enemies":game.enemies.size(),"used_unique_models":PublicAssets.used.size(),"instances":PublicAssets.used,"bounds":{}}
	for key in PublicAssets.bounds:report.bounds[key]=str(PublicAssets.bounds[key])
	FileAccess.open("res://art/expansion-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	quit()
