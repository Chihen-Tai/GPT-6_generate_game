extends "res://tests/smoke.gd"

func run(g: Node3D) -> void:
	g.test_mode=true
	g.set_mode("play")
	g.player.set_physics_process(false)
	for foe in g.enemies:foe.set_physics_process(false)
	var p:Hero=g.player
	check(CharacterProfile.clean({"gender":{},"job":"invalid","skills":[-1,99,{},2,2]}).job==0,"Malformed character input is sanitized")
	var shared=true
	for npc in g.npcs:
		for child in npc.node.get_children():
			if child is Label3D and child.font!=Art.label_font:shared=false
	check(shared,"NPC labels share one font resource")
	check(WorldAtlas.HALF_SIZE==1200,"World bounds span 2.4 kilometres on each axis")
	check(WorldAtlas.settlements.size()==72 and WorldAtlas.dungeons.size()==19,"72 additional settlements and 19 regional dungeons")
	var bosses:Array=[]
	var signatures={}
	for foe in g.enemies:
		if not foe.is_boss:continue
		bosses.append(foe)
		foe.ensure_visual()
		p.position=foe.home+Vector3(0,0,10)
		foe.combat_target=p
		foe.attack_index=0
		foe._start_attack()
		signatures[JSON.stringify(foe.attack)]=true
		check(foe.rig.clips.slash_a!=foe.rig.clips.idle,"Authored Boss attack: "+foe.title)
	check(bosses.size()==20 and signatures.size()>10,"20 bosses with differentiated attacks")
	for gender in 2:
		p.apply_profile({"gender":gender,"job":2,"skills":[11,8,4,3]})
		p.restore()
		check(p.max_mana==140 and p.skill_index(0)==11,"Gender %d preserves selected class and skill layout"%gender)
		for clip in ["idle","walk","run","sprint","roll","slash_a","slash_b","slash_c","heavy","cast","hurt","sit","death"]:
			check(p.rig.clips.has(clip),"Gender %d authored clip: %s"%[gender,clip])
			p.rig.pose(clip,.5,0,0)
			for bone in p.rig.skeleton.get_bone_count():
				if not p.rig.skeleton.get_bone_pose_position(bone).is_finite():check(false,"Non-finite bone transform")
		p.attack_time=0;p.stagger=0;p.mounted=false
		p.cast_time=0;p.cast_time=.6
		p.anim_time=27.3
		p._animate(.016,0)
		check(p.rig.current_clip=="cast" and p.rig.animator.current_animation_position<.05,"Cast begins at the authored anticipation")
		p.cast_time=0
		p._animate(.2,1.5)
		check(p.rig.current_clip=="walk","Slow movement uses walk instead of jog")
		p.mounted=true
		p._animate(.2,10)
		check(p.rig.current_clip=="sit" and is_equal_approx(p.rig.position.y,p.saddle_height()),"Mounted rider uses saddle pose")
		p.attack_length=.62;p.attack_time=.31
		p._animate(.2,0)
		check(p.rig.skeleton.get_bone_pose_position(p.rig.hip_index).is_equal_approx(p.rig.seated_hip),"Mounted sword attacks preserve seated hips")
		p.attack_time=0
		var sword=p.sword_trail.blade
		check(sword.has_meta("trail_tip") and sword.get_meta("trail_tip").y>1,"Sword trail follows the authored blade axis")
		p.mounted=false
	p.apply_profile({})
	p.restore()
	for center in [Vector3(-1100,0,-1100),Vector3(1100,0,1100),Vector3(0,0,0)]:
		p.position=center+Vector3(0,.4,0)
		g.world.stream.update_centers([center],true)
		await frames(g,2)
		var query=PhysicsRayQueryParameters3D.create(center+Vector3(10,20,10),center+Vector3(10,-2,10),1)
		check(not g.world.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"Streamed ground collision at "+str(center))
		check(g.world.stream.chunks.size()<=9,"Single-player chunk count stays bounded")
	p.position=Vector3(100,.4,100)
	check(not g.travel_to(1),"Travel rejected away from a shrine")
	p.position=Vector3(5.2,.4,31)
	for foe in g.enemies:foe.engaged=false
	check(g.travel_to(1),"Shrine travel reaches a remote settlement")
	check(p.position.distance_to(WorldAtlas.settlements[0].center)<25,"Travel uses the selected destination")
	var guardian:Foe=bosses[1]
	guardian.take_damage(guardian.max_hp+1)
	check(guardian.boss_profile in g.cleared_guardians and not g.boss_defeated,"Regional Boss victory records progress without ending the game")
	p.apply_profile({"gender":1,"job":3,"skills":[4,5,6,7]})
	g.save_game("user://continental-test.json")
	p.apply_profile({})
	check(g.load_game("user://continental-test.json") and p.profile.gender==1 and p.profile.job==3 and p.skill_index(0)==4,"Character and distant checkpoint survive save/reload")
	check(not g.cleared_guardians.is_empty(),"Regional Boss completion survives save/reload")
	var old_save=JSON.parse_string(FileAccess.get_file_as_string("user://continental-test.json"))
	old_save.erase("world_layout")
	old_save.checkpoint=[-4000,.4,-3982]
	FileAccess.open("user://continental-test.json",FileAccess.WRITE).store_string(JSON.stringify(old_save))
	check(g.load_game("user://continental-test.json") and p.position.distance_to(WorldAtlas.settlements[0].center+Vector3(0,.4,18))<.01,"Old remote save loads at the matching compact shrine")
	check(p.profile.gender==1 and not g.cleared_guardians.is_empty(),"Map migration preserves character and Boss progress")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://continental-test.json"))
	check(var_to_bytes(g.net._snapshot()).size()<262144,"Full continental snapshot fits the network protocol")
	print("CONTINENTAL RESULT: %d passed, %d failed"%[passed,failures.size()])
	g.get_tree().quit(0 if failures.is_empty() else 1)
