class_name Hero
extends CharacterBody3D

var profile: Dictionary=CharacterProfile.clean({})
var max_mana=100.0
var level=1
var experience=0
var game: Node3D
var spellcraft: Spellcraft
var network_id = 0
var network_driven = false
var network_move = Vector2.ZERO
var network_sprint = false
var mount_visual: Node3D
var personal_checkpoint = Vector3(4,0.4,30)
var personal_quest = false
var personal_reward = false
var personal_kills = 0

var rig: Node3D
var visual: Node3D
var camera: Camera3D
var camera_pivot: Node3D
var spring: SpringArm3D
var yaw = 0.0
var pitch = -0.27
var hp = 140.0
var max_hp = 140.0
var mana = 100.0
var stamina = 100.0
var flasks = 4
var gold = 80
var herbs = 0
var upgrades = 0
var food_time = 0.0
var mounted = false
var invulnerable = 0.0
const ROLL_DURATION = 0.72
const LIGHT_DURATIONS = [0.62,0.66,0.86]
const LIGHT_HIT_PHASES = [0.32,0.34,0.32]
var roll_time = 0.0
var roll_direction = Vector3.ZERO
var queued_attack = -1
var sword_trail: BladeTrail
var attack_time = 0.0
var attack_length = 0.0
var attack_hit = false
var heavy = false
var combo = 0
var combo_window = 0.0
var cast_duration = 0.55
var cast_time = 0.0:
	set(value):
		if value>cast_time:cast_duration=value
		cast_time=value
var locomotion_time = 0.0
var skill_cooldown = 0.0
var heal_cooldown = 0.0
var stagger = 0.0
var stamina_delay = 0.0
var death_time=0.0
var dead = false
var locked_target: Node3D
var anim_time = 0.0
var spell_page = 0
var spell_cooldowns: Dictionary = {}
var ward_time = 0.0
var ward_hp = 0.0

func cooldown(index: int) -> float:
	if index==2:return skill_cooldown
	if index==3:return heal_cooldown
	return float(spell_cooldowns.get(index,0.0))

func cast_slot(slot: int) -> bool:
	var index=skill_index(slot)
	var spell=Spellcraft.SPELLS[index]
	if not can_act():return false
	if cooldown(index)>0:
		game.toast(spell.name+"尚未就緒","剩餘 %.1f 秒" % cooldown(index))
		return false
	if mana<spell.cost:
		game.toast("魔力不足","%s 需要 %d MP" % [spell.name,spell.cost])
		return false
	if index==2 and stamina<20:return false
	if index==3 and hp>=max_hp:return false
	if index<2:
		cast_spell(index==1)
	else:
		mana-=spell.cost
		cast_time=spell.cast
		if index==2:
			stamina-=20
			skill_cooldown=spell.cd
			spellcraft.cast_flourish(global_position,Color(spell.color))
			spellcraft.impact(global_position,Color(spell.color),5.3,true)
			for i in 3:spellcraft.slash_fx(global_position+Vector3.UP*(0.6+i*0.4),visual.rotation.y+i*TAU/3,true)
			game.player_melee(5.3,58+upgrades*8,true,self)
			game.sound("skill")
		elif index==3:
			heal_cooldown=spell.cd
			hp=minf(max_hp,hp+55)
			spellcraft.cast_flourish(global_position,Color(spell.color))
			for i in 3:spellcraft.circle(global_position+Vector3.UP*i*0.5,1.2+i*0.2,Color(spell.color),1.2)
			game.sound("heal")
		else:spellcraft.cast(index)
	spell_cooldowns[index]=spell.cd
	if network_driven:game.net.cast_effect(self,index)
	return true

func setup(owner_game: Node3D) -> void:
	game = owner_game
	collision_layer = 2
	collision_mask = 1 | 4
	floor_snap_length = 0.6
	var shape = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.92
	add_child(shape)
	visual = Art.pivot(self,"Visual",Vector3.ZERO)
	rig = Art.knight(visual)
	var blade=Art.sword(Art.socket(rig,"ArmR"))
	sword_trail=BladeTrail.new()
	add_child(sword_trail)
	sword_trail.setup(blade)
	_equip_shield()
	camera_pivot=Art.pivot(self,"CameraPivot",Vector3(0,1.5,0))
	spring=SpringArm3D.new()
	spring.spring_length=6.8
	spring.margin=0.25
	spring.collision_mask=1
	spring.add_excluded_object(get_rid())
	camera_pivot.add_child(spring)
	camera=Camera3D.new()
	camera.fov=64
	camera.near=0.1
	camera.far=350
	spring.add_child(camera)
	camera.current=true

