class_name Foe
extends CharacterBody3D

var game: Node3D
var combat_target: Hero
var kind = "sentinel"
var title = "荊棘遊兵"
var visual_asset=""
var visual_ready=false
var rig: Node3D
var visual: Node3D
var hp = 90.0
var max_hp = 90.0
var home = Vector3.ZERO
var rewarded=false
var dead = false
var death_elapsed=0.0
var is_boss = false
var boss_profile = -1
var phase = 1
var state = "idle"
var timer = 0.0
var recovery = 0.0
var slowed = 0.0
var poise = 0.0
var attack_index = 0
var swing_index = 0
var hits_done = 0
var attack: Dictionary = {}
var aim = Vector3.FORWARD
var engaged = false
var anim_time = 0.0
var tell: MeshInstance3D
var nameplate: Label3D
var health_mesh: MeshInstance3D

func setup(owner_game: Node3D, enemy_kind: String, pos: Vector3) -> void:
	game=owner_game
	kind=enemy_kind
	is_boss=kind in ["boss","guardian"]
	home=pos
	position=pos
	collision_layer=4
	collision_mask=1|2|4
	floor_snap_length=0.7
	var c=CollisionShape3D.new()
	var cap=CapsuleShape3D.new()
	cap.radius=0.78 if is_boss else 0.38
	cap.height=3.5 if is_boss else 1.8
	c.shape=cap
	c.position.y=cap.height/2
	add_child(c)
	visual=Art.pivot(self,"Visual",Vector3.ZERO)
	var asset="character-pack-skeletons/Skeleton_Warrior"
	if is_boss:
		title="天穹古龍 · 奧瑞利昂"
		max_hp=3400
		asset="monsters/Dragon"
	elif kind=="mage":
		title="霜冠骸骨術師"
		max_hp=100
		asset="character-pack-skeletons/Skeleton_Mage"
	elif kind=="elite":
		title="日冕遺跡重衛"
		max_hp=280
		asset="character-pack-skeletons/Skeleton_Warrior"
	elif kind=="slime":
		title="鏡露晶凍"
		max_hp=70
		asset="monsters/Slime"
	elif kind=="bat":
		title="霜翼蝙蝠"
		max_hp=65
		asset="monsters/Bat"
	else:
		title="遺跡骸骨遊兵"
	if kind=="guardian":
		title=WorldAtlas.dungeons[boss_profile].boss
		max_hp=1400+boss_profile*85
		var models=["MushroomKing","Monkroose","Orc","Yeti","Orc_Skull","Cactoro","Ninja","Fish","Demon","Alien","Tribal","BlueDemon","Birb","Dino","Ninja","Frog","Demon","Bunny","BlueDemon"]
		asset="ultimate-monsters/"+models[boss_profile]
	visual_asset=asset
	rig=AnimatedCharacter.new()
	rig.name="Rig"
	rig.source_asset=asset
	visual.add_child(rig)
	if not game.net.dedicated and pos.length_squared()<250000:ensure_visual()
	hp=max_hp
	nameplate=Art.label3d(self,title,Vector3(0,4.8 if is_boss else 2.65,0),Color("efe4ca"),26)
	nameplate.visible=false
	health_mesh=Art.box(self,Vector3(0,2.36 if not is_boss else 4.4,0),Vector3(1.15,0.065,0.055),Color("cb846c"))
	health_mesh.visible=false

