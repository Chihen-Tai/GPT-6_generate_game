extends "res://tests/smoke.gd"

func run(g: Node3D) -> void:
	print("AURELIA character and combat motion integration suite")
	g.set_mode("play")
	for foe in g.enemies:foe.set_physics_process(false)
	var p=g.player
	var rig:AnimatedCharacter=p.rig
	p.set_physics_process(false)
	for clip in ["idle","run","sprint","roll","slash_a","slash_b","slash_c","heavy","sit","cast"]:
		check(rig.clips.has(clip),"Imported authored animation exists: "+clip)
	var hip=rig.skeleton.find_bone("pelvis")
	var thigh=rig.skeleton.find_bone("thigh_r")
	var spine=rig.skeleton.find_bone("spine_03")
	rig.pose("idle",0.2,0,0)
	var idle_hip=rig.skeleton.get_bone_pose_position(hip)
	var idle_leg=rig.skeleton.get_bone_pose_rotation(thigh)
	rig.pose("roll",0.50,0,0)
	check(rig.skeleton.get_bone_pose_position(hip).distance_to(idle_hip)>0.2,"Roll lowers the animated hips instead of flipping a rigid body")
	check(rig.skeleton.get_bone_pose_rotation(thigh).angle_to(idle_leg)>0.5,"Roll tucks articulated legs")
	var poses=[]
	for clip in ["slash_a","slash_b","slash_c"]:
		rig.pose(clip,0.5,0,0)
		poses.append(rig.skeleton.get_bone_pose_rotation(spine))
	check(poses[0].angle_to(poses[1])>0.15 and poses[1].angle_to(poses[2])>0.15,"Three sword attacks use different full-body poses")
	check(rig.socket("ArmR").get_parent() is BoneAttachment3D,"Sword socket follows the animated hand bone")
	check(g.boss.rig is AnimatedCharacter and g.boss.rig.source_asset=="monsters/Dragon","Final Boss uses the authored animated dragon")
	var npc_assets={}
	for npc in g.npcs:
		var model=npc.node.get_node_or_null("Rig")
		if model:npc_assets[model.source_asset]=true
	check(npc_assets.size()>=4,"NPC professions use at least four character variants")
	p.restore()
	p.position=Vector3(0,0.3,-35)
	p.visual.rotation.y=0
	p.set_physics_process(true)
	await frames(g,5)
	var target=g.enemies[0]
	target.position=p.position+Vector3(0,0,-2)
	target.max_hp=1000
	target.hp=1000
	p.combo_window=0
	p.begin_attack(false)
	await frames(g,6)
	check(target.hp==1000,"Sword anticipation does not deal early damage")
	await frames(g,10)
	check(target.hp==976,"Blade contact applies exactly one light hit")
	await frames(g,14)
	p.begin_attack(false)
	check(p.queued_attack==0,"A click during recovery buffers the next slash")
	await frames(g,12)
	check(p.combo==1 and p.attack_time>0,"Buffered slash transitions to the second combo animation")
	await frames(g,40)
	p.restore()
	target.position=Vector3(30,0.3,-35)
	await frames(g,2)
	var start=p.position
	action(p,"roll")
	await frames(g,22)
	check(p.rig.rotation.is_zero_approx(),"Dodge leaves the visual root upright while bones perform the roll")
	check(p.stamina<=76 and p.roll_time>0,"Dodge consumes stamina and keeps a recovery phase")
	await frames(g,10)
	check(p.invulnerable<=0 and p.roll_time>0,"Roll recovery is vulnerable")
	await frames(g,15)
	var distance=start.distance_to(p.position)
	check(distance>4.5 and distance<6.6,"Roll travel stays within the tuned five-to-six metre range")
	check(p.can_act(),"Player can act after getting back to their feet")
	p.restore()
	g.boss.position=Vector3(0,0.3,-108)
	for index in [0,1,2,3,4]:
		g.boss.attack_index=index
		g.boss._start_attack()
		g.boss.timer=g.boss.attack.windup*0.5
		g.boss._animate_skeleton(0.1,0)
		check(g.boss.rig.current_clip in ["slash_a","heavy","cast"],"Boss telegraphs pattern %d with skeletal anticipation" % index)
	p.restore()
	check(p.queued_attack==-1,"Respawn clears a buffered attack")
	print("MOTION RESULT: %d passed, %d failed" % [passed,failures.size()])
	g.get_tree().quit(0 if failures.is_empty() else 1)
