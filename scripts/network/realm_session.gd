class_name RealmSession
extends Node

# One authoritative ENet world. Only this fixed node path exposes RPCs.
const PROTOCOL = "aurelia-realm-5"
const PORT = 24567
const MAX_PLAYERS = 32
const TRADES = ["flask","herbs","upgrade","brew","food"]
const WORLD_FILE = "user://realm-world.json"
const FIELDS = ["level","experience","hp","max_hp","max_mana","cast_duration","mana","stamina","flasks","gold","herbs","upgrades","food_time","mounted","dead","attack_time","attack_length","heavy","combo","roll_time","cast_time","stagger","ward_time","ward_hp","skill_cooldown","heal_cooldown","personal_quest","personal_reward","personal_kills","personal_checkpoint"]
var offline_state: Dictionary = {}
var game: Node3D
var online = false
var connecting = false
var dedicated = false
var status = "所有旅人加入同一個世界 · 最多 32 人"
var address = "127.0.0.1"
var port = PORT
var nickname = "旅人"
var avatars: Dictionary = {}
var names: Dictionary = {}
var targets: Dictionary = {}
var input_times: Dictionary = {}
var command_limits: Dictionary = {}
var sequences: Dictionary = {}
var pending: Dictionary = {}
var enemy_returns: Dictionary = {}
var herb_returns: Dictionary = {}
var death_times: Dictionary = {}
var snap_accum = 0.0
var save_accum = 0.0
var connect_age = 0.0
var command_sequence = 0
var move_sequence = 0
var server_tick = 0
var received_tick = -1
var snapshot_count = 0
var test_session = false
var last_players = 0
var test_phase = ""
var snapshot_stream = WorldSnapshot.new()

func _ready() -> void:
	multiplayer.peer_disconnected.connect(_peer_left)
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(func():leave("連線失敗：請確認伺服器位址與 UDP 連接埠。"))
	multiplayer.server_disconnected.connect(func():leave("伺服器已離線；你的單人存檔沒有被覆寫。"))

func authoritative() -> bool:
	return online and multiplayer.is_server()

func is_local(actor: Hero) -> bool:
	return online and not dedicated and actor==game.player

func start_from_arguments() -> void:
	var args=OS.get_cmdline_user_args()
	test_session="--net-test" in args
	for arg in args:
		if arg.begins_with("--port="):port=clampi(int(arg.trim_prefix("--port=")),1024,65535)
		if arg.begins_with("--name="):nickname=arg.trim_prefix("--name=").left(20)
	if "--server" in args:
		dedicated=true
		game.test_mode=true
		game.hud.hide()
		if host(false)!=OK:
			printerr(status)
			get_tree().quit(1)
			return
	elif Array(args).any(func(arg):return arg.begins_with("--join=")):
		for arg in args:
			if arg.begins_with("--join="):address=arg.trim_prefix("--join=")
		join_world(address,nickname,port)
	if "--network-review" in args:call_deferred("_run_network_review")
	if test_session and not "--capacity-server" in args:
		game.test_mode=true
		call_deferred("_run_network_probe")

func host(with_player: bool = true) -> Error:
	if online or connecting:return ERR_ALREADY_IN_USE
	_remember_offline()
	var peer=ENetMultiplayerPeer.new()
	var error=peer.create_server(port,MAX_PLAYERS+4,3)
	if error!=OK:
		status="伺服器啟動失敗，連接埠可能已被使用："+error_string(error)
		return error
	multiplayer.server_relay=false
	multiplayer.multiplayer_peer=peer
	online=true
	dedicated=not with_player
	game.mode="play"
	game.player.network_driven=true
	game.player.hide()
	game.player.collision_layer=0
	game._clear_effects()
	game.boss_defeated=false
	for foe in game.enemies:foe.revive()
	for item in game.interactables:
		if item.type=="herb":item.node.show()
	if with_player:
		_add_actor(1,nickname,true)
		game.set_mode("play")
	_load_world()
	status="世界運行中 · UDP %d · 容量 %d" % [port,MAX_PLAYERS]
	print("REALM_READY port=",port," capacity=",MAX_PLAYERS)
	return OK