func _physics_process(delta: float) -> void:
	if not is_instance_valid(game) or not game.world_running() or dead:
		return
	anim_time+=delta
	slowed=maxf(0,slowed-delta)
	if game.net and game.net.online and not game.net.authoritative():return
	combat_target=game.closest_player(global_position)
	if combat_target==null:
		velocity=Vector3.ZERO
		return
	var player=combat_target
	if player.dead:
		return
	var distance=global_position.distance_to(player.global_position)
	if distance>120:
		if engaged:reset()
		velocity=Vector3.ZERO
		return
	ensure_visual()
	nameplate.visible=not is_boss and distance<12
	health_mesh.visible=not is_boss and hp<max_hp and distance<16
	health_mesh.scale.x=maxf(0.001,hp/max_hp)
	if is_boss:
		if not engaged and player.global_position.distance_to(home)<17:
			engaged=true
			game.toast(title+"甦醒", "觀察刀勢。翻滾閃避；重擊與日輪斬能打破架勢。")
		if engaged and player.global_position.distance_to(home)>29:
			reset()
			game.toast("已離開聖域", "古龍恢復了力量。")
		if not engaged:
			if rig is AnimatedCharacter:rig.cycle("idle",anim_time,delta)
			return
	elif global_position.distance_to(home)>22 or distance>26:
		state="return"
	elif distance<15 and game.can_see(global_position+Vector3.UP,player.global_position+Vector3.UP,self):
		engaged=true
	if state=="return":
		var d=home-global_position
		_walk(d,3,delta)
		if d.length()<1:
			reset()
	elif state=="windup":
		timer+=delta
		velocity.x=0
		velocity.z=0
		# Slow attacks track only during the first 65% of the tell, then commit.
		if timer<float(attack.windup)*0.65:
			aim=(player.global_position-global_position).normalized()
			_face(aim,delta*5)
		if not rig is AnimatedCharacter:
			var arm=rig.get_node("ArmR")
			arm.rotation.x=lerpf(arm.rotation.x,-2.35,delta*5)
			arm.rotation.y=-0.65
		if timer>=float(attack.windup):
			state="swing"
			timer=0
			hits_done=0
			game.slash(global_position+Vector3.UP*(2 if is_boss else 1),visual.rotation.y,is_boss)
	elif state=="swing":
		timer+=delta
		var intervals: Array=attack.get("hits",[0.1])
		if hits_done<intervals.size() and timer>=float(intervals[hits_done]):
			_execute_hit(hits_done)
			hits_done+=1
		velocity.x=aim.x*float(attack.get("lunge",3.0)) if timer<0.3 else 0.0
		velocity.z=aim.z*float(attack.get("lunge",3.0)) if timer<0.3 else 0.0
		if not rig is AnimatedCharacter:
			rig.get_node("ArmR").rotation.x=lerpf(-2.3,1.0,clampf(timer*4,0,1))
			rig.get_node("ArmR").rotation.y=sin(timer*10)*1.5
		if timer>float(intervals[-1])+0.3:
			state="recover"
			timer=float(attack.get("recovery",1.1))
	elif state=="recover" or state=="stagger":
		timer-=delta
		velocity.x=0
		velocity.z=0
		if not rig is AnimatedCharacter:
			rig.get_node("ArmR").rotation=rig.get_node("ArmR").rotation.lerp(Vector3.ZERO,delta*5)
		if timer<=0:
			state="idle"
	elif engaged:
		var d=player.global_position-global_position
		var reach=8.0 if kind=="mage" else (5.8 if is_boss else 2.6)
		if distance>reach:
			_walk(d,3.6 if is_boss else 2.8,delta)
		else:
			_start_attack()
	else:
		velocity.x=0
		velocity.z=0
	if not is_on_floor():
		velocity.y-=22*delta
	else:
		velocity.y=-0.2
	move_and_slide()
	var speed=Vector2(velocity.x,velocity.z).length()
	if rig is AnimatedCharacter:
		_animate_skeleton(delta,speed)
	else:
		rig.get_node("LegL").rotation.x=sin(anim_time*7)*minf(speed*0.18,0.5)
		rig.get_node("LegR").rotation.x=-sin(anim_time*7)*minf(speed*0.18,0.5)
	if rig.has_node("Cape"):
		rig.get_node("Cape").rotation.x=0.12+sin(anim_time*3)*0.07

func _animate_skeleton(delta: float, speed: float) -> void:
	var spell=attack.get("type","melee")!="melee"
	var delayed=float(attack.get("windup",0.5))>1.3
	if state=="windup":
		# Stretch only the anticipation; the blade release remains fast.
		var p=clampf(timer/float(attack.windup),0,1)
		rig.pose("cast" if spell else "heavy" if delayed else "slash_a",p*(0.40 if delayed else 0.24),delta,0.07)
	elif state=="swing":
		if spell:
			rig.pose("cast",0.24+timer*1.9,delta,0.04)
		else:
			var hits:Array=attack.hits
			var index=0
			while index+1<hits.size() and timer>float(hits[index])+0.23:index+=1
			var until=timer-float(hits[index])
			var clip="heavy" if delayed else "slash_a" if index%2==0 else "slash_b"
			var impact=0.48 if delayed else 0.52
			rig.pose(clip,clampf(impact+until*2.4,0.2,1),delta,0.035)
	elif state=="recover":
		rig.cycle("idle",anim_time,delta)
	elif state=="stagger":
		rig.pose("hurt",0.48,delta)
	else:
		rig.cycle("walk" if speed>0.3 else "idle",anim_time,delta,1.35 if speed>0.3 else 1.0)

