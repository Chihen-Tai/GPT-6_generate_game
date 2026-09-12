class_name Spellcraft
extends Node3D

const PAGES = ["曦光劍術", "元素轟擊", "星界祕法"]
const SPELLS = [
	{"id":"bolt","name":"星火","cost":13,"cd":0.5,"cast":0.48,"color":"ffbc6b","desc":"追向目標的星火彈，消耗低、出手快。"},
	{"id":"frost","name":"霜矢","cost":25,"cd":0.7,"cast":0.48,"color":"8ee9ff","desc":"冰晶飛矢，命中後減速四秒。"},
	{"id":"sun","name":"日輪斬","cost":28,"cd":9.0,"cast":0.7,"color":"ffe095","desc":"消耗 20 體力，迴旋劍光打擊周圍並破壞架勢。"},
	{"id":"heal","name":"癒光","cost":35,"cd":12.0,"cast":0.65,"color":"9affcf","desc":"恢復 55 生命，升起療癒光環。"},
	{"id":"lightning","name":"天雷連鎖","cost":30,"cd":7.0,"cast":0.55,"color":"c9a5ff","desc":"雷擊最多串連四名敵人，每次跳躍傷害遞減。"},
	{"id":"meteor","name":"熾星墜落","cost":48,"cd":14.0,"cast":1.0,"color":"ff9869","desc":"標記地面後降下熾星，重創五公尺內敵人。"},
	{"id":"blizzard","name":"霜華領域","cost":32,"cd":12.0,"cast":0.6,"color":"7be6ff","desc":"留下三秒冰霜領域，持續傷害並減速。"},
	{"id":"wind","name":"蒼嵐三刃","cost":22,"cd":4.0,"cast":0.45,"color":"92ffce","desc":"扇形射出三道旋風刃，適合迎擊成群敵人。"},
	{"id":"swords","name":"星穹劍陣","cost":42,"cd":16.0,"cast":0.7,"color":"b6b0ff","desc":"召喚六柄浮游光劍，依序追蹤射向敵人。"},
	{"id":"beam","name":"破曉光槍","cost":36,"cd":10.0,"cast":1.25,"color":"ffe8a7","desc":"短暫蓄力後三次貫穿直線目標；地形會擋住光束。"},
	{"id":"ward","name":"星紗護壁","cost":30,"cd":18.0,"cast":0.45,"color":"84ddff","desc":"八秒內吸收最多 90 傷害，護盾不阻擋移動。"},
	{"id":"comet","name":"終式・天星","cost":75,"cd":32.0,"cast":1.25,"color":"ddb7ff","desc":"三道天星接連轟擊大範圍，施法時需留意敵人追刀。"}
]
var game: Node3D
var caster: Hero
var visuals: Array[Dictionary] = []
var jobs: Array[Dictionary] = []
var generation = 0
var shake = 0.0
var materials: Dictionary = {}

func setup(owner_game: Node3D, owner_caster: Hero = null) -> void:
	game=owner_game
	caster=owner_caster if owner_caster else game.player

func luminous(color: Color, alpha: float = 1.0) -> StandardMaterial3D:
	var key=str(color)+str(alpha)
	if not materials.has(key):
		var m=StandardMaterial3D.new()
		m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color=Color(color,alpha*0.86)
		m.emission_enabled=true
		m.emission=color
		m.emission_energy_multiplier=0.65
		m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode=BaseMaterial3D.BLEND_MODE_MIX
		m.cull_mode=BaseMaterial3D.CULL_DISABLED
		m.no_depth_test=false
		m.vertex_color_use_as_albedo=true
		materials[key]=m
	return materials[key]

func mesh_at(parent: Node3D, mesh: Mesh, color: Color) -> MeshInstance3D:
	var n=MeshInstance3D.new()
	n.mesh=mesh
	n.material_override=luminous(color)
	n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(n)
	return n

