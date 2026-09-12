extends RefCounted

var passed=0
var failures:Array[String]=[]

func check(condition: bool, message: String) -> void:
	if condition:
		passed+=1
		print("PASS: "+message)
	else:
		failures.append(message)
		push_error("FAIL: "+message)

func frames(game: Node, count: int) -> void:
	for i in count:
		await game.get_tree().physics_frame

func action(player: Hero, name: String) -> void:
	var e=InputEventAction.new()
	e.action=name
	e.pressed=true
	player._unhandled_input(e)

func run(g: Node3D) -> void:
	print("AURELIA integration smoke suite")
	await frames(g,3)
	check(g.npcs.size()==244,"244 NPC records cover starter regions and continental settlements")
	check(g.enemies.size()==119+WorldAtlas.camps.size(),"Original enemies, 20 bosses and roadside encounters exist")
	check(g.mode=="menu","game opens on title screen")
	check(g.player.camera!=null,"third-person camera is present")
	check(ResourceLoader.exists("res://assets/models/traveler.glb"),"Blender traveler GLB is imported")
	check(g.player.rig is AnimatedCharacter and g.player.rig.skeleton.get_bone_count()>50,"Skinned character and full humanoid skeleton are used at runtime")
	g.set_mode("play")
	for e in g.enemies:
		e.set_physics_process(false)
	var p=g.player
	await frames(g,30)
	check(p.is_on_floor(),"terrain collision supports the player")
	var start=p.position
	Input.action_press("forward")
	await frames(g,45)
	Input.action_release("forward")
	check(p.position.z<start.z-2.5,"W moves forward in camera space")
	await frames(g,10)
	p.stamina=100
	action(p,"roll")
	check(p.roll_time>0 and p.invulnerable>0,"roll grants a timed invulnerability window")
	var old_hp=p.hp
	check(not p.take_damage(30,Vector3.ZERO) and p.hp==old_hp,"roll invulnerability prevents damage")
	await frames(g,45)
	p.invulnerable=0
	check(p.take_damage(20,Vector3.ZERO),"damage applies after invulnerability expires")
	check(p.hp==old_hp-20,"damage reduces health by the expected amount")
	await frames(g,40)
	p.hp=60
	p.flasks=2
	action(p,"flask")
	check(p.hp==135 and p.flasks==1,"healing flask restores 75 HP and consumes one charge")
	await frames(g,40)
	p.restore()
	p.position=Vector3(0,0.5,-26)
	g.horse.position=p.position+Vector3(1,0,0)
	g.toggle_mount()
	check(p.mounted,"nearby horse can be mounted")
	var ride=p.position
	Input.action_press("forward")
	Input.action_press("sprint")
	await frames(g,45)
	Input.action_release("forward")
	Input.action_release("sprint")
	check(p.position.distance_to(ride)>8,"mounted sprint accelerates and traverses eight metres in 0.75 seconds")
	g.toggle_mount()
	check(not p.mounted,"rider can dismount")
	p.restore()
	p.position=Vector3(0,0.4,-35)
	p.visual.rotation.y=0
	var e=g.enemies[0]
	e.position=Vector3(0,0.4,-37)
	e.hp=e.max_hp
	await frames(g,3)
	g.player_melee(3,24,false)
	check(e.hp==e.max_hp-24,"sword attack damages an enemy within the forward arc")
	e.position=Vector3(0,0.4,-33)
	await frames(g,2)
	var before=e.hp
	g.player_melee(3,24,false)
	check(e.hp==before,"sword attack does not hit an enemy behind the player")
	e.position=Vector3(0,0.4,-40)
	await frames(g,2)
	p.cast_time=0
	p.mana=100
	p.cast_spell(true)
	await frames(g,30)
	check(e.hp<before and e.slowed>0,"frost projectile collides and slows its target")
	check(p.mana<80,"spell consumes mana")
	p.gold=0
	check(not g.trade("flask") and p.gold==0,"shop rejects unaffordable purchases without charging")
	p.gold=100
	p.flasks=1
	check(g.trade("flask") and p.gold==75 and p.flasks==2,"shop exchanges gold for a flask")
	p.herbs=2
	check(g.trade("food") and p.herbs==0 and p.food_time==180,"cooking consumes herbs and applies the stamina buff")
	p.gold=100
	p.upgrades=0
	check(g.trade("upgrade") and p.upgrades==1 and p.gold==40,"blacksmith upgrade has the correct cost and result")
	var b=g.boss
	b.take_damage(b.max_hp*0.5)
	check(b.phase==2 and is_equal_approx(b.hp,b.max_hp*.5),"boss enters its second phase at half health")
	b.attack_index=0
	b._start_attack()
	check(b.attack.hits.size()==3,"phase two adds a third quick-combo strike")
	b.attack_index=1
	b._start_attack()
	check(b.attack.windup>1.4,"boss heavy attack preserves a readable delayed windup")
	b.poise=200
	b.take_damage(20,false,true)
	check(b.state=="stagger","poise damage opens a boss punish window")
	b.engaged=true
	p.position=Vector3(0,0.4,-70)
	b._physics_process(0.02)
	check(not b.engaged and b.hp==b.max_hp,"leaving the arena resets boss health and engagement")
	g._clear_effects()
	# The two gates and courtyard must form an actually traversable path.
	p.position=Vector3(0,0.5,-42)
	p.yaw=0
	p.restore()
	Input.action_press("forward")
	await frames(g,455)
	Input.action_release("forward")
	check(p.position.z<-79,"player can physically traverse both castle gates")
	g.quest_active=true
	g.kills=3
	g.checkpoint=Vector3(5,0.3,-65)
	p.gold=123
	p.flasks=6
	g.save_game("user://smoke_save.json")
	p.gold=1
	g.quest_active=false
	check(g.load_game("user://smoke_save.json"),"saved JSON reloads successfully")
	check(p.gold==123 and g.quest_active and g.checkpoint.z==-65,"save restores inventory, quest and checkpoint")
	check(p.flasks==6,"purchased flask count survives save and load")
	for foe in g.enemies:
		foe.set_physics_process(false)
	p.hp=10
	p.invulnerable=0
	p.take_damage(20,Vector3.ZERO)
	check(g.mode=="dead" and p.dead,"lethal damage enters the death screen")
	g.respawn()
	check(g.mode=="play" and p.hp==p.max_hp and not p.dead,"respawn restores the player and resumes play")
	check(p.position.distance_to(g.checkpoint)<0.01,"respawn returns to the saved shrine")
	for foe in g.enemies:
		foe.set_physics_process(false)
	p.position=g.boss.home+Vector3(0,0,6)
	g.boss.hp=1
	var bolt_origin=p.global_position+Vector3.UP*1.3
	var bolt_dir=(g.boss.global_position+Vector3.UP*2.0-bolt_origin).normalized()
	g.fire_projectile(bolt_origin,bolt_dir,27,30,p,false)
	await frames(g,30)
	check(g.boss_defeated and g.mode=="victory","defeating the boss enters the victory state")
	check(g.effects.is_empty(),"a lethal projectile safely clears all effects during effect iteration")
	g.reward_quest()
	var final_gold=p.gold
	g.reward_quest()
	check(p.gold==final_gold and g.quest_rewarded,"quest reward can only be claimed once")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://smoke_save.json"))
	print("RESULT: %d passed, %d failed" % [passed,failures.size()])
	g.get_tree().quit(0 if failures.is_empty() else 1)
