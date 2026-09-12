extends RefCounted

var caption: Label
func shot(g: Node3D, title: String, camera_pos: Vector3, focus: Vector3) -> void:
	caption.text=title
	g.menu_camera.position=camera_pos
	g.menu_camera.look_at(focus)
	g.menu_camera.current=true

func wait(g: Node3D, seconds: float) -> void:
	await g.get_tree().create_timer(seconds).timeout

func snap(g: Node3D, name: String) -> void:
	await RenderingServer.frame_post_draw
	g.get_viewport().get_texture().get_image().save_png("res://screenshots/"+name+".png")

func run(g: Node3D) -> void:
	await wait(g,1.5)
	g.set_mode("play")
	g.toast_time=0
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var canvas=CanvasLayer.new()
	g.add_child(canvas)
	caption=Label.new()
	canvas.add_child(caption)
	caption.position=Vector2(370,110)
	caption.add_theme_font_size_override("font_size",26)
	caption.add_theme_color_override("font_color",Color("fff0c5"))
	caption.add_theme_color_override("font_shadow_color",Color("183541"))
	caption.add_theme_constant_override("shadow_offset_x",2)
	caption.add_theme_constant_override("shadow_offset_y",2)
	var font=SystemFont.new()
	font.font_names=PackedStringArray(["PingFang TC"])
	caption.add_theme_font_override("font",font)
	for e in g.enemies:e.set_physics_process(false)
	var p=g.player
	p.position=Vector3(4,0.3,23)
	p.visual.rotation.y=PI
	g.npcs[2].node.position=Vector3(6,0,23)
	g.npcs[4].node.position=Vector3(2,0,23)
	shot(g,"動漫角色 × 奇幻服裝 · 遊戲實景",Vector3(4,2.7,29),Vector3(4,1.15,23))
	await wait(g,1.5)
	await snap(g,"template-village")
	await wait(g,0.7)
	p.position=Vector3(0,0.3,-98)
	p.visual.rotation.y=0
	p.yaw=0
	g.boss.position=Vector3(0,0.3,-112)
	g.boss.visual.rotation.y=PI
	shot(g,"三段劍技 · 腰部轉動、踏步、收刀",Vector3(3.6,2.35,-103),Vector3(0,1.05,-98.6))
	p.combo_window=0
	for i in 3:
		p.stamina=100
		p.begin_attack(false)
		await wait(g,p.attack_length+0.08)
	p.stamina=100
	caption.text="重斬 · 蓄勢 → 斬擊 → 回收"
	p.begin_attack(true)
	await wait(g,0.5)
	await snap(g,"template-sword")
	await wait(g,0.75)
	shot(g,"翻滾 · 收身、落地、起身",Vector3(5,2.0,-101),Vector3(0,0.9,-101))
	p.stamina=100
	var e=InputEventAction.new()
	e.action="roll"
	e.pressed=true
	p._unhandled_input(e)
	await wait(g,0.23)
	await snap(g,"template-roll")
	await wait(g,0.85)
	p.position=Vector3(-4,0.3,-99)
	p.yaw=-PI/2
	shot(g,"奔跑 · 全身步態與重心變化",Vector3(0,2,-105),Vector3(0,1,-99))
	Input.action_press("forward")
	Input.action_press("sprint")
	await wait(g,0.95)
	Input.action_release("forward")
	Input.action_release("sprint")
	await wait(g,0.35)
	p.restore()
	p.position=Vector3(0,0.3,-100)
	g.boss.position=Vector3(0,0.3,-105)
	p.invulnerable=100
	p.visual.rotation.y=0
	g.boss.visual.rotation.y=PI
	shot(g,"日冕守誓者 · 慢刀蓄勢、快速出刀",Vector3(-5,3.1,-99),Vector3(0,1.8,-104))
	g.boss.attack_index=1
	g.boss.engaged=true
	g.boss._start_attack()
	g.boss.set_physics_process(true)
	await wait(g,1.4)
	await snap(g,"template-boss")
	await wait(g,1.15)
	g.boss.set_physics_process(false)
	g.boss.position=Vector3(0,0.3,-105)
	g.boss.attack_index=0
	g.boss._start_attack()
	g.boss.set_physics_process(true)
	caption.text="迅光二連 · 每一刀都有獨立動作與命中時點"
	await wait(g,1.5)
	g.boss.set_physics_process(false)
	g._clear_effects()
	p.restore()
	p.position=Vector3(0,0.3,-99)
	p.locked_target=g.boss
	p.spell_page=2
	shot(g,"劍與魔法 · 保留 12 招術式與華麗特效",Vector3(7,4.5,-96),Vector3(0,1.6,-104))
	p.cast_slot(3)
	await wait(g,2.3)
	g._clear_effects()
	for child in g.get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream=null
	await wait(g,0.15)
	print("MOTION CAPTURE COMPLETE")
	g.get_tree().quit()