func effect(pos: Vector3, life: float, kind: String = "still") -> Node3D:
	# Bounds remain fixed during sustained combat; expired nodes are freed below.
	if visuals.size()>=240:
		var oldest=visuals.pop_front()
		if is_instance_valid(oldest.node):oldest.node.queue_free()
	var n=Node3D.new()
	add_child(n)
	n.position=pos
	visuals.append({"node":n,"life":life,"age":0.0,"kind":kind})
	return n

func arc(parent: Node3D, radius: float, width: float, color: Color, start: float = 0.0, sweep: float = TAU) -> Node3D:
	var st=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 64:
		var a=start+sweep*i/64.0
		var b=start+sweep*(i+1)/64.0
		for p in [Vector3(cos(a)*radius,0,sin(a)*radius),Vector3(cos(a)*(radius-width),0,sin(a)*(radius-width)),Vector3(cos(b)*radius,0,sin(b)*radius),Vector3(cos(b)*radius,0,sin(b)*radius),Vector3(cos(a)*(radius-width),0,sin(a)*(radius-width)),Vector3(cos(b)*(radius-width),0,sin(b)*(radius-width))]:
			st.add_vertex(p)
	st.generate_normals()
	return mesh_at(parent,st.commit(),color)

func line(parent: Node3D, a: Vector3, b: Vector3, width: float, color: Color) -> Node3D:
	var mesh=CylinderMesh.new()
	mesh.top_radius=width*0.35
	mesh.bottom_radius=width
	mesh.height=maxf(0.001,a.distance_to(b))
	mesh.radial_segments=7
	var n=mesh_at(parent,mesh,color)
	n.position=(a+b)*0.5
	if a.distance_to(b)>0.001:n.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
	return n

func public_sprite(parent: Node3D, texture: String, size: float, color: Color, billboard: bool = true) -> MeshInstance3D:
	var quad=QuadMesh.new()
	quad.size=Vector2.ONE*size
	var sprite=mesh_at(parent,quad,color)
	var mat=luminous(color).duplicate()
	mat.albedo_texture=load("res://assets/vendor/particles/PNG (Transparent)/"+texture+".png")
	mat.emission_texture=mat.albedo_texture
	mat.emission_energy_multiplier=1.2
	mat.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED if billboard else BaseMaterial3D.BILLBOARD_DISABLED
	sprite.material_override=mat
	return sprite

func orb(parent: Node3D, radius: float, color: Color) -> Node3D:
	return public_sprite(parent,"light_01",radius*3,color)

func ribbon(parent: Node3D, end: Vector3, width: float, color: Color) -> void:
	var along=end.normalized()
	var side=along.cross(Vector3.FORWARD).normalized()
	if side.length()<0.1:side=Vector3.RIGHT
	for layer in 2:
		var st=SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var across=side if layer==0 else side.cross(along).normalized()
		for i in 20:
			var t=i/20.0
			var next=(i+1)/20.0
			for uv in [Vector2(0,t),Vector2(1,t),Vector2(1,next),Vector2(0,t),Vector2(1,next),Vector2(0,next)]:
				st.set_uv(uv)
				var curve=across*sin(uv.y*PI)*width*0.35
				st.add_vertex(end*uv.y+curve+across*(uv.x*2-1)*width*(1-uv.y*0.65))
		st.generate_normals()
		var n=mesh_at(parent,st.commit(),color)
		var m=ShaderMaterial.new()
		m.shader=load("res://shaders/energy_ribbon.gdshader")
		m.set_shader_parameter("tint",color)
		n.material_override=m
		n.set_meta("animated_ribbon",true)

func circle(pos: Vector3, radius: float, color: Color, life: float) -> Node3D:
	var n=effect(pos+Vector3.UP*0.09,life,"circle")
	var sigil=public_sprite(n,"circle_05",radius*2,color,false)
	sigil.rotation.x=-PI/2
	var star=public_sprite(n,"star_09",radius*1.35,color,false)
	star.rotation.x=-PI/2
	return n