func _walk(d: Vector3, speed: float, delta: float) -> void:
	d.y=0
	d=d.normalized()
	_face(d,delta*6)
	var actual=speed*(0.5 if slowed>0 else 1.0)
	velocity.x=d.x*actual
	velocity.z=d.z*actual

func _face(d: Vector3, weight: float) -> void:
	visual.rotation.y=lerp_angle(visual.rotation.y,atan2(-d.x,-d.z),minf(1,weight))

func _start_attack() -> void:
	if not is_instance_valid(combat_target) or combat_target.dead:
		combat_target=game.closest_player(global_position)
	if combat_target==null:return
	if is_boss:
		var patterns = [
			{"name":"迅翼二連", "windup":0.43,"hits":[0.08,0.58],"damage":23,"range":5.3,"recovery":0.85,"lunge":5.0},
			{"name":"遲暮龍爪", "windup":1.8,"hits":[0.1],"damage":58,"range":6.4,"recovery":1.7,"lunge":8.0},
			{"name":"日蝕掃尾", "windup":0.62,"hits":[0.08,0.56,1.48],"damage":28,"range":5.7,"recovery":1.4,"lunge":4.0},
			{"name":"天穹落印", "windup":1.15,"hits":[0.1],"damage":38,"range":18.0,"recovery":1.5,"type":"sigils","lunge":0.0},
			{"name":"日輪震波", "windup":1.05,"hits":[0.1],"damage":35,"range":12.0,"recovery":1.7,"type":"wave","lunge":0.0}
		]
		if phase>=2:
			patterns.append({"name":"星焰吐息","windup":1.4,"hits":[0.1,0.55,1.0],"damage":28,"range":22,"recovery":1.8,"type":"breath","lunge":0.0})
		if phase==3:
			patterns.append({"name":"天穹審判","windup":2.2,"hits":[0.1,0.8],"damage":38,"range":22,"recovery":2.4,"type":"sigils","lunge":0.0})
		if boss_profile>=0:
			# Five tactical families, with distinct delays, combinations and phase escalation.
			var family=boss_profile%5
			var signature=["wave","sigils","melee","breath","bolt"][family]
			patterns[3].type=signature
			patterns[3].name=title+" · "+["大地迴響","追獵落印","破陣突襲","熾光扇射","連珠星火"][family]
			patterns[3].lunge=10.0 if family==2 else 0.0
			patterns[3].hits=[.1,.6] if family in [1,3,4] else [.1]
			patterns[0].hits=[.08,.42,.95] if boss_profile%3==0 else [.08,.68]
			patterns[1].windup=1.45+float(boss_profile%4)*.23
			if family==4:patterns[0].type="bolt"
			if family==1:patterns[4].type="sigils"
		attack=patterns[(attack_index+maxi(0,boss_profile))%patterns.size()].duplicate(true)
		if phase>=2:
			attack.windup*=0.85
			attack.recovery*=0.85
			if attack_index%5==0:
				attack.hits=[0.08,0.5,1.1]
		attack_index+=1
	elif kind=="mage":
		attack={"name":"星火","windup":0.95,"hits":[0.1],"damage":18,"range":20,"type":"bolt","recovery":1.5,"lunge":0.0}
	else:
		var slow=attack_index%3==1
		attack={"name":"蓄力斬" if slow else "斬擊","windup":1.3 if slow else 0.65,"hits":[0.1],"damage":32 if kind=="elite" else 17,"range":3.5 if kind=="elite" else 2.7,"recovery":1.35,"lunge":3.0}
		attack_index+=1
	aim=(combat_target.global_position-global_position).normalized()
	_face(aim,1)
	state="windup"
	timer=0
	game.burst(global_position+Vector3.UP*(3.5 if is_boss else 1.8),Color("f1b267") if float(attack.windup)>1.3 else Color("edf0cb"),0.4)