func _unhandled_input(event: InputEvent) -> void:
	if network_driven:
		if game.net.is_local(self):game.net.player_input(event)
		return
	if game.mode != "play" or dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.0026
		pitch=clampf(pitch-event.relative.y*0.0023,-0.95,0.3)
	if event.is_action_pressed("lock_on"):
		if is_instance_valid(locked_target):
			locked_target=null
		else:
			locked_target=game.nearest_enemy(global_position,24)
	if event.is_action_pressed("mount"):
		game.toggle_mount()
	if event.is_action_pressed("flask") and flasks>0 and hp<max_hp and attack_time<=0 and roll_time<=0:
		flasks-=1
		hp=minf(max_hp,hp+75)
		cast_time=0.55
		game.burst(global_position+Vector3.UP,Color("f4ce88"),1.2)
		game.sound("heal")
	if event.is_action_pressed("spell_page"):
		spell_page=(spell_page+1)%3
	if event.is_action_pressed("roll") and can_act() and stamina>=24 and not mounted:
		var axis=movement_input()
		roll_direction=(Basis(Vector3.UP,yaw)*Vector3(axis.x,0,axis.y)).normalized()
		if roll_direction.length()<0.1:
			roll_direction=-visual.global_basis.z
		roll_time=ROLL_DURATION
		invulnerable=0.37
		stamina-=24
		stamina_delay=0.8
		game.sound("roll")
	if event.is_action_pressed("attack"):
		begin_attack(false)
	if event.is_action_pressed("heavy"):
		begin_attack(true)
	if event.is_action_pressed("bolt"):
		cast_slot(0)
	if event.is_action_pressed("frost"):
		cast_slot(1)
	if event.is_action_pressed("skill"):
		cast_slot(2)
	if event.is_action_pressed("heal"):
		cast_slot(3)

func movement_input() -> Vector2:
	return network_move if network_driven else Input.get_vector("left","right","forward","back")

func server_action(action: String, value: int = 0) -> void:
	match action:
		"attack":begin_attack(false)
		"heavy":begin_attack(true)
		"cast":
			spell_page=value/4
			cast_slot(value%4)
		"roll":
			if can_act() and stamina>=24 and not mounted:
				roll_direction=(Basis(Vector3.UP,yaw)*Vector3(network_move.x,0,network_move.y)).normalized()
				if roll_direction.length()<0.1:roll_direction=-visual.global_basis.z
				roll_time=ROLL_DURATION
				invulnerable=0.37
				stamina-=24
				stamina_delay=0.8
		"flask":
			if can_act() and flasks>0 and hp<max_hp:
				flasks-=1
				hp=minf(max_hp,hp+75)
				cast_time=0.55
		"mount":
			if can_act():mounted=not mounted

func update_replica(delta: float) -> void:
	rig.rotation.z=0
	if dead:
		death_time+=delta
		rig.pose("death",minf(1,death_time/1.4),delta,0.04)
		sword_trail.active=false
		if mount_visual:mount_visual.hide()
		return
	death_time=0
	anim_time+=delta
	attack_time=maxf(0,attack_time-delta)
	roll_time=maxf(0,roll_time-delta)
	cast_time=maxf(0,cast_time-delta)
	if roll_time>0 and rig is AnimatedCharacter:
		rig.position.y=0
		rig.pose("roll",1.0-roll_time/ROLL_DURATION,delta,0.045)
	else:_animate(delta,Vector2(velocity.x,velocity.z).length())
	sword_trail.active=not dead and attack_time>0 and attack_time<attack_length*0.8 and attack_time>attack_length*0.33
	if mount_visual:
		mount_visual.visible=mounted and not dead
		mount_visual.global_position=global_position
		mount_visual.rotation.y=visual.rotation.y
		var leg_index=0
		for leg in mount_visual.get_children():
			if leg.name.begins_with("Leg"):
				leg.rotation.x=sin(anim_time*12+leg_index*2.5)*minf(0.7,velocity.length()*0.07)
				leg_index+=1

func can_act() -> bool:
	return not dead and roll_time<=0 and attack_time<=0 and cast_time<=0 and stagger<=0