func sparks(pos: Vector3, color: Color, count: int = 40, speed: float = 4.0) -> void:
	if game.test_mode:return
	var n=effect(pos,1.1)
	var p=GPUParticles3D.new()
	n.add_child(p)
	p.amount=count
	p.lifetime=0.85
	p.one_shot=true
	p.explosiveness=0.95
	p.visibility_aabb=AABB(Vector3.ONE*-12,Vector3.ONE*24)
	var m=ParticleProcessMaterial.new()
	m.direction=Vector3.UP
	m.spread=140
	m.initial_velocity_min=speed*0.3
	m.initial_velocity_max=speed
	m.gravity=Vector3(0,-2.5,0)
	m.scale_min=0.035
	m.scale_max=0.10
	var gradient=Gradient.new()
	gradient.colors=PackedColorArray([Color.WHITE,color,Color(color,0)])
	gradient.offsets=PackedFloat32Array([0,0.2,1])
	var ramp=GradientTexture1D.new()
	ramp.gradient=gradient
	m.color_ramp=ramp
	p.process_material=m
	var particle=QuadMesh.new()
	particle.size=Vector2(3,3)
	var sprite=StandardMaterial3D.new()
	sprite.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	sprite.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	sprite.billboard_mode=BaseMaterial3D.BILLBOARD_PARTICLES
	sprite.vertex_color_use_as_albedo=true
	sprite.albedo_texture=load("res://assets/vendor/particles/PNG (Transparent)/"+("flame_01" if color.r>color.b*1.3 else "spark_01" if color.b>color.r else "star_04")+".png")
	sprite.emission_texture=sprite.albedo_texture
	sprite.emission_enabled=true
	sprite.emission=color
	sprite.emission_energy_multiplier=2.0
	particle.material=sprite
	p.draw_pass_1=particle
	p.emitting=true

func impact(pos: Vector3, color: Color, radius: float, heavy: bool = false) -> void:
	var n=effect(pos+Vector3.UP*0.12,0.55,"expand")
	arc(n,radius,0.10 if heavy else 0.05,color)
	var tilt=arc(n,radius*0.65,0.055,color.lightened(0.3))
	tilt.rotation.x=0.45
	sparks(pos+Vector3.UP*0.5,color,70 if heavy else 25,7 if heavy else 3)
	if heavy:
		shake=maxf(shake,0.24)
		var column=effect(pos,0.35,"collapse")
		ribbon(column,Vector3.UP*radius*1.8,radius*0.28,color)
		var rays=effect(pos+Vector3.UP*0.18,0.6,"expand")
		for i in 18:
			var d=Vector3(cos(i*TAU/18),0.06,sin(i*TAU/18))
			line(rays,d*radius*0.3,d*radius*(1.05+float(i%3)*0.18),0.045,color)

func cast_flourish(pos: Vector3, color: Color) -> void:
	circle(pos,1.4,color,0.65)
	sparks(pos+Vector3.UP*1.2,color,22,2)

func trail(pos: Vector3, dir: Vector3, color: Color) -> void:
	var n=effect(pos,0.22,"shrink")
	line(n,Vector3.ZERO,-dir*0.9,0.035,color)

func slash_fx(pos: Vector3, angle: float, big: bool) -> void:
	var n=effect(pos,0.32,"slash")
	n.rotation.y=angle
	arc(n,4.5 if big else 2.25,0.23 if big else 0.13,Color("ffdb9b"),-2.85,2.6)
	var inner=arc(n,4.15 if big else 2.05,0.04,Color("fff4d3"),-2.7,2.35)
	inner.position.y=0.055
	sparks(pos,Color("ffe0a0"),12,2)

func aim() -> Dictionary:
	var p=caster
	var origin=p.global_position+Vector3.UP*(2.4 if p.mounted else 1.35)
	var direction=-p.visual.global_basis.z
	var enemy=p.locked_target if is_instance_valid(p.locked_target) and not p.locked_target.dead else game.nearest_enemy(p.global_position,26)
	if is_instance_valid(enemy) and p.global_position.distance_to(enemy.global_position)<=28 and game.can_see(origin,enemy.global_position+Vector3.UP,p):
		direction=(enemy.global_position+Vector3.UP*(2.1 if enemy.is_boss else 1.2)-origin).normalized()
	else:enemy=null
	var point=enemy.global_position if enemy else p.global_position+direction*16
	var hit=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,origin+direction*28,1,[p.get_rid()]))
	var end=origin+direction*28
	if not hit.is_empty():
		end=hit.position-direction*0.12
		if not enemy:point=end
	point.y=game.world.ground_height(point.x,point.z)+0.15
	p.face(direction,1.0)
	return {"origin":origin,"dir":direction,"point":point,"end":end,"target":enemy}

