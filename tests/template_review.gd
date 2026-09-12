extends SceneTree

func _initialize() -> void:
	call_deferred("review")

func review() -> void:
	var stage=Node3D.new()
	root.add_child(stage)
	var environment=WorldEnvironment.new()
	var env=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("859ba9")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("d5e3f1")
	env.ambient_light_energy=0.7
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	environment.environment=env
	stage.add_child(environment)
	var light=DirectionalLight3D.new()
	stage.add_child(light)
	light.rotation_degrees=Vector3(-45,-25,0)
	light.light_energy=1.1
	Art.box(stage,Vector3(0,-0.06,0),Vector3(15,0.1,8),Color("c4cfd0"))
	var camera=Camera3D.new()
	stage.add_child(camera)
	camera.current=true
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=3.25
	camera.position=Vector3(0,2.3,-9)
	camera.look_at(Vector3(0,1.1,0))
	var chars=[]
	var names=["vivi_rigged","citizen_rigged","hero_rigged","warden_rigged","victoria_rigged"]
	for i in names.size():
		var ch=Art.character(stage,names[i])
		ch.position.x=(i-2)*1.2
		ch.pose("idle" if i in [2,3] else "relax",0.2,0,0)
		if i in [2,3]:Art.sword(ch.socket("ArmR"),i==3)
		chars.append(ch)
	print("CLIPS: ",chars[2].clips)
	print("HAND: ",chars[2].socket("ArmR").global_basis)
	await create_timer(2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/template-lineup.png")
	for i in chars.size():chars[i].visible=i==2
	camera.size=2.3
	camera.position=Vector3(2,1.7,-4)
	camera.look_at(Vector3(0,0.95,0))
	for clip in ["idle","slash_a","slash_b","slash_c","heavy","roll"]:
		for i in [1,2,3]:
			chars[2].pose(clip,i*0.25,0,0)
			await create_timer(0.12).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://screenshots/pose-"+clip+str(i)+".png")
	print("TEMPLATE REVIEW COMPLETE")
	quit()