func join_world(host_address: String, player_name: String, host_port: int = PORT) -> Error:
	if online or connecting:return ERR_ALREADY_IN_USE
	address=host_address.strip_edges().left(253)
	nickname=player_name.strip_edges().left(20)
	if address.is_empty() or nickname.is_empty() or host_port<1024 or host_port>65535:
		status="請填寫伺服器位址、角色名稱及 1024–65535 的連接埠。"
		return ERR_INVALID_PARAMETER
	port=host_port
	_remember_offline()
	var peer=ENetMultiplayerPeer.new()
	var error=peer.create_client(address,port,3)
	if error!=OK:
		status="無法建立連線："+error_string(error)
		return error
	multiplayer.multiplayer_peer=peer
	connecting=true
	connect_age=0
	status="正在加入 %s:%d…" % [address,port]
	game.set_mode("network")
	return OK

func _connected() -> void:
	register.rpc_id(1,PROTOCOL,nickname,game.player.profile)

func _peer_connected(id: int) -> void:
	if authoritative():pending[id]=Time.get_ticks_msec()

@rpc("any_peer","call_remote","reliable",0)
func register(version: String, display_name: String, profile: Dictionary) -> void:
	if not authoritative():return
	var id=multiplayer.get_remote_sender_id()
	if id<=1 or avatars.has(id):return
	if version!=PROTOCOL or avatars.size()>=MAX_PLAYERS:
		rejected.rpc_id(id,"版本不相容，請使用與伺服器相同的遊戲版本。" if version!=PROTOCOL else "世界人數已滿（32 / 32），請稍後再試。")
		return
	var cleaned=display_name.strip_edges().left(20)
	for i in cleaned.length():
		if cleaned.unicode_at(i)<32:cleaned="旅人";break
	if cleaned.is_empty():cleaned="旅人"
	_add_actor(id,cleaned,false)
	avatars[id].apply_profile(profile)
	avatars[id].restore()
	pending.erase(id)
	welcome.rpc_id(id,PROTOCOL,_snapshot())
	print("REALM_JOIN id=",id," count=",avatars.size())

@rpc("authority","call_remote","reliable",0)
func rejected(reason: String) -> void:
	leave(reason)

@rpc("authority","call_remote","reliable",0)
func welcome(version: String, state: Dictionary) -> void:
	if not connecting or version!=PROTOCOL:return
	connecting=false
	online=true
	for foe in game.enemies:foe.set_physics_process(false)
	_apply_snapshot(state,true)
	game.set_mode("play")
	status="已加入共同世界"
	print("REALM_CONNECTED id=",multiplayer.get_unique_id())

func _add_actor(id: int, display_name: String, local: bool) -> Hero:
	var actor:Hero
	if local:
		actor=game.player
		actor.show()
		actor.collision_layer=2
	else:
		actor=Hero.new()
		actor.name="Guest_"+str(id)
		game.add_child(actor)
		actor.setup(game)
		var spells=Spellcraft.new()
		game.add_child(spells)
		spells.setup(game,actor)
		actor.spellcraft=spells
		actor.camera.current=false
	actor.network_id=id
	actor.network_driven=true
	actor.position=Vector3(4+(avatars.size()%4)*1.4,0.4,30+int(avatars.size()/4)*1.4)
	actor.load_progress({})
	actor.restore()
	actor.gold=80
	actor.herbs=0
	actor.upgrades=0
	actor.food_time=0
	actor.mounted=false
	actor.personal_quest=false
	actor.personal_reward=false
	actor.personal_kills=0
	actor.personal_checkpoint=Vector3(4,0.4,30)
	if not dedicated:
		actor.mount_visual=Art.horse(actor)
		actor.mount_visual.top_level=true
		actor.mount_visual.hide()
	var label=Art.label3d(actor,display_name,Vector3(0,2.25,0),Color("a9e9ff"),22)
	label.visibility_range_end=28
	actor.set_meta("nameplate",label)
	avatars[id]=actor
	names[id]=display_name
	input_times[id]=Time.get_ticks_msec()
	sequences[id]={"move":-1,"command":-1}
	command_limits[id]={"tokens":20.0,"time":Time.get_ticks_msec()}
	if not dedicated:
		game.player.camera.current=true
	return actor