func cast(index: int) -> void:
	var s=SPELLS[index]
	var color=Color(s.color)
	var a=aim()
	var p=caster
	cast_flourish(p.global_position,color)
	match s.id:
		"lightning":
			circle(a.point,2.0,color,0.5)
			jobs.append({"type":"lightning","wait":0.32,"pos":a.point,"damage":57+p.upgrades*5})
		"meteor","comet":
			var ultimate=s.id=="comet"
			if ultimate:circle(a.point,7.2,color,2.0)
			for i in (3 if ultimate else 1):
				var pos:Vector3=a.point+Vector3(cos(i*TAU/3),0,sin(i*TAU/3))*(1.5 if ultimate else 0.0)
				var delay=1.05+i*0.24
				circle(pos,2.3 if ultimate else 5.0,color,delay+0.5)
				var falling=effect(pos,delay,"meteor")
				falling.set_meta("delay",delay)
				falling.set_meta("impact",pos)
				orb(falling,0.7 if ultimate else 0.9,color)
				ribbon(falling,Vector3(3,9,1),1.1,color)
				for k in 3:
					var ring=arc(falling,1.15+k*0.3,0.055,color)
					ring.rotation=Vector3(k*0.7,0,0.5)
				jobs.append({"type":"blast","wait":delay,"pos":pos,"radius":6.2 if ultimate else 5.0,"damage":95+p.upgrades*7 if ultimate else 145+p.upgrades*12,"color":color})
		"blizzard":
			circle(a.point,4.5,color,3.2)
			var n=effect(a.point,3.2,"ice")
			for i in 12:
				var t=i*TAU/12
				var v=Vector3(cos(t),0,sin(t))*3.4
				line(n,v,v+Vector3(cos(t)*0.3,1.2+float(i%3)*0.6,sin(t)*0.3),0.20,color)
				line(n,v+Vector3.UP*0.04,v+Vector3(cos(t)*0.3,1.1+float(i%3)*0.6,sin(t)*0.3),0.055,Color("ecfcff"))
			for i in 6:jobs.append({"type":"ice","wait":0.3+i*0.5,"pos":a.point,"damage":11+p.upgrades*2})
		"wind":
			for i in range(-1,2):projectile(a.origin,a.dir.rotated(Vector3.UP,i*0.20),31+p.upgrades*4,29,color,null,true)
		"swords":
			var orbit=effect(p.global_position+Vector3.UP*2.1,1.3,"circle_orbit")
			arc(orbit,1.8,0.04,color)
			arc(orbit,1.95,0.02,color)
			for i in 6:
				var offset=Vector3(cos(i*TAU/6)*1.7,2.0+sin(i*TAU/6)*0.6,0.7)
				var n=effect(p.global_position+offset,0.5+i*0.13,"float")
				light_sword(n,color)
				jobs.append({"type":"sword","wait":0.5+i*0.13,"pos":p.global_position+offset,"target":a.target,"dir":a.dir,"damage":26+p.upgrades*3})
		"beam":
			var n=circle(a.origin+a.dir*1.0,1.1,color,1.2)
			n.quaternion=Quaternion(Vector3.UP,a.dir)
			for i in 3:jobs.append({"type":"beam","wait":0.6+i*0.22,"origin":a.origin,"end":a.end,"damage":35+p.upgrades*4})
		"ward":
			p.ward_time=8
			p.ward_hp=90
			var n=effect(p.global_position+Vector3.UP*1.1,8,"ward")
			for i in 3:
				var ring=arc(n,1.2,0.035,color)
				ring.rotation=Vector3(PI/2,i*PI/3,0)
			circle(p.global_position,1.5,color,0.8)
	game.sound("arcane_"+s.id)

