extends RefCounted

var passed=0
var failures=[]
var game: Node3D

func check(ok: bool, message: String) -> void:
	if ok:
		passed+=1
		print("NET PASS: "+message)
	else:
		failures.append(message)
		push_error("NET FAIL: "+message)

func wait(seconds: float) -> void:
	await game.get_tree().create_timer(seconds).timeout

func find_player(name: String) -> Hero:
	for id in game.net.names:
		if game.net.names[id]==name:return game.net.avatars[id]
	return null

func run(g: Node3D) -> void:
	game=g
	if g.net.dedicated:await server()
	else:await client()

func server() -> void:
	var n=game.net
	for i in 200:
		if n.avatars.size()>=2:break
		await wait(0.1)
	check(n.avatars.size()==2,"Two independent clients enter one authoritative world")
	if n.avatars.size()!=2:
		game.get_tree().quit(1)
		return
	for foe in game.enemies:foe.set_physics_process(false)
	var a=find_player("Alpha")
	var b=find_player("Beta")
	check(a!=b and a.network_id!=b.network_id,"Peer identity selects its own Hero")
	a.position=Vector3(0,0.3,-35)
	b.position=Vector3(1.2,0.3,-35)
	a.visual.rotation.y=0
	b.visual.rotation.y=0
	var enemy=game.enemies[0]
	enemy.position=Vector3(0,0.3,-37)
	enemy.max_hp=1000
	enemy.hp=1000
	a.personal_quest=true
	b.personal_quest=true
	await wait(0.3)
	n.test_phase="combat"
	await wait(1.2)
	check(is_equal_approx(enemy.hp,952),"Both clients' sword hits reduce the same enemy HP exactly once")
	check(a.stamina<100 and b.stamina<100,"Each player's attack spends their own stamina")
	n.test_phase="magic"
	await wait(1.3)
	check(enemy.hp<900 and enemy.slowed>0,"Independent lightning and frost casts affect the shared enemy")
	check(a.mana<76 and b.mana<82,"Spell mana belongs to the individual caster")
	var start_a=a.position
	var start_b=b.position
	n.test_phase="move"
	await wait(1.0)
	check(b.position.distance_to(start_b)>3.5,"Server simulates a moving client's input")
	check(a.position.distance_to(start_a)<0.4,"One client's pause menu does not move their character")
	n.test_phase="stop"
	# Wait for the remote client to observe the phase and return its neutral input.
	# Deceleration is measured after that delivery, independently of packet scheduling.
	for attempt in 20:
		if b.network_move.is_zero_approx():break
		await wait(.05)
	check(b.network_move.is_zero_approx(),"Released input reaches the server within one second")
	await wait(.2)
	check(Vector2(b.velocity.x,b.velocity.z).length()<0.5,"Releasing input stops authoritative movement")
	a.position=Vector3(-10,0.3,-35)
	var roll_start=a.position
	n.test_phase="dodge"
	await wait(0.25)
	check(a.roll_time>0 and a.stamina<90,"Remote roll starts on the server and consumes stamina")
	check(not a.take_damage(10,Vector3.ZERO),"Authoritative roll invulnerability rejects an incoming hit")
	await wait(0.85)
	check(a.position.distance_to(roll_start)>4.5,"Remote roll travels through the real server physics world")
	n.test_phase="ride"
	await wait(0.4)
	check(a.mounted and not b.mounted,"Mounting affects only the requesting player")
	n.test_phase="dismount"
	await wait(0.4)
	check(not a.mounted,"Remote player can dismount before continuing combat")
	a.position=Vector3(0,0.3,-35)
	b.position=Vector3(5,0.3,-35)
	var gold=a.gold
	var mana=a.mana
	n.test_phase="invalid"
	await wait(0.5)
	check(a.gold==gold and a.upgrades==0,"Server rejects a remote blacksmith purchase away from the NPC")
	check(a.mana>=mana and a.position.distance_to(Vector3(0,a.position.y,-35))<0.1,"Unknown actions and invalid spell indices cannot teleport or consume resources")
	var previous=a.network_move
	n._movement(a.network_id,999999,Vector2(NAN,0),0,false)
	check(a.network_move==previous,"Non-finite movement is rejected")
	n._movement(a.network_id,n.sequences[a.network_id].move+1,Vector2(10000,10000),0,false)
	check(a.network_move.length()<=1.001,"Oversized input vectors are normalized on the server")
	a.network_move=Vector2.ZERO
	a.hp=50
	a.flasks=4
	n.test_phase="replay"
	await wait(1.3)
	check(a.hp==125 and a.flasks==3,"A repeated reliable command sequence cannot consume a second flask")
	# Simultaneous collection is serialized on the one world authority.
	var resource_index=14
	var resource=game.interactables[resource_index]
	a.position=resource.node.position+Vector3(0,0.3,1)
	b.position=resource.node.position+Vector3(0.8,0.3,1)
	a.herbs=0
	b.herbs=0
	await wait(0.2)
	n.test_phase="gather"
	await wait(0.6)
	check(a.herbs+b.herbs==1 and not resource.node.visible,"Contested gathering grants one item across both clients")
	check(n.herb_returns.has(resource_index),"Shared herbs get a server respawn timer")
	# Shrine use must not reset a different player's battle or heal them.
	a.position=game.interactables[12].node.position+Vector3(0,0.3,1)
	a.hp=35
	b.hp=61
	var enemy_hp=enemy.hp
	await wait(0.2)
	n.test_phase="rest"
	await wait(0.6)
	check(a.hp==a.max_hp and b.hp==61,"Rest restores only the player who used the shrine")
	check(enemy.hp==enemy_hp,"One player's rest never resets shared monster HP")
	# A nearby living player becomes the enemy target; there is no hidden host target.
	b.position=game.boss.home+Vector3(0,0,5)
	check(game.closest_player(game.boss.home)==b,"Boss targeting can select a remote player")
	game.boss.combat_target=b
	game.boss.attack_index=1
	game.boss._start_attack()
	check(game.boss.state=="windup" and game.boss.attack.windup>1.5,"Shared Boss retains its delayed heavy tell")
	game.boss.take_damage(10000)
	check(game.boss.dead and game.boss_defeated,"Boss death changes the authoritative world state")
	check(b.gold>=580,"Nearby cooperating player receives the Boss reward")
	check(b.level>1 and b.max_hp>140,"Nearby co-op player receives authoritative XP and stat growth")
	var pth="user://realm-network-test.json"
	n.save_world(pth)
	check(FileAccess.file_exists(pth),"Dedicated world state can be saved independently of a single-player save")
	n.enemy_returns.clear()
	n.herb_returns.clear()
	game.boss_defeated=false
	n._load_world(pth)
	check(game.boss_defeated and n.enemy_returns.has(10) and n.herb_returns.has(14),"World reload preserves Boss and gathering respawn schedules")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(pth))
	n.test_phase="late"
	print("NET_WAIT_LATE")
	for i in 150:
		if n.avatars.size()==3:break
		await wait(0.1)
	check(n.avatars.size()==3,"A third player can join an already changed world")
	await wait(0.7)
	n.test_phase="disconnect"
	for i in 80:
		if find_player("Beta")==null:break
		await wait(0.1)
	check(find_player("Beta")==null and n.avatars.size()==2,"Disconnect removes only that player's avatar")
	check(game.boss.dead and not resource.node.visible,"Disconnect does not reset shared world progress")
	a.take_damage(10000,Vector3.ZERO)
	check(a.dead and game.mode=="play","Player death does not pause or end the server world")
	check(find_player("Late")!=null and not find_player("Late").dead,"Other players remain alive after a teammate dies")
	n.death_times[a.network_id]=0
	n._command(a.network_id,n.sequences[a.network_id].command+1,"respawn",0,0,Vector2.ZERO,-1)
	check(not a.dead and a.position.distance_to(a.personal_checkpoint)<0.2,"Respawn restores the player's own checkpoint")
	n.test_phase="complete"
	await wait(0.5)
	print("NET SERVER RESULT: %d passed, %d failed" % [passed,failures.size()])
	game.get_tree().quit(0 if failures.is_empty() else 1)