func _peer_left(id: int) -> void:
	pending.erase(id)
	_remove_actor(id)

func _remove_actor(id: int) -> void:
	if avatars.has(id):
		var actor:Hero=avatars[id]
		actor.spellcraft.clear()
		if actor!=game.player:
			actor.spellcraft.queue_free()
			actor.queue_free()
		avatars.erase(id)
	for dictionary in [names,targets,input_times,command_limits,sequences,death_times]:dictionary.erase(id)

func leave(message: String = "已離開共同世界") -> void:
	if authoritative():save_world()
	online=false
	connecting=false
	multiplayer.multiplayer_peer=OfflineMultiplayerPeer.new()
	for id in avatars.keys():_remove_actor(id)
	for child in game.player.get_children():
		if child is Label3D:child.queue_free()
	if is_instance_valid(game.player.mount_visual):game.player.mount_visual.queue_free()
	game.player.mount_visual=null
	game.player.network_driven=false
	game.player.network_id=0
	game.player.network_move=Vector2.ZERO
	game.player.show()
	game.player.collision_layer=2
	game.player.restore()
	game.player.position=Vector3(4,0.4,30)
	if not offline_state.is_empty():
		game.player.apply_profile(offline_state.profile)
		for field in offline_state.hero:game.player.set(field,offline_state.hero[field])
		for field in offline_state.world:game.set(field,offline_state.world[field])
	game._clear_effects()
	game._spawn_enemies()
	for i in game.interactables.size():
		if game.interactables[i].type=="herb":game.interactables[i].node.visible=not i in offline_state.get("harvested",[])
	received_tick=-1
	snapshot_stream=WorldSnapshot.new()
	enemy_returns.clear()
	herb_returns.clear()
	status=message
	game.set_mode("network")

func player_input(event: InputEvent) -> void:
	var p=game.player
	if game.mode!="play" or p.dead:return
	if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		p.yaw-=event.relative.x*0.0026
		p.pitch=clampf(p.pitch-event.relative.y*0.0023,-0.95,0.3)
	if event.is_action_pressed("spell_page"):p.spell_page=(p.spell_page+1)%3
	if event.is_action_pressed("lock_on"):
		p.locked_target=null if is_instance_valid(p.locked_target) else game.nearest_enemy(p.position,24)
	for action in ["attack","heavy","roll","flask","mount"]:
		if event.is_action_pressed(action):request(action)
	for slot in 4:
		if event.is_action_pressed(["bolt","frost","skill","heal"][slot]):request("cast",p.spell_page*4+slot)

func request(action: String, value: int = 0) -> void:
	if not online:return
	command_sequence+=1
	var axis=Input.get_vector("left","right","forward","back") if game.mode=="play" else Vector2.ZERO
	var enemy=game.enemies.find(game.player.locked_target) if is_instance_valid(game.player.locked_target) else -1
	if authoritative():_command(1,command_sequence,action,value,game.player.yaw,axis,enemy)
	else:command.rpc_id(1,command_sequence,action,value,game.player.yaw,axis,enemy)

@rpc("any_peer","call_remote","unreliable_ordered",1)
func movement(sequence: int, axis: Vector2, angle: float, sprinting: bool) -> void:
	if authoritative():_movement(multiplayer.get_remote_sender_id(),sequence,axis,angle,sprinting)

func _movement(id: int, sequence: int, axis: Vector2, angle: float, sprinting: bool) -> void:
	if not avatars.has(id) or not axis.is_finite() or not is_finite(angle):return
	if sequence<=sequences[id].move:return
	sequences[id].move=sequence
	var p:Hero=avatars[id]
	p.network_move=axis.limit_length(1)
	p.yaw=wrapf(angle,-PI,PI)
	p.network_sprint=sprinting
	input_times[id]=Time.get_ticks_msec()

