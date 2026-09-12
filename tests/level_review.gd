extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var g=load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await process_frame
	g.test_mode=true
	g.set_mode("play")
	for foe in g.enemies:foe.set_physics_process(false)
	g.player.set_physics_process(false)
	g.player.load_progress({"level":5,"experience":210})
	g.player.restore()
	for i in 30:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/level-system.png")
	quit()
