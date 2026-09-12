extends SceneTree
var failures=0
var passed=0
func check(ok: bool, description: String) -> void:
	if ok:
		passed+=1
		print("PASS: "+description)
	else:
		failures+=1
		push_error("FAIL: "+description)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var g=load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await physics_frame
	g.test_mode=true
	g.set_mode("play")
	for foe in g.enemies:foe.set_physics_process(false)
	g.player.set_physics_process(false)
	check(g.npcs.size()>=28 and g.enemies.size()>=43,"Five-region NPC and enemy population")
	check(PublicAssets.used.size()>=85,"At least 85 distinct public models are instantiated")
	for region in AureliaWorld.REGIONS:
		check(g.world.region_at(region.center).name==region.name,"Map region lookup: "+region.name)
		var ray=PhysicsRayQueryParameters3D.create(region.center+Vector3.UP*15,region.center-Vector3.UP*5,1)
		var hit=g.world.get_world_3d().direct_space_state.intersect_ray(ray)
		check(not hit.is_empty(),"Collision ground exists: "+region.name)
	for npc in [g.npcs[1],g.npcs[2],g.npcs[8]]:
		var rig=npc.node.get_node("Rig")
		check(rig.clips.has(npc.motion),"Authored occupation motion: "+npc.type)
	var mount=g.horse
	check(mount is PublicCharacter and mount.clips.has("run"),"Mount uses the imported animated horse")
	check(mount.clips.run!=mount.clips.idle,"Horse running and idle use different source clips")
	var b=g.boss
	check(b.rig.clips.slash_a!=b.rig.clips.idle and b.rig.clips.heavy!=b.rig.clips.idle,"Dragon has separate authored attacks and flying idle")
	b.take_damage(b.max_hp*.35)
	check(b.phase==2,"Final Boss enters phase two below 66 percent")
	b.attack_index=5
	b._start_attack()
	check(b.attack.type=="breath" and b.attack.hits.size()==3,"Phase two unlocks three committed breath volleys")
	b.take_damage(b.max_hp*.36)
	check(b.phase==3,"Final Boss enters phase three below 30 percent")
	b.attack_index=6
	b._start_attack()
	check(b.attack.name=="天穹審判" and b.attack.hits.size()==2,"Phase three unlocks a delayed two-wave judgement")
	g.checkpoint=AureliaWorld.ARENA+Vector3(5,.3,65)
	g.save_game("user://expansion-test.json")
	check(g.load_game("user://expansion-test.json") and g.checkpoint.z<-200,"Expanded-region checkpoint survives save and load")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://expansion-test.json"))
	var state=g.net._snapshot()
	check(var_to_bytes(state).size()<262144,"Expanded enemy snapshot fits the protocol payload limit")
	print("EXPANSION RESULT: %d passed, %d failed" % [passed,failures])
	quit(0 if failures==0 else 1)
