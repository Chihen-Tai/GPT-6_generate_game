extends SceneTree
var passed=0
var failed=0
func check(ok:bool, label:String) -> void:
	if ok:passed+=1;print("LEVEL PASS: ",label)
	else:failed+=1;push_error("LEVEL FAIL: "+label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var g=load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await process_frame
	g.test_mode=true;g.set_mode("play")
	for foe in g.enemies:foe.set_physics_process(false)
	var p:Hero=g.player
	p.set_physics_process(false)
	check(p.level==1 and p.experience==0,"New character begins at level one")
	p.upgrades=5
	check(p.level==1,"Weapon upgrade is independent of character level")
	check(p.gain_experience(119)==0 and p.experience==119,"Experience accumulates below threshold")
	p.hp=70;p.mana=50
	check(p.gain_experience(1)==1 and p.level==2 and p.experience==0,"Exact threshold levels up once")
	check(p.max_hp==148 and p.max_mana==103 and p.hp==78 and p.mana==53,"Growth preserves existing missing health and mana")
	check(p.gain_experience(Progression.required(2)+Progression.required(3)+17)==2 and p.level==4 and p.experience==17,"Large reward crosses multiple levels with remainder")
	p.gain_experience(-500)
	check(p.experience==17,"Negative experience is ignored")
	for job in 5:
		p.apply_profile({"job":job})
		check(p.max_hp==CharacterProfile.HEALTH[job]+3*Progression.HEALTH_GROWTH[job] and p.max_mana==CharacterProfile.MANA[job]+3*Progression.MANA_GROWTH[job],"Class growth: "+CharacterProfile.CLASSES[job])
	p.load_progress({"level":10,"experience":31})
	g.save_game("user://level-test.json")
	p.load_progress({})
	check(g.load_game("user://level-test.json") and p.level==10 and p.experience==31,"Level and XP survive save/load")
	var old=JSON.parse_string(FileAccess.get_file_as_string("user://level-test.json"))
	old.erase("level");old.erase("experience");old.version=3
	FileAccess.open("user://level-test.json",FileAccess.WRITE).store_string(JSON.stringify(old))
	check(g.load_game("user://level-test.json") and p.level==1 and p.experience==0,"Old saves start at level one without losing their other data")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://level-test.json"))
	p.load_progress({"level":{},"experience":NAN})
	check(p.level==1 and p.experience==0,"Malformed saved progression is sanitized")
	p.load_progress({"level":49,"experience":0})
	p.gain_experience(1000000)
	check(p.level==50 and p.experience==0 and Progression.required(50)==0,"Level cap stops growth and clears remainder")
	p.load_progress({"level":11});p.restore()
	var foe:Foe=g.enemies[0]
	foe.max_hp=1000;foe.hp=1000
	foe.take_damage(100,false,false,p)
	check(foe.hp==875,"Level damage multiplier applies exactly once")
	p.load_progress({});p.restore()
	foe.take_damage(10000)
	check(p.experience==60,"A real enemy defeat grants its XP reward")
	g.enemy_defeated(foe)
	check(p.experience==60,"Repeated defeat callbacks do not duplicate XP")
	foe.revive();foe.take_damage(10000)
	check(p.level==2 and p.experience==0,"A respawned enemy grants a fresh reward")
	p.level=8;p.experience=9;p.refresh_growth()
	g.net.test_session=true;g.net.port=24675
	check(g.net.host(true)==OK and p.level==1,"Guest realm starts independently of offline progression")
	p.gain_experience(120)
	var state=g.net._snapshot()
	check(state.actors[1].level==2 and state.actors[1].experience==0,"Authoritative snapshots include progression")
	var far=g.net._add_actor(2,"Far",false)
	far.position=Vector3(4000,.4,4000)
	var dead_player=g.net._add_actor(3,"Dead",false)
	dead_player.position=p.position;dead_player.dead=true
	foe.revive();foe.position=p.position+Vector3(0,0,2)
	foe.dead=true
	g.net.enemy_defeated(foe)
	check(p.experience==60 and far.experience==0 and dead_player.experience==0,"Co-op XP is shared only with nearby living players")
	g.net.leave()
	check(p.level==8 and p.experience==9,"Leaving a realm restores offline progression")
	p.network_driven=true
	check(p.gain_experience(5000)==0 and p.level==8,"Replica cannot grant itself experience")
	p.network_driven=false
	await process_frame
	print("LEVEL RESULT: %d passed, %d failed"%[passed,failed])
	quit(1 if failed else 0)
