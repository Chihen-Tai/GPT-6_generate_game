extends RefCounted

func run(g: Node3D) -> void:
	await g.get_tree().create_timer(2).timeout
	g.set_mode("play")
	g.toast_time=0
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	for e in g.enemies:
		e.set_physics_process(false)
		e.position=Vector3(75,0.3,65)
		e.max_hp=100000
		e.hp=100000
		e.visual.rotation.y=PI
	g.enemies[0].position=Vector3(0,0.3,-108)
	g.enemies[1].position=Vector3(3,0.3,-110)
	g.enemies[2].position=Vector3(-3,0.3,-109)
	g.player.position=Vector3(0,0.4,-98)
	g.player.visual.rotation=Vector3.ZERO
	g.player.locked_target=g.enemies[0]
	g.menu_camera.position=Vector3(10,7,-89)
	g.menu_camera.look_at(Vector3(0,1.6,-104))
	g.menu_camera.current=true
	for shot in [[4,0.4,"lightning"],[5,0.83,"meteor"],[6,1.0,"frost"],[8,0.44,"swords"],[9,0.79,"beam"],[11,0.98,"ultimate"]]:
		g._clear_effects()
		g.player.restore()
		g.player.locked_target=g.enemies[0]
		g.player.spell_page=int(shot[0])/4
		g.player.cast_slot(int(shot[0])%4)
		await g.get_tree().create_timer(shot[1]).timeout
		await RenderingServer.frame_post_draw
		g.get_viewport().get_texture().get_image().save_png("res://screenshots/magic-"+shot[2]+".png")
		if "--magic-movie" in OS.get_cmdline_user_args():
			await g.get_tree().create_timer(2.4-shot[1]).timeout
	g.set_mode("spellbook")
	await g.get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	g.get_viewport().get_texture().get_image().save_png("res://screenshots/magic-spellbook.png")
	if "--magic-movie" in OS.get_cmdline_user_args():
		await g.get_tree().create_timer(1.5).timeout
	g._clear_effects()
	# Let the offline movie audio mixer release its looping WAV playback.
	for child in g.get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream=null
	await g.get_tree().create_timer(0.15).timeout
	print("MAGIC CAPTURE COMPLETE")
	g.get_tree().quit()