@rpc("any_peer","call_remote","reliable",0)
func command(sequence: int, action: String, value: int, angle: float, axis: Vector2, enemy: int) -> void:
	if authoritative():_command(multiplayer.get_remote_sender_id(),sequence,action,value,angle,axis,enemy)

func _command(id: int, sequence: int, action: String, value: int, angle: float, axis: Vector2, enemy: int) -> void:
	if not avatars.has(id) or not is_finite(angle) or not axis.is_finite():return
	if sequence<=sequences[id].command:return
	sequences[id].command=sequence
	var budget=command_limits[id]
	var now=Time.get_ticks_msec()
	budget.tokens=minf(20,budget.tokens+(now-budget.time)*0.012)
	budget.time=now
	if budget.tokens<1:return
	budget.tokens-=1
	var p:Hero=avatars[id]
	p.yaw=wrapf(angle,-PI,PI)
	p.network_move=axis.limit_length(1)
	p.locked_target=null
	if enemy>=0 and enemy<game.enemies.size():
		var target=game.enemies[enemy]
		if not target.dead and p.position.distance_to(target.position)<28 and game.can_see(p.position+Vector3.UP,target.position+Vector3.UP,p):p.locked_target=target
	if action=="respawn":
		if p.dead and now>=death_times.get(id,0):
			p.position=p.personal_checkpoint
			p.restore()
			p.mounted=false
		return
	if p.dead:return
	match action:
		"attack","heavy","roll","flask","mount":p.server_action(action)
		"cast":
			if value>=0 and value<Spellcraft.SPELLS.size():p.server_action("cast",value)
		"travel":
			var arrived=game.travel_to(value,p)
			_notify(id,"已抵達驛站。" if arrived else "請靠近曦光碑，並在附近沒有交戰敵人時旅行。")
		"trade":
			if value<0 or value>=TRADES.size():return
			var role=["merchant","merchant","smith","herbalist","cook"][value]
			if _near_role(p,role):
				var success=game.trade(TRADES[value],p)
				_notify(id,"補給已更新" if success else "無法交易，請確認金幣、材料與攜帶上限。")
			else:_notify(id,"請先走近對應的商人或工匠。")
		"quest":
			if _near_role(p,"elder"):p.personal_quest=true
		"reward":
			if _near_role(p,"elder") and p.personal_quest and not p.personal_reward and p.personal_kills>=3 and game.boss_defeated:
				p.personal_reward=true
				p.gold+=180
				p.herbs+=3
		"interact":_interact(p,value)

func _near_role(p: Hero, role: String) -> bool:
	for npc in game.npcs:
		if npc.type==role and p.position.distance_to(npc.node.position)<3.2:return true
	return false

func _interact(p: Hero, index: int) -> void:
	if index<0 or index>=game.interactables.size() or not p.can_act():return
	var item=game.interactables[index]
	if p.position.distance_to(item.node.position)>3.2:return
	if item.type=="herb" and item.node.visible:
		item.node.hide()
		p.herbs+=1
		herb_returns[index]=Time.get_unix_time_from_system()+90
	elif item.type=="shrine":
		var foe=game.nearest_enemy(p.position,12)
		if foe and foe.engaged:return
		p.personal_checkpoint=item.node.position+Vector3(0,0.3,2)
		p.restore()
		p.mounted=false
		p.spellcraft.clear()
		# Rest heals this player; it never resets everybody else's encounter.

func hero_died(p: Hero) -> void:
	if not authoritative() or not is_instance_valid(p):return
	p.gold=int(p.gold*0.85)
	p.mounted=false
	p.spellcraft.clear()
	death_times[p.network_id]=Time.get_ticks_msec()+3000
	broadcast_fx("death",[p.network_id])