func begin_attack(is_heavy: bool) -> void:
	if attack_time>0 and attack_time<0.22:
		queued_attack=1 if is_heavy else 0
		return
	var cost=31.0 if is_heavy else 17.0
	if not can_act() or stamina<cost:
		return
	stamina-=cost
	stamina_delay=0.8
	heavy=is_heavy
	combo=(combo+1)%3 if combo_window>0 else 0
	combo_window=1.7
	attack_length=1.08 if heavy else LIGHT_DURATIONS[combo]
	attack_time=attack_length
	attack_hit=false
	if is_instance_valid(locked_target):
		face(locked_target.global_position-global_position,1.0)
	game.sound("sword")

func cast_spell(frost: bool) -> void:
	var cost=25.0 if frost else 13.0
	if not can_act() or mana<cost:
		return
	mana-=cost
	cast_time=0.48
	var direction=-visual.global_basis.z
	var origin=global_position+Vector3.UP*(2.4 if mounted else 1.35)
	var enemy=locked_target if is_instance_valid(locked_target) else game.nearest_enemy(global_position,26)
	if is_instance_valid(enemy):
		direction=(enemy.global_position+Vector3.UP*(2.2 if enemy.is_boss else 1.2)-origin).normalized()
		face(direction,1.0)
	game.fire_projectile(origin+direction*0.7,direction,27.0,30.0+upgrades*4, self, frost)
	spellcraft.cast_flourish(global_position,Color("8ee9ff") if frost else Color("ffbc6b"))
	game.sound("spell")

func _physics_process(delta: float) -> void:
	if network_driven and not game.net.authoritative():return
	if sword_trail:
		var phase=1.0-attack_time/maxf(attack_length,0.001)
		sword_trail.active=game.world_running() and not dead and attack_time>0 and phase>0.2 and phase<0.67
	if not is_instance_valid(game) or not game.world_running():
		return
	anim_time+=delta
	invulnerable=maxf(0,invulnerable-delta)
	skill_cooldown=maxf(0,skill_cooldown-delta)
	heal_cooldown=maxf(0,heal_cooldown-delta)
	for index in spell_cooldowns:spell_cooldowns[index]=maxf(0,spell_cooldowns[index]-delta)
	ward_time=maxf(0,ward_time-delta)
	if ward_time<=0:ward_hp=0
	food_time=maxf(0,food_time-delta)
	combo_window=maxf(0,combo_window-delta)
	stagger=maxf(0,stagger-delta)
	cast_time=maxf(0,cast_time-delta)
	stamina_delay=maxf(0,stamina_delay-delta)
	if dead:
		return
	mana=minf(max_mana,mana+delta*2.8)
	if stamina_delay<=0:
		stamina=minf(100,stamina+delta*(31 if food_time>0 else 23))
	if is_instance_valid(locked_target):
		if locked_target.dead or global_position.distance_to(locked_target.global_position)>30:
			locked_target=null
		else:
			var d=locked_target.global_position-global_position
			yaw=lerp_angle(yaw,atan2(-d.x,-d.z),delta*3.5)
	camera_pivot.rotation=Vector3(pitch,yaw,0)
	camera_pivot.position.y=lerpf(camera_pivot.position.y,2.65 if mounted else 1.5,delta*8)
	var axis=movement_input()
	var dir=Basis(Vector3.UP,yaw)*Vector3(axis.x,0,axis.y)
	var speed=5.4*CharacterProfile.SPEED[profile.job]
	var sprint=(network_sprint if network_driven else Input.is_action_pressed("sprint")) and stamina>1 and dir.length()>0.1 and can_act()
	if mounted:
		speed=15 if sprint else 9.2
	elif sprint:
		speed=8.8*CharacterProfile.SPEED[profile.job]
		stamina=maxf(0,stamina-delta*14)
		stamina_delay=0.7
	if attack_time>0:
		attack_time=maxf(0,attack_time-delta)
		speed*=0.25
		var progress=1.0-attack_time/attack_length
		if progress>(0.48 if heavy else LIGHT_HIT_PHASES[combo]) and not attack_hit:
			attack_hit=true
			game.player_melee(4.4 if mounted else (3.4 if heavy else 2.9),(48 if heavy else 24+combo*5)+upgrades*6,false,self)
			game.slash(global_position+Vector3.UP*(2.0 if mounted else 1.1),visual.rotation.y,heavy)
	if stagger>0 or cast_time>0:
		speed*=0.2
	if roll_time>0:
		roll_time=maxf(0,roll_time-delta)
		var roll_progress=1.0-roll_time/ROLL_DURATION
		var roll_speed=3.0+8.7*sin(PI*roll_progress)
		velocity.x=roll_direction.x*roll_speed
		velocity.z=roll_direction.z*roll_speed
		face(roll_direction,1)
		rig.position.y=0
		if rig is AnimatedCharacter:
			rig.pose("roll",roll_progress,delta,0.045)
		else:
			rig.rotation.x=-TAU*roll_progress
	else:
		rig.rotation.x=0
		velocity.x=move_toward(velocity.x,dir.x*speed,delta*38)
		velocity.z=move_toward(velocity.z,dir.z*speed,delta*38)
		if dir.length()>0.1 and attack_time<=0:
			face(dir,delta*12)
		_animate(delta,Vector2(velocity.x,velocity.z).length())
	if not is_on_floor():
		velocity.y-=22*delta
	else:
		velocity.y=-0.1
	move_and_slide()
	if attack_time<=0 and queued_attack>=0:
		var next_heavy=queued_attack==1
		queued_attack=-1
		begin_attack(next_heavy)
	if global_position.y < -12:
		take_damage(1000,Vector3.ZERO)
	if network_driven and is_instance_valid(mount_visual):mount_visual.visible=mounted and not dead
	if mounted:
		var riding_horse=mount_visual if network_driven else game.horse
		if riding_horse==null:return
		riding_horse.global_position=global_position
		riding_horse.rotation.y=visual.rotation.y
		var i=0
		for leg in riding_horse.get_children():
			if leg.name.begins_with("Leg"):
				leg.rotation.x=sin(anim_time*12+i*2.5)*minf(0.7,dir.length()*0.7)
				i+=1