func client() -> void:
	var language=game.get_node("/root/Language")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--language="):
			var expected=argument.trim_prefix("--language=")
			check(language.locale==expected and language.render("霜矢")==("Frost Arrow" if expected=="en" else "霜矢"),"Client retains its own selected interface language")
	var n=game.net
	for i in 180:
		if n.online:break
		await wait(0.1)
	check(n.online,"Client finishes real ENet registration")
	if not n.online:
		game.get_tree().quit(1)
		return
	check(game.player.network_id==game.multiplayer.get_unique_id(),"Welcome binds the local camera and HUD to the correct peer")
	var last=""
	var seen_peer=false
	var saw_shared_damage=false
	var saw_death=false
	var saw_mount=false
	for i in 500:
		if n.avatars.size()>=2:seen_peer=true
		if game.enemies[0].hp<1000 and game.enemies[0].max_hp==90:saw_shared_damage=true
		if game.boss.dead:saw_death=true
		var riding_peer=find_player("Alpha")
		if is_instance_valid(riding_peer) and riding_peer.mounted:saw_mount=true
		var phase=n.test_phase
		if phase!=last:
			last=phase
			match phase:
				"combat":n.request("attack")
				"magic":n.request("cast",4 if n.nickname=="Alpha" else 1)
				"move":
					if n.nickname=="Beta":Input.action_press("forward")
					else:game.set_mode("pause")
				"stop":
					Input.action_release("forward")
					game.set_mode("play")
				"dodge":
					if n.nickname=="Alpha":n.request("roll")
				"ride":
					if n.nickname=="Alpha":n.request("mount")
				"dismount":
					check(saw_mount,"Other clients receive the same mounted character state")
					if n.nickname=="Alpha":n.request("mount")
				"invalid":
					if n.nickname=="Alpha":
						n.request("trade",2)
						n.request("cast",999)
						n.request("teleport",999)
				"replay":
					if n.nickname=="Alpha":
						n.request("flask")
						var seq=n.command_sequence
						await wait(0.8)
						n.command.rpc_id(1,seq,"flask",0,0.0,Vector2.ZERO,-1)
				"gather":n.request("interact",14)
				"rest":
					if n.nickname=="Alpha":n.request("interact",12)
				"late":
					if n.nickname=="Late":
						check(find_player("Beta").level>1 and game.player.level==1,"Late join sees veteran levels while starting its own character at one")
						check(game.boss.dead and game.boss_defeated,"Late join receives an already defeated Boss")
						check(not game.interactables[14].node.visible,"Late join receives already harvested resources")
				"disconnect":
					if n.nickname=="Beta":
						check(seen_peer and saw_shared_damage and saw_death,"Client received other players, shared damage, and Boss death")
						check(n.snapshot_count>50,"Client receives a continuous state stream")
						check(game.player.level>1 and game.player.max_hp>140,"Client receives earned level and maximum health")
						print("NET CLIENT RESULT: %d passed, %d failed" % [passed,failures.size()])
						game.get_tree().quit(0 if failures.is_empty() else 1)
						return
				"complete":
					check(seen_peer and saw_death,"Remaining client observes teammates and shared Boss state")
					check(not game.player.take_damage(100,Vector3.ZERO),"Client-side damage cannot modify authoritative player health")
					print("NET CLIENT RESULT: %d passed, %d failed" % [passed,failures.size()])
					game.get_tree().quit(0 if failures.is_empty() else 1)
					return
		await wait(0.1)
	check(false,"Network test reached its time limit")
	game.get_tree().quit(1)