func enemy_defeated(foe: Foe) -> void:
	if not authoritative() or foe.rewarded:return
	foe.rewarded=true
	var index=game.enemies.find(foe)
	enemy_returns[index]=Time.get_unix_time_from_system()+(600 if foe.is_boss else 90)
	if foe==game.boss:game.boss_defeated=true
	elif foe.is_boss and not foe.boss_profile in game.cleared_guardians:game.cleared_guardians.append(foe.boss_profile)
	for actor in game.living_players():
		if actor.position.distance_to(foe.position)>45:continue
		var xp=Progression.reward(foe)
		var gained=actor.gain_experience(xp)
		game.experience_feedback(actor,xp,gained)
		actor.gold+=500 if foe.is_boss else 45 if foe.kind=="elite" else 18
		if not foe.is_boss:actor.personal_kills+=1
	save_world()

func actor_id(actor: Node3D) -> int:
	return actor.network_id if actor is Hero else -game.enemies.find(actor)-1

func cast_effect(actor: Hero, index: int) -> void:
	if authoritative():broadcast_fx("cast",[actor.network_id,index,game.enemies.find(actor.locked_target)])

func broadcast_fx(kind: String, data: Array) -> void:
	if not authoritative():return
	for id in avatars:
		if id!=1:effect.rpc_id(id,kind,data)

@rpc("authority","call_remote","reliable",2)
func effect(kind: String, data: Array) -> void:
	if not online:return
	match kind:
		"slash":game.slash(data[0],data[1],data[2])
		"damage":game.floating_text(data[0],data[1],data[2])
		"projectile":
			var source=avatars.get(data[4]) if data[4]>0 else game.enemies[-data[4]-1]
			if source:game.fire_projectile(data[0],data[1],data[2],0,source,data[5])
		"hazard":game.make_hazard(data[0],data[1],data[2],0,game.boss)
		"wave":game.shockwave(data[0],data[1])
		"death":
			if avatars.has(data[0]):avatars[data[0]].spellcraft.clear()
		"cast":
			if not avatars.has(data[0]):return
			var p:Hero=avatars[data[0]]
			var index:int=data[1]
			p.locked_target=game.enemies[data[2]] if data[2]>=0 else null
			if index>=4:p.spellcraft.cast(index)
			else:
				var color=Color(Spellcraft.SPELLS[index].color)
				p.spellcraft.cast_flourish(p.position,color)
				if index==2:p.spellcraft.impact(p.position,color,5.3,true)
				if index==3:p.spellcraft.circle(p.position,1.5,color,1.2)

func _snapshot() -> Dictionary:
	var actors={}
	for id in avatars:
		var p:Hero=avatars[id]
		var state={"profile":p.profile,"position":p.position,"velocity":p.velocity,"angle":p.visual.rotation.y,"name":names[id],"cooldowns":p.spell_cooldowns.duplicate()}
		for field in FIELDS:state[field]=p.get(field)
		actors[id]=state
	var foes=[]
	for foe in game.enemies:
		foes.append({"position":foe.position,"angle":foe.visual.rotation.y,"velocity":foe.velocity,"hp":foe.hp,"dead":foe.dead,"phase":foe.phase,"state":foe.state,"timer":foe.timer,"engaged":foe.engaged,"attack":foe.attack.duplicate(true),"arm":Vector3.ZERO if foe.rig is AnimatedCharacter else foe.rig.get_node("ArmR").rotation})
	var herbs=[]
	for i in game.interactables.size():
		if game.interactables[i].type=="herb" and not game.interactables[i].node.visible:herbs.append(i)
	return {"cleared_guardians":game.cleared_guardians,"tick":server_tick,"actors":actors,"foes":foes,"herbs":herbs,"boss_defeated":game.boss_defeated,"test_phase":test_phase if test_session else ""}

@rpc("authority","call_remote","unreliable",1)
func snapshot(frame: int, index: int, count: int, bytes: PackedByteArray) -> void:
	if not online or authoritative() or frame<=received_tick:return
	var state=snapshot_stream.receive(frame,index,count,bytes)
	if not state.is_empty():_apply_snapshot(state,false)

