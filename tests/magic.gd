extends RefCounted

var passed=0
var failures: Array[String]=[]
var game: Node3D
var target: Foe

func check(ok: bool, message: String) -> void:
	if ok:
		passed+=1
		print("PASS: "+message)
	else:
		failures.append(message)
		push_error("FAIL: "+message)

func frames(count: int) -> void:
	for i in count:await game.get_tree().physics_frame

func prepare(index: int) -> void:
	target=game.enemies[0]
	game.set_mode("play")
	game._clear_effects()
	game.player.restore()
	game.player.position=Vector3(0,0.4,-98)
	game.player.visual.rotation=Vector3.ZERO
	game.player.spell_page=index/4
	game.player.locked_target=target
	for e in game.enemies:
		e.set_physics_process(false)
		e.position=Vector3(80,0.3,65)
		e.max_hp=3000
		e.hp=3000
		e.dead=false
	target.position=Vector3(0,0.3,-107)
	target.slowed=0

func run(g: Node3D) -> void:
	game=g
	target=g.enemies[0]
	await frames(3)
	for index in 12:
		prepare(index)
		if index==2:target.position=Vector3(0,0.3,-101)
		if index==3:game.player.hp=70
		await frames(3)
		var before=game.player.mana
		check(game.player.cast_slot(index%4),"skill %02d %s can be cast" % [index,Spellcraft.SPELLS[index].name])
		check(is_equal_approx(before-game.player.mana,float(Spellcraft.SPELLS[index].cost)),"skill %02d charges its exact mana cost" % index)
		await frames(195 if index==6 else 140)
		if index==3:
			check(game.player.hp==125,"healing spell restores 55 health")
		elif index==10:
			game.player.invulnerable=0
			var hp=game.player.hp
			game.player.take_damage(40,Vector3.ZERO)
			check(game.player.hp==hp and game.player.ward_hp==50,"ward absorbs damage and consumes shield capacity")
			game.player.invulnerable=0
			game.player.take_damage(70,Vector3.ZERO)
			check(game.player.hp==hp-20 and game.player.ward_hp==0,"damage exceeding ward capacity reaches health")
		else:
			check(target.hp<3000,"skill %02d hits a real enemy collider or area" % index)
			if index==6:check(target.slowed>0 and target.hp<=2940,"ice field repeatedly damages and slows")
		if index in [7,8]:
			await frames(125)
			check(game.magic.jobs.is_empty() and game.magic.visuals.is_empty(),"projectile skill %02d releases all jobs and visuals after flight" % index)
	prepare(4)
	await frames(3)
	game.player.mana=0
	check(not game.player.cast_slot(0) and game.magic.jobs.is_empty(),"insufficient mana creates no pending damage")
	game.player.mana=100
	game.player.cast_slot(0)
	game.player.cast_time=0
	game.player.spell_page=2
	game.player.spell_page=1
	var mana=game.player.mana
	check(not game.player.cast_slot(0) and game.player.mana==mana,"switching pages cannot bypass cooldown or spend mana twice")
	game.set_mode("pause")
	var wait=game.magic.jobs[0].wait
	await frames(30)
	check(game.magic.jobs[0].wait==wait and target.hp==3000,"pausing freezes scheduled spell damage")
	game.set_mode("play")
	game._clear_effects()
	await frames(40)
	check(target.hp==3000 and game.magic.jobs.is_empty(),"clearing effects cancels delayed damage")
	prepare(4)
	var second=g.enemies[1]
	second.position=Vector3(3,0.3,-108)
	await frames(3)
	game.player.cast_slot(0)
	await frames(35)
	check(target.hp==2943 and second.hp>2943 and second.hp<3000,"chain lightning jumps once to a second target with damage falloff")
	prepare(9)
	await frames(3)
	var wall=Art.body_box(g,Vector3(0,2,-103),Vector3(6,4,0.7))
	await frames(3)
	game.player.cast_slot(1)
	await frames(95)
	check(target.hp==3000,"solid terrain blocks the piercing beam")
	wall.queue_free()
	prepare(11)
	await frames(3)
	game.player.cast_slot(3)
	game.player.invulnerable=0
	game.player.take_damage(1000,Vector3.ZERO)
	check(game.magic.jobs.is_empty() and game.magic.visuals.is_empty(),"death cancels ultimate impacts and releases visuals")
	game.respawn()
	check(game.player.ward_hp==0 and game.player.cooldown(11)==0,"respawn resets temporary spell state")
	prepare(5)
	await frames(3)
	# Lethal area damage can clear the currently executing magic job list.
	g.boss.position=Vector3(0,0.3,-107)
	target.position=Vector3(70,0.3,65)
	g.boss.hp=1
	g.player.locked_target=g.boss
	g.player.cast_slot(1)
	await frames(100)
	check(g.mode=="victory" and g.magic.jobs.is_empty(),"a lethal meteor safely cancels all pending spell jobs")
	print("MAGIC RESULT: %d passed, %d failed" % [passed,failures.size()])
	g.get_tree().quit(0 if failures.is_empty() else 1)