func light_sword(parent: Node3D, color: Color) -> void:
	var sword=Art.sword(parent)
	_glow_authored(sword,color)

func _glow_authored(node: Node, color: Color) -> void:
	if node is MeshInstance3D:node.material_override=luminous(color)
	for child in node.get_children():_glow_authored(child,color)

func projectile(pos: Vector3, direction: Vector3, damage: float, speed: float, color: Color, target: Node3D = null, wind: bool = false) -> void:
	var n=effect(pos,3.0,"projectile")
	if wind:
		arc(n,0.65,0.16,color,-2.4,4.8)
	else:light_sword(n,color)
	n.look_at(pos+direction,Vector3.UP)
	jobs.append({"type":"projectile","wait":0.0,"node":n,"dir":direction,"target":target,"damage":damage,"speed":speed,"life":3.0,"trail":0.0,"color":color})

func area_damage(pos: Vector3, radius: float, damage: float, ice: bool = false) -> void:
	var revision=generation
	for e in game.enemies:
		if e.dead or absf(e.global_position.y-pos.y)>5:continue
		var d=e.global_position-pos
		d.y=0
		if d.length()<=radius and game.can_see(pos+Vector3.UP,e.global_position+Vector3.UP,caster):
			e.take_damage(damage,ice,true,caster)
		if revision!=generation:return

func lightning(pos: Vector3, damage: float) -> void:
	var used=[]
	var start=pos+Vector3.UP*11
	var revision=generation
	for hop in 4:
		var closest:Foe=null
		var distance=3.5 if hop==0 else 7.0
		for e in game.enemies:
			if e.dead or e in used:continue
			var d=e.global_position.distance_to(pos)
			if d<distance and game.can_see(pos+Vector3.UP,e.global_position+Vector3.UP,caster):
				closest=e
				distance=d
		if not closest:
			if hop==0:bolt_line(start,pos+Vector3.UP,Color("c9a5ff"))
			break
		var target=closest.global_position+Vector3.UP*1.1
		bolt_line(start,target,Color("c9a5ff"))
		impact(target,Color("c9a5ff"),1.1)
		used.append(closest)
		closest.take_damage(damage*pow(0.8,hop),false,true,caster)
		if revision!=generation:return
		pos=closest.global_position
		start=target

func bolt_line(start: Vector3, end: Vector3, color: Color) -> void:
	var n=effect(start,0.4,"shrink")
	var last=Vector3.ZERO
	for i in range(1,10):
		var point=(end-start)*i/9.0
		if i<9:point+=Vector3(sin(i*17.2),sin(i*5.7),cos(i*8.1))*0.32
		line(n,last,point,0.07,color)
		line(n,last,point,0.024,Color.WHITE)
		last=point

func advance(job: Dictionary, delta: float) -> bool:
	job.wait-=delta
	if job.wait>0:return true
	match job.type:
		"blast":
			impact(job.pos,job.color,job.radius,true)
			area_damage(job.pos,job.radius,job.damage)
		"ice":
			sparks(job.pos+Vector3.UP,Color("8beaff"),25,4)
			area_damage(job.pos,4.5,job.damage,true)
		"lightning":lightning(job.pos,job.damage)
		"sword":projectile(job.pos,job.dir,job.damage,23,Color("b6b0ff"),job.target)
		"beam":
			var n=effect(job.origin,0.32,"shrink")
			line(n,Vector3.ZERO,job.end-job.origin,0.23,Color("ffd483"))
			line(n,Vector3.ZERO,job.end-job.origin,0.075,Color.WHITE)
			ribbon(n,job.end-job.origin,0.5,Color("ffe19b"))
			shake=maxf(shake,0.09)
			var revision=generation
			for e in game.enemies:
				if e.dead:continue
				var point=e.global_position+Vector3.UP*(2.1 if e.is_boss else 1.2)
				var near=Geometry3D.get_closest_point_to_segment(point,job.origin,job.end)
				if near.distance_to(point)<1.0 and game.can_see(job.origin,point,caster):
					e.take_damage(job.damage,false,true,caster)
				if revision!=generation:return false
		"projectile":
			if not is_instance_valid(job.node) or job.node.is_queued_for_deletion():return false
			var n:Node3D=job.node
			job.life-=delta
			if job.life<=0:
				n.queue_free()
				return false
			if is_instance_valid(job.target) and not job.target.dead:
				var direction=(job.target.global_position+Vector3.UP*(2.1 if job.target.is_boss else 1.2)-n.global_position).normalized()
				job.dir=job.dir.lerp(direction,minf(1,delta*9)).normalized()
			var end=n.global_position+job.dir*job.speed*delta
			var hit=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(n.global_position,end,1|4,[caster.get_rid()]))
			if not hit.is_empty():
				impact(hit.position,job.color,0.8)
				n.queue_free()
				if hit.collider is Foe:hit.collider.take_damage(job.damage,false,false,caster)
				return false
			n.position=end
			n.look_at(end+job.dir,Vector3.UP)
			job.trail-=delta
			if job.trail<=0:
				trail(end,job.dir,job.color)
				job.trail=0.06
			return true
	return false