func _animate(delta: float, speed: float) -> void:
	if mounted:
		var mount=mount_visual if network_driven else game.horse
		if mount is PublicCharacter:
			locomotion_time+=delta*(clampf(speed/(12.0 if speed>5 else 3.0),0.3,1.5) if speed>.3 else 1.0)
			mount.cycle("run" if speed>5 else "walk" if speed>.3 else "idle",locomotion_time,delta)
	if rig is AnimatedCharacter:
		rig.position.y=saddle_height() if mounted else 0.0
		if attack_time>0:
			rig.sword_pose(combo,heavy,1.0-attack_time/attack_length,delta)
		elif stagger>0:
			rig.pose("hurt",1.0-stagger/0.26,delta,0.04)
		elif cast_time>0:
			rig.pose("cast",1.0-cast_time/maxf(cast_duration,0.01),delta,0.06)
		elif mounted:
			rig.riding_pose(anim_time,delta)
		else:
			var clip="sprint" if speed>6.5 else "run" if speed>3 else "walk" if speed>0.25 else "idle"
			var stride_speed=8.8*CharacterProfile.SPEED[profile.job] if clip=="sprint" else 5.4 if clip=="run" else 2.2
			locomotion_time+=delta*(clampf(speed/stride_speed,0.25,1.6) if speed>0.25 else 1.0)
			rig.cycle(clip,locomotion_time,delta)
		if mounted:rig.apply_riding_posture()
		return
	var stride=sin(anim_time*(12 if speed>6 else 8))*minf(speed/6.0,0.8)
	rig.position.y=(1.07 if mounted else 0.0)+absf(sin(anim_time*8))*minf(0.045,speed*0.007)
	rig.get_node("LegL").rotation.x=-0.8 if mounted else stride
	rig.get_node("LegR").rotation.x=-0.8 if mounted else -stride
	rig.get_node("LegL").rotation.z=0.35 if mounted else 0.0
	rig.get_node("LegR").rotation.z=-0.35 if mounted else 0.0
	for side in ["LegL","LegR"]:
		var leg=rig.get_node(side)
		if leg.has_node("Knee"):
			leg.get_node("Knee").rotation.x=0.9 if mounted else maxf(0,-leg.rotation.x)*1.25
	rig.get_node("ArmL").rotation.x=lerpf(rig.get_node("ArmL").rotation.x,-stride*0.45,delta*14)
	var arm=rig.get_node("ArmR")
	if attack_time>0:
		var p=1-attack_time/attack_length
		arm.rotation.x=-sin(p*PI)*2.2
		arm.rotation.y=lerpf(-1.5,1.6,clampf((p-0.2)*2,0,1))*(1 if combo%2==0 else -1)
	elif cast_time>0:
		arm.rotation.x=-1.5
	else:
		arm.rotation=arm.rotation.lerp(Vector3(stride*0.45,0,0),delta*12)
	if arm.has_node("Elbow"):
		arm.get_node("Elbow").rotation.x=-0.3 if attack_time>0 else -0.12
	rig.get_node("Cape").rotation.x=sin(anim_time*3)*0.07+speed*0.025