func _apply_snapshot(state: Dictionary, initial: bool) -> void:
	if int(state.tick)<=received_tick and not initial:return
	game.cleared_guardians.assign(state.get("cleared_guardians",[]))
	received_tick=int(state.tick)
	snapshot_count+=1
	if test_session:test_phase=state.get("test_phase","")
	var self_id=multiplayer.get_unique_id()
	for id in state.actors:
		var data:Dictionary=state.actors[id]
		var fresh=not avatars.has(id)
		if fresh:_add_actor(id,data.name,id==self_id)
		var p:Hero=avatars[id]
		if p.profile!=data.profile:p.apply_profile(data.profile)
		if fresh or initial or p.position.distance_to(data.position)>8:p.position=data.position
		targets[id]=data.position
		p.velocity=data.velocity
		p.visual.rotation.y=data.angle
		for field in FIELDS:p.set(field,data[field])
		p.spell_cooldowns=data.cooldowns
	for id in avatars.keys():
		if not state.actors.has(id):_remove_actor(id)
	for i in mini(game.enemies.size(),state.foes.size()):
		var foe:Foe=game.enemies[i]
		var data:Dictionary=state.foes[i]
		foe.position=data.position
		foe.visual.rotation.y=data.angle
		foe.velocity=data.velocity
		for field in ["hp","dead","phase","state","timer","engaged","attack"]:foe.set(field,data[field])
		foe.visible=not foe.dead or foe.death_elapsed<1.4
		foe.collision_layer=0 if foe.dead else 4
		foe.visual.scale=Vector3.ONE
		if not foe.rig is AnimatedCharacter:foe.rig.get_node("ArmR").rotation=data.arm
	for i in game.interactables.size():
		if game.interactables[i].type=="herb":game.interactables[i].node.visible=not i in state.herbs
	game.boss_defeated=state.boss_defeated
	_sync_local_ui()

func _sync_local_ui() -> void:
	if dedicated:return
	game.quest_active=game.player.personal_quest
	game.quest_rewarded=game.player.personal_reward
	game.kills=game.player.personal_kills
	if game.player.dead and game.mode!="dead":game.set_mode("dead")
	elif not game.player.dead and game.mode=="dead":game.set_mode("play")
	status="共同世界 · %d / %d 人在線" % [avatars.size(),MAX_PLAYERS]

func _physics_process(delta: float) -> void:
	if not online:return
	snap_accum+=delta
	server_tick+=1
	if authoritative():
		var now=Time.get_ticks_msec()
		for id in avatars:
			if now-int(input_times[id])>300:
				avatars[id].network_move=Vector2.ZERO
				avatars[id].network_sprint=false
		for id in pending.keys():
			if now-int(pending[id])>10000:
				multiplayer.multiplayer_peer.disconnect_peer(id)
		_world_timers()
		save_accum+=delta
		if save_accum>=10:
			save_accum=0
			save_world()
	if snap_accum<0.05:return
	snap_accum=0
	if not dedicated:
		move_sequence+=1
		var axis=Input.get_vector("left","right","forward","back") if game.mode=="play" else Vector2.ZERO
		if authoritative():_movement(1,move_sequence,axis,game.player.yaw,Input.is_action_pressed("sprint"))
		else:movement.rpc_id(1,move_sequence,axis,game.player.yaw,Input.is_action_pressed("sprint"))
	if authoritative():
		var state=_snapshot()
		var chunks=WorldSnapshot.encode(state)
		for id in avatars:
			if id==1:continue
			for index in chunks.size():snapshot.rpc_id(id,server_tick,index,chunks.size(),chunks[index])