func _physics_process(delta: float) -> void:
	if not is_instance_valid(game) or not game.world_running():return
	var revision=generation
	var active=jobs
	jobs=[]
	for job in active:
		var keep=advance(job,delta)
		if revision!=generation:break
		if keep:jobs.append(job)

func _process(delta: float) -> void:
	if not is_instance_valid(game):return
	if not game.world_running():
		caster.camera.h_offset=0
		caster.camera.v_offset=0
		for fx in visuals:
			if is_instance_valid(fx.node):
				for c in fx.node.get_children():
					if c is GPUParticles3D:c.speed_scale=0
		return
	shake=maxf(0,shake-delta)
	caster.camera.h_offset=sin(Time.get_ticks_msec()*0.061)*shake*0.20
	caster.camera.v_offset=cos(Time.get_ticks_msec()*0.079)*shake*0.15
	for i in range(visuals.size()-1,-1,-1):
		var fx=visuals[i]
		if not is_instance_valid(fx.node) or fx.node.is_queued_for_deletion():
			visuals.remove_at(i)
			continue
		var n:Node3D=fx.node
		fx.age+=delta
		var t=clampf(fx.age/fx.life,0,1)
		match fx.kind:
			"circle":
				n.rotation.y+=delta*0.4
				for child in n.get_children():
					if child is MeshInstance3D and child.material_override is StandardMaterial3D:
						child.material_override.albedo_color.a=minf(1,(1-t)*4)*minf(1,t*10)
			"expand":n.scale=Vector3.ONE*(0.3+t*1.0)
			"shrink":n.scale=Vector3.ONE*maxf(0.01,1-t*0.8)
			"collapse":n.scale=Vector3(1-t,1+t,1-t).max(Vector3.ONE*0.01)
			"slash":
				n.rotation.y+=delta*5
				n.scale=Vector3.ONE*(1+t*0.25)
			"meteor":n.position=n.get_meta("impact")+Vector3(3,15,1)*pow(1-t,1.4)
			"ice":n.scale.y=minf(1,t*9)*minf(1,(1-t)*5)
			"float":n.position.y+=delta*0.3
			"circle_orbit":n.rotation.y+=delta*2
			"ward":
				n.position=caster.global_position+Vector3.UP*(2.1 if caster.mounted else 1.1)
				n.rotation.y+=delta
				if caster.ward_hp<=0 or caster.ward_time<=0:fx.age=fx.life
		for c in n.get_children():
			if c.has_meta("animated_ribbon"):c.material_override.set_shader_parameter("phase",fx.age)
			if c is GeometryInstance3D:c.transparency=clampf((t-0.65)/0.35,0,1) if fx.kind!="projectile" else 0
			if c is GPUParticles3D:c.speed_scale=1
		if fx.age>=fx.life:
			n.queue_free()
			visuals.remove_at(i)

func clear() -> void:
	generation+=1
	jobs.clear()
	for fx in visuals:
		if is_instance_valid(fx.node):fx.node.queue_free()
	visuals.clear()
	shake=0