func _execute_hit(index: int) -> void:
	if not is_instance_valid(combat_target) or combat_target.dead:
		combat_target=game.closest_player(global_position)
	if combat_target==null:return
	var type=attack.get("type","melee")
	if type=="breath":
		# A committed fan has gaps between bolts and can be dodged laterally.
		for lane in [-2,-1,0,1,2]:
			var direction=aim.rotated(Vector3.UP,float(lane)*0.19)
			game.fire_projectile(global_position+Vector3.UP*1.5+direction*1.8,direction,15,28,self,false)
	elif type=="sigils":
		for i in range(7 if phase==3 else 5 if phase==2 else 3):
			var offset=Vector3(cos(i*2.4),0,sin(i*2.4))*i*1.9
			game.make_hazard(combat_target.global_position+offset,2.25,1.1+i*0.19,38,self)
	elif type=="wave":
		game.shockwave(global_position,phase)
	elif type=="bolt":
		var dir=(combat_target.global_position+Vector3.UP-global_position-Vector3.UP*1.5).normalized()
		game.fire_projectile(global_position+Vector3.UP*1.5+dir*0.7,dir,13,18,self,false)
	else:
		# Delayed combo finishers redirect; every strike has its own visible swing.
		if index>0:
			aim=(combat_target.global_position-global_position).normalized()
			_face(aim,1)
		game.slash(global_position+Vector3.UP*(2 if is_boss else 1),visual.rotation.y,is_boss)
		var to_player=combat_target.global_position-global_position
		to_player.y=0
		if to_player.length()<float(attack.range) and aim.dot(to_player.normalized())>0.15 and game.can_see(global_position+Vector3.UP,combat_target.global_position+Vector3.UP,self):
			combat_target.take_damage(float(attack.damage),global_position)
		game.sound("boss" if is_boss else "sword")

func take_damage(amount: float, frost: bool = false, force: bool = false, attacker: Hero = null) -> void:
	if game.net and game.net.online and not game.net.authoritative():return
	if dead:
		return
	if is_instance_valid(attacker):amount*=attacker.damage_multiplier()
	engaged=true
	hp=maxf(0,hp-amount)
	poise+=amount*(1.6 if force else 1.0)
	if frost:
		slowed=4.0
	game.floating_text(str(int(amount)),global_position+Vector3.UP*(3 if is_boss else 1.8),Color("f6d79e"))
	game.burst(global_position+Vector3.UP,Color("9ad5d3") if frost else Color("edca86"),0.5)
	if hp<=0:
		dead=true
		collision_layer=0
		collision_mask=0
		nameplate.visible=false
		health_mesh.visible=false
		game.enemy_defeated(self)
		var tween=create_tween()
		if rig is AnimatedCharacter and rig.clips.has("death"):
			tween.tween_method(func(t:float):rig.pose("death",t,.016,0),0.0,1.0,1.0)
		else:tween.tween_property(visual,"rotation:x",-PI/2,0.6)
		tween.tween_property(visual,"scale",Vector3.ONE*0.01,1.2).set_delay(1)
	elif is_boss and phase<3 and hp<max_hp*(0.30 if phase==2 else 0.66):
		phase+=1
		state="recover"
		timer=2.4
		poise=0
		game.toast("第三階段 · 天穹審判" if phase==3 else "第二階段 · 星焰甦醒", "觀察蓄力與地面落印；吐息間有閃避空隙。")
		game.ring_effect(global_position,7,Color("efcb8c"),1.5)
		game.make_hazard(global_position,6.5,2.0,35,self)
	elif poise>=(210 if is_boss else 42):
		poise=0
		state="stagger"
		timer=2.1 if is_boss else 0.75
		if is_boss:
			game.toast("架勢崩解", "古龍失去平衡，趁現在進攻！")

func reset() -> void:
	death_elapsed=0
	if dead:
		return
	hp=max_hp
	phase=1
	state="idle"
	timer=0
	poise=0
	attack_index=0
	engaged=false
	global_position=home
	velocity=Vector3.ZERO

func revive() -> void:
	rewarded=false
	dead=false
	visual.rotation=Vector3.ZERO
	visual.scale=Vector3.ONE
	show()
	collision_layer=4
	collision_mask=1|2|4
	reset()

func ensure_visual() -> void:
	if visual_ready or game.net.dedicated:return
	var old=rig
	visual.remove_child(old)
	old.queue_free()
	rig=PublicCharacter.new()
	visual.add_child(rig)
	rig.configure(visual_asset)
	if kind=="elite":rig.scale=Vector3.ONE*1.3
	if kind=="guardian":rig.scale=Vector3.ONE*(1.6+float(boss_profile%3)*.25)
	Art.limit_visibility(rig,65 if is_boss else 42)
	visual_ready=true
