extends SceneTree
var passed=0
var failed=0
func _initialize() -> void:call_deferred("run")
func check(value: bool, message: String) -> void:
	if value:passed+=1;print("HOST PASS: ",message)
	else:failed+=1;push_error("HOST FAIL: "+message)
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.3).timeout
	game.test_mode=true
	if game.music:game.music.stop();game.music.stream=null
	game.player.gold=123
	game.quest_active=false
	game.boss_defeated=true
	game.boss.dead=true
	game.player.personal_reward=true
	game.player.food_time=120
	game.net.test_session=true
	game.net.port=24674
	check(game.net.host(true)==OK,"Listen server starts on an isolated port")
	check(game.net.avatars.has(1) and game.player.network_id==1,"Host is also a registered player")
	check(game.player.gold==80,"Online character starts with its own inventory")
	check(not game.boss_defeated and not game.boss.dead and not game.player.personal_reward and game.player.food_time==0,"New shared world cannot inherit offline Boss or character bonuses")
	game.player.position=game.npcs[0].node.position+Vector3(0,0.3,1)
	game.net.request("quest")
	await create_timer(0.1).timeout
	check(game.quest_active and game.player.personal_quest,"Host HUD reflects authoritative quest state")
	game.set_mode("pause")
	check(game.world_running(),"Host menu does not pause the server simulation")
	game.player.invulnerable=0
	game.player.take_damage(10000,Vector3.ZERO)
	await create_timer(0.1).timeout
	check(game.mode=="dead" and game.world_running(),"Host sees a death screen while the world keeps running")
	game.net.death_times[1]=0
	game.respawn()
	await create_timer(0.1).timeout
	check(game.mode=="play" and not game.player.dead,"Host respawn returns to live play")
	game.player.position=Vector3(5.2,.4,31)
	for foe in game.enemies:foe.engaged=false
	game.net.request("travel",1)
	check(game.player.position.distance_to(WorldAtlas.settlements[0].center)<25,"Authoritative travel command reaches a remote settlement")
	game.net.leave()
	check(not game.net.online and game.net.avatars.is_empty(),"Leaving closes the connection and removes online actors")
	check(game.player.gold==123 and not game.quest_active,"Offline inventory and quest state are restored without mixing realms")
	check(game.boss_defeated and game.boss.dead and game.player.food_time>0,"Offline Boss completion and food effect survive a realm session")
	check(not game.player.network_driven and game.player.collision_layer==2,"Offline control and collision are restored")
	check(game.net.join_world("","Name",24567)==ERR_INVALID_PARAMETER,"Connection form rejects an empty address")
	print("HOST RESULT: %d passed, %d failed" % [passed,failed])
	await create_timer(0.1).timeout
	quit(1 if failed else 0)