func _process(delta: float) -> void:
	if connecting:
		connect_age+=delta
		if connect_age>12:leave("連線逾時：伺服器未回應。")
	if not online:return
	if not authoritative():
		for id in avatars:
			var actor:Hero=avatars[id]
			actor.position=actor.position.lerp(targets.get(id,actor.position),minf(1,delta*22))
			actor.update_replica(delta)
		for foe in game.enemies:
			if foe.dead:
				foe.death_elapsed+=delta
				if foe.rig.clips.has("death"):foe.rig.pose("death",minf(1,foe.death_elapsed/1.4),delta,.04)
				foe.visible=foe.death_elapsed<1.4
				continue
			foe.death_elapsed=0
			var distance=game.player.position.distance_to(foe.position)
			if distance>120:continue
			foe.ensure_visual()
			foe.nameplate.visible=not foe.is_boss and distance<12
			foe.health_mesh.visible=not foe.is_boss and foe.hp<foe.max_hp and distance<16
			foe.health_mesh.scale.x=maxf(0.001,foe.hp/foe.max_hp)
			foe.anim_time+=delta
			if foe.rig is AnimatedCharacter:foe._animate_skeleton(delta,Vector2(foe.velocity.x,foe.velocity.z).length())
			else:
				foe.rig.get_node("LegL").rotation.x=sin(foe.anim_time*7)*minf(foe.velocity.length()*0.18,0.5)
				foe.rig.get_node("LegR").rotation.x=-foe.rig.get_node("LegL").rotation.x
	if not dedicated:
		_sync_local_ui()
		var p=game.player
		if is_instance_valid(p.locked_target):
			if p.locked_target.dead:p.locked_target=null
			else:
				var direction=p.locked_target.position-p.position
				p.yaw=lerp_angle(p.yaw,atan2(-direction.x,-direction.z),delta*3.5)
		p.camera_pivot.rotation=Vector3(p.pitch,p.yaw,0)
		p.camera_pivot.position.y=lerpf(p.camera_pivot.position.y,2.65 if p.mounted else 1.5,delta*8)

func _world_timers() -> void:
	var now=Time.get_unix_time_from_system()
	for index in enemy_returns.keys():
		if now>=float(enemy_returns[index]):
			game.enemies[int(index)].revive()
			enemy_returns.erase(index)
	for index in herb_returns.keys():
		if now>=float(herb_returns[index]):
			game.interactables[int(index)].node.show()
			herb_returns.erase(index)

func save_world(path: String = WORLD_FILE) -> void:
	if not authoritative() or (test_session and path==WORLD_FILE):return
	var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"version":2,"cleared_guardians":game.cleared_guardians,"boss_defeated":game.boss_defeated,"enemies":enemy_returns,"herbs":herb_returns}))
		file.close()
		DirAccess.rename_absolute(path+".tmp",path)

func _load_world(path: String = WORLD_FILE) -> void:
	if (test_session and path==WORLD_FILE) or not FileAccess.file_exists(path):return
	var data=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("version",0)!=2:return
	game.boss_defeated=bool(data.get("boss_defeated",false))
	game.cleared_guardians.assign(data.get("cleared_guardians",[]))
	for key in data.get("enemies",{}):
		var index=int(key)
		if index>=0 and index<game.enemies.size():
			enemy_returns[index]=float(data.enemies[key])
			game.enemies[index].dead=true
			game.enemies[index].hide()
			game.enemies[index].collision_layer=0
	for key in data.get("herbs",{}):
		var index=int(key)
		if index>=0 and index<game.interactables.size() and game.interactables[index].type=="herb":
			herb_returns[index]=float(data.herbs[key])
			game.interactables[index].node.hide()

func _run_network_probe() -> void:
	await load("res://tests/network_probe.gd").new().run(game)

func _notify(id: int, message: String) -> void:
	if id==1:game.toast("共同世界",message)
	else:notice.rpc_id(id,message)

@rpc("authority","call_remote","reliable",0)
func notice(message: String) -> void:
	if online:game.toast("共同世界",message)

func _remember_offline() -> void:
	offline_state={"profile":game.player.profile.duplicate(true),"hero":{},"world":{},"harvested":[]}
	for field in FIELDS+["position"]:offline_state.hero[field]=game.player.get(field)
	for field in ["boss_defeated","cleared_guardians","quest_active","quest_rewarded","kills","checkpoint"]:offline_state.world[field]=game.get(field).duplicate() if game.get(field) is Array else game.get(field)
	for i in game.interactables.size():
		if game.interactables[i].type=="herb" and not game.interactables[i].node.visible:offline_state.harvested.append(i)

func _exit_tree() -> void:
	if is_instance_valid(game) and authoritative():save_world()

func _run_network_review() -> void:
	await load("res://tests/network_review.gd").new().run(game)
