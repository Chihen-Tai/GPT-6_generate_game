extends RefCounted
func run(g: Node3D) -> void:
	var n=g.net
	if n.dedicated:
		for i in 200:
			if n.avatars.size()>=2:break
			await g.get_tree().create_timer(0.1).timeout
		if n.avatars.size()<2:g.get_tree().quit(1);return
		var index=0
		for actor in n.avatars.values():
			actor.position=Vector3(-1.7 if index==0 else 1.7,0.3,-101)
			actor.visual.rotation.y=0
			actor.invulnerable=40
			index+=1
		g.boss.position=Vector3(0,0.3,-106)
		g.boss.visual.rotation.y=PI
		g.boss.engaged=true
		n.test_phase="review"
		await g.get_tree().create_timer(12).timeout
		g.get_tree().quit()
		return
	for i in 180:
		if n.online and n.test_phase=="review":break
		await g.get_tree().create_timer(0.1).timeout
	g.menu_camera.position=Vector3(7,4.6,-97)
	g.menu_camera.look_at(Vector3(0,1.4,-104))
	g.menu_camera.current=true
	g.toast_time=0
	if n.nickname=="青葉":
		n.request("cast",4)
		await g.get_tree().create_timer(0.45).timeout
	else:
		await g.get_tree().create_timer(0.4).timeout
		n.request("cast",6)
	await g.get_tree().create_timer(0.8).timeout
	if n.nickname=="青葉":
		await RenderingServer.frame_post_draw
		g.get_viewport().get_texture().get_image().save_png("res://screenshots/multiplayer-coop.png")
		n.request("roll")
	await g.get_tree().create_timer(1.0).timeout
	n.request("attack")
	await g.get_tree().create_timer(0.7).timeout
	n.request("cast",8 if n.nickname=="青葉" else 0)
	await g.get_tree().create_timer(1.5).timeout
	if n.nickname=="青葉":
		await RenderingServer.frame_post_draw
		g.get_viewport().get_texture().get_image().save_png("res://screenshots/multiplayer-boss.png")
	await g.get_tree().create_timer(1.2).timeout
	print("NETWORK REVIEW COMPLETE")
	g.get_tree().quit()