func face(direction: Vector3, weight: float) -> void:
	visual.rotation.y=lerp_angle(visual.rotation.y,atan2(-direction.x,-direction.z),minf(1,weight))

func take_damage(amount: float, from: Vector3) -> bool:
	if network_driven and not game.net.authoritative():return false
	if dead or invulnerable>0:
		return false
	if ward_time>0 and ward_hp>0:
		var blocked=minf(ward_hp,amount)
		ward_hp-=blocked
		amount-=blocked
		spellcraft.impact(global_position+Vector3.UP,Color("84ddff"),1.2)
		if amount<=0:
			invulnerable=0.25
			return true
	hp=maxf(0,hp-amount)
	invulnerable=0.55
	stagger=0.26
	game.damage_flash=0.4
	game.sound("hurt")
	if from != Vector3.ZERO:
		var push=(global_position-from).normalized()*4
		velocity.x+=push.x
		velocity.z+=push.z
	if hp<=0:
		dead=true
		death_time=0
		var tween=create_tween()
		tween.tween_method(func(t:float):
			if dead:rig.pose("death",t,.016,0.04),0.0,1.0,1.4)
		game.hero_died(self)
	return true

func restore() -> void:
	hp=max_hp
	mana=max_mana
	stamina=100
	flasks=4
	dead=false
	death_time=0
	attack_time=0
	queued_attack=-1
	roll_time=0
	stagger=0
	cast_time=0
	spell_cooldowns.clear()
	skill_cooldown=0
	heal_cooldown=0
	ward_time=0
	ward_hp=0
	invulnerable=1.5
	locked_target=null
	velocity=Vector3.ZERO
	rig.rotation=Vector3.ZERO

func skill_index(slot: int) -> int:
	return profile.skills[spell_page*4+slot]

func _equip_shield() -> void:
	var shield=PublicAssets.place(Art.socket(rig,"ArmL"),"character-pack-adventures/shield_round",Vector3(-.06,.02,.035),.6)
	shield.rotation.y=PI/2

func apply_profile(value: Dictionary) -> void:
	var next=CharacterProfile.clean(value)
	var swap=next.gender!=profile.gender
	profile=next
	refresh_growth()
	if swap and is_instance_valid(rig):
		var old=rig
		visual.remove_child(old)
		old.queue_free()
		rig=AnimatedCharacter.new()
		visual.add_child(rig)
		rig.configure("hero_female_rigged" if profile.gender==1 else "hero_rigged")
		Art.toon(rig)
		sword_trail.points.clear()
		sword_trail.setup(Art.sword(Art.socket(rig,"ArmR")))
		_equip_shield()
	hp=minf(hp,max_hp)
	mana=minf(mana,max_mana)

func saddle_height() -> float:
	return 1.22 if profile.gender==1 else 1.07

func refresh_growth() -> void:
	max_hp=CharacterProfile.HEALTH[profile.job]+(level-1)*Progression.HEALTH_GROWTH[profile.job]
	max_mana=CharacterProfile.MANA[profile.job]+(level-1)*Progression.MANA_GROWTH[profile.job]

func damage_multiplier() -> float:
	return 1.0+(level-1)*.025

func load_progress(value: Dictionary) -> void:
	level=maxi(1,Progression.safe_integer(value.get("level",1),1,Progression.MAX_LEVEL))
	experience=Progression.safe_integer(value.get("experience",0),0,1000000)
	# Save files store progress within the current level, never grant unearned extra levels.
	experience=clampi(experience,0,maxi(0,Progression.required(level)-1))
	refresh_growth()
	hp=minf(hp,max_hp)
	mana=minf(mana,max_mana)

func gain_experience(amount: int) -> int:
	if network_driven and not game.net.authoritative():return 0
	if amount<=0 or level>=Progression.MAX_LEVEL:return 0
	var old_level=level
	var old_hp=max_hp
	var old_mana=max_mana
	experience+=mini(amount,1000000)
	while level<Progression.MAX_LEVEL and experience>=Progression.required(level):
		experience-=Progression.required(level)
		level+=1
	if level==Progression.MAX_LEVEL:experience=0
	refresh_growth()
	if not dead:
		hp=minf(max_hp,hp+max_hp-old_hp)
		mana=minf(max_mana,mana+max_mana-old_mana)
	return level-old_level
