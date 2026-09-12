extends SceneTree
func _initialize() -> void:call_deferred("run")
func capture(game:Node,file:String) -> void:
	for i in 15:await process_frame
	game.toast_time=0
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/"+file+".png")
func run() -> void:
	var g=load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await process_frame
	g.test_mode=true
	for foe in g.enemies:foe.set_physics_process(false)
	g.player.set_physics_process(false)
	var lang=root.get_node("Language")
	lang.set_language("zh_TW",false)
	await capture(g,"language-zh-menu")
	lang.set_language("en",false)
	await capture(g,"language-en-menu")
	for mode in ["character","play","spellbook","journal","map","pause","credits"]:
		g.set_mode(mode)
		await capture(g,"language-en-"+mode)
	g.speaker="伊蓮 · 晨鐘村村長"
	g.dialogue_text="歡迎來到晨鐘村，旅人。這裡的每一盞燈，都為歸來的人而亮。\n但曦白城北方的古龍已迷失於日輪的力量。\n請先清除三名野外敵人，再去日冕聖域解放奧瑞利昂。"
	g.set_mode("dialogue")
	await capture(g,"language-en-dialogue")
	quit()
