extends Node3D

var net: RealmSession
var world: AureliaWorld
var player: Hero
var magic: Spellcraft
var hud: AureliaHUD
var horse: Node3D
var boss: Foe
var enemies: Array[Foe] = []
var npcs: Array[Dictionary] = []
var interactables: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var effects_running = false
var effects_clear_requested = false
var mode = "menu"
var guide_return = "menu"
var zone_name = "晨鐘村"
var interact_hint = ""
var current_interaction: Dictionary = {}
var speaker = ""
var dialogue_text = ""
var dialogue_options: Array[Dictionary] = []
var toast_title = ""
var toast_body = ""
var toast_time = 0.0
var damage_flash = 0.0
var checkpoint = Vector3(4,0.4,30)
var quest_active = false
var quest_rewarded = false
var cleared_guardians:Array[int]=[]
var boss_defeated = false
var character_return="play"
var stream_clock=0.0
var kills = 0
var has_save = false
var sounds: Dictionary = {}
var music: AudioStreamPlayer
var menu_camera: Camera3D
var clock_time = 0.0
var test_mode = false
const SAVE_PATH = "user://aurelia_save.json"

func _ready() -> void:
	net=RealmSession.new()
	net.name="Realm"
	add_child(net)
	net.game=self
	net.dedicated="--server" in OS.get_cmdline_user_args()
	test_mode="--server" in OS.get_cmdline_user_args() or "--net-test" in OS.get_cmdline_user_args() or "--smoke-test" in OS.get_cmdline_user_args() or "--magic-test" in OS.get_cmdline_user_args() or "--motion-test" in OS.get_cmdline_user_args() or "--motion-capture" in OS.get_cmdline_user_args()
	_inputs()
	world=AureliaWorld.new()
	add_child(world)
	world.build()
	player=Hero.new()
	player.name="Traveler"
	add_child(player)
	player.setup(self)
	player.position=checkpoint
	magic=Spellcraft.new()
	add_child(magic)
	magic.setup(self)
	player.spellcraft=magic
	horse=Art.horse(self)
	horse.position=Vector3(23,0,36)
	horse.rotation.y=-0.4
	_spawn_enemies()
	_spawn_people()
	_spawn_gathering()
	_spawn_region_people()
	_spawn_continental_people()
	var canvas=CanvasLayer.new()
	add_child(canvas)
	hud=AureliaHUD.new()
	canvas.add_child(hud)
	hud.setup(self)
	menu_camera=Camera3D.new()
	menu_camera.fov=58
	menu_camera.far=400
	add_child(menu_camera)
	menu_camera.position=Vector3(31,16,47)
	menu_camera.look_at(Vector3(-2,3,-11))
	menu_camera.current=true
	has_save=FileAccess.file_exists(SAVE_PATH)
	_audio()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	net.start_from_arguments()
	if "--smoke-test" in OS.get_cmdline_user_args():
		call_deferred("_run_smoke")
	if "--motion-test" in OS.get_cmdline_user_args():
		call_deferred("_run_motion_tests")
	if "--motion-capture" in OS.get_cmdline_user_args():
		call_deferred("_capture_motion")
	if "--magic-test" in OS.get_cmdline_user_args():
		call_deferred("_run_magic_tests")
	if "--magic-capture" in OS.get_cmdline_user_args():
		call_deferred("_capture_magic")
	if "--capture" in OS.get_cmdline_user_args():
		call_deferred("_capture")

func _inputs() -> void:
	var keys={"forward":KEY_W,"back":KEY_S,"left":KEY_A,"right":KEY_D,"sprint":KEY_SHIFT,"roll":KEY_SPACE,"lock_on":KEY_Q,"mount":KEY_H,"interact":KEY_E,"bolt":KEY_1,"frost":KEY_2,"skill":KEY_3,"heal":KEY_4,"flask":KEY_R,"map":KEY_M,"journal":KEY_J}
	keys["spell_page"]=KEY_TAB
	keys["spellbook"]=KEY_K
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var e=InputEventKey.new()
		e.physical_keycode=keys[action]
		InputMap.action_add_event(action,e)
	for pair in [["attack",MOUSE_BUTTON_LEFT],["heavy",MOUSE_BUTTON_RIGHT]]:
		InputMap.add_action(pair[0])
		var e=InputEventMouseButton.new()
		e.button_index=pair[1]
		InputMap.action_add_event(pair[0],e)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if mode=="play":
			set_mode("pause")
		elif mode in ["character","credits"]:
			set_mode("menu")
		elif mode=="guide":
			set_mode(guide_return)
		elif mode in ["pause","map","journal","dialogue","spellbook"]:
			set_mode("play")
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("map") and mode in ["play","map"]:
		set_mode("play" if mode=="map" else "map")
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("journal") and mode in ["play","journal"]:
		set_mode("play" if mode=="journal" else "journal")
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("spellbook") and mode in ["play","spellbook"]:
		set_mode("play" if mode=="spellbook" else "spellbook")
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("interact") and mode=="play" and not player.dead:
		interact()
		get_viewport().set_input_as_handled()

func set_mode(next: String) -> void:
	mode=next
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED if mode=="play" and not test_mode else Input.MOUSE_MODE_VISIBLE
	if menu_camera:
		menu_camera.current=mode=="menu"
		player.camera.current=mode!="menu"
	if mode!="play":
		player.velocity=Vector3.ZERO

func start_game() -> void:
	character_return="play"
	set_mode("character")
	toast_time=0

func continue_game() -> void:
	if not load_game():
		toast("存檔無法讀取", "將開始新的旅程。")
	set_mode("play")

func return_menu() -> void:
	if net.online or net.connecting:
		net.leave()
		return
	save_game()
	set_mode("menu")

func quit_game() -> void:
	if net.online:net.save_world()
	save_game()
	get_tree().quit()

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST and is_instance_valid(player):
		save_game()

func _process(delta: float) -> void:
	clock_time+=delta
	if mode=="menu":
		menu_camera.position=Vector3(31+sin(clock_time*0.05)*2,16,47)
		menu_camera.look_at(Vector3(-2,3,-11))
	if not world_running():
		return
	stream_clock-=delta
	if stream_clock<=0:
		stream_clock=.25
		var points:Array=[player.position]
		if net.online and net.authoritative():
			points=[]
			for actor in net.avatars.values():points.append(actor.position)
		world.stream.update_centers(points)
	toast_time=maxf(0,toast_time-delta)
	damage_flash=maxf(0,damage_flash-delta)
	_zone()
	_nearby()
	_effects(delta)
	for npc in npcs:
		var distance=player.position.distance_to(npc.node.position)
		var model=npc.node.get_node_or_null("Rig")
		if npc.get("streamed",false):
			if distance>100:
				if model:npc.node.remove_child(model);model.queue_free()
				continue
			if model==null:
				model=PublicCharacter.new()
				npc.node.add_child(model)
				model.configure("character-pack-adventures/"+npc.asset)
		if distance>80:continue
		if model is AnimatedCharacter:
			model.cycle("talk" if player.global_position.distance_to(npc.node.global_position)<4 else npc.get("motion","relax"),clock_time+npc.id*0.37,delta,0.75 if npc.type=="smith" else 1.0)
		else:
			Art.socket(model,"Head").rotation.y=sin(clock_time*0.7+npc.id)*0.15
			model.get_node("ArmL").rotation.x=sin(clock_time*1.1+npc.id)*0.06
		if player.global_position.distance_to(npc.node.global_position)<4:
			var d=player.global_position-npc.node.global_position
			npc.node.rotation.y=lerp_angle(npc.node.rotation.y,atan2(-d.x,-d.z),delta*2)

func _zone() -> void:
	var next:String=world.region_at(player.global_position).name
	if next!=zone_name:
		zone_name=next
		toast(next,"前方有強大敵人，準備好補給再深入。" if "危險" in next else "讓光指引你的旅途。")

func _spawn_enemies() -> void:
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	var data=[["sentinel",Vector3(32,0,-6)],["sentinel",Vector3(39,0,-14)],["mage",Vector3(49,0,-18)],["sentinel",Vector3(-33,0,-32)],["sentinel",Vector3(-37,0,-43)],["mage",Vector3(28,0,-32)],["elite",Vector3(49,0,-43)],["elite",Vector3(56,0,-53)],["mage",Vector3(59,0,-44)],["sentinel",Vector3(-25,0,-83)]]
	for d in data:
		var p:Vector3=d[1]
		p.y=world.ground_height(p.x,p.z)+0.3
		var e=Foe.new()
		add_child(e)
		e.setup(self,d[0],p)
		enemies.append(e)
	boss=Foe.new()
	add_child(boss)
	boss.setup(self,"boss",AureliaWorld.ARENA+Vector3(0,0.25,-3))
	enemies.append(boss)
	if boss_defeated:
		boss.dead=true
		boss.hide()
		boss.collision_layer=0
	for r in range(1,5):
		var center:Vector3=AureliaWorld.REGIONS[r].center
		for i in 8:
			var a=float(i)*TAU/8
			var p=center+Vector3(cos(a)*53,0.3,sin(a)*53)
			var foe=Foe.new()
			add_child(foe)
			foe.setup(self,["slime","bat","sentinel","mage","elite"][(i+r)%5],p)
			enemies.append(foe)

	for site in WorldAtlas.dungeons:
		var foe=Foe.new()
		foe.boss_profile=int(site.profile)
		add_child(foe)
		foe.setup(self,"guardian",site.center+Vector3(0,.3,0))
		if int(site.profile) in cleared_guardians:
			foe.dead=true;foe.hide();foe.collision_layer=0;foe.collision_mask=0
		enemies.append(foe)
		for i in 3:
			var mob=Foe.new()
			add_child(mob)
			mob.setup(self,"mage" if i==2 else "sentinel",site.center+Vector3(-4+i*4,.3,43+i*7))
			enemies.append(mob)

	for camp in WorldAtlas.camps:
		if not camp.hostile:continue
		for i in 2:
			var mob=Foe.new()
			add_child(mob)
			mob.setup(self,"slime" if i==0 else "sentinel",camp.center+Vector3(-4+i*8,.3,3))
			enemies.append(mob)

func _spawn_people() -> void:
	var people=[
		["伊蓮","晨鐘村村長",Vector3(-4.9,0,18),Color("667d65"),"elder"],
		["米洛","旅行商人",Vector3(-7.9,0,17),Color("a88b5f"),"merchant"],
		["露茜","烹飪師",Vector3(6.7,0,21),Color("c7b994"),"cook"],
		["布蘭","王城鐵匠",Vector3(7.8,0,1.8),Color("86766a"),"smith"],
		["瑟琳","星術導師",Vector3(-6.2,0,-4),Color("7b819a"),"mage"],
		["芬恩","馬廄主人",Vector3(21,0,33),Color("988968"),"stable"],
		["艾達","藥草師",Vector3(7,0,29),Color("799277"),"herbalist"],
		["羅溫","城門衛隊長",Vector3(4.6,0,-44),Color("809794"),"guard"],
		["泰爾","巡遊樂師",Vector3(-5.5,0,7),Color("ae826a"),"bard"],
		["安妮","麵包學徒",Vector3(9,0,13),Color("c7b994"),"baker"],
		["奧斯","湖畔釣客",Vector3(51,0.55,20),Color("8c967d"),"fisher"],
		["里昂","曦光學者",Vector3(6,0,-61),Color("a7a68a"),"scholar"]
	]
	for i in people.size():
		var d=people[i]
		var node=Node3D.new()
		add_child(node)
		node.position=d[2]
		var model=Art.citizen(node,d[4],i)
		Art.limit_visibility(model,42)
		if d[4] in ["cook","baker"]:
			PublicAssets.place(node,"dungeon-remastered/table_medium_tablecloth_decorated_B",Vector3(0,0,-1.25),1.0)
		elif d[4]=="smith":
			PublicAssets.place(node,"medieval-hexagon-pack/weaponrack",Vector3(0,0,-1.1),1.4)
		elif d[4]=="guard":Art.sword(Art.socket(model,"ArmR"))
		var label=Art.label3d(node,d[0]+"\n"+d[1],Vector3(0,2.55,0),Art.IVORY,24)
		label.visibility_range_end=17
		Art.body_box(node,Vector3(0,0.8,0),Vector3(0.55,1.6,0.55))
		var record={"node":node,"name":d[0],"role":d[1],"type":d[4],"id":i,"motion":"work" if d[4]=="smith" else "gather" if d[4] in ["cook","baker","herbalist"] else "dance" if d[4]=="bard" else "relax"}
		npcs.append(record)
		interactables.append(record)
	for pos in [Vector3(5.2,0,31),Vector3(5.2,0,-67)]:
		var shrine=Node3D.new()
		add_child(shrine)
		shrine.position=pos
		PublicAssets.place(shrine,"dungeon-remastered/column",Vector3.ZERO,1.8)
		PublicAssets.place(shrine,"dungeon-remastered/candle_triple",Vector3(0,1.8,0),.5)
		Art.label3d(shrine,"曦光碑",Vector3(0,2.4,0),Art.GOLD,25)
		interactables.append({"node":shrine,"type":"shrine","name":"曦光碑"})

func _spawn_region_people() -> void:
	for r in range(1,5):
		var center:Vector3=AureliaWorld.REGIONS[r].center
		if r==4:center.z+=65
		for i in 4:
			var node=Node3D.new()
			add_child(node)
			node.position=center+Vector3(-9+i*6,0,14)
			var model=PublicCharacter.new()
			node.add_child(model)
			model.configure("character-pack-adventures/"+["Knight","Mage","Rogue","Barbarian"][i])
			var role=["guard","mage","merchant","smith"][i]
			var title=["巡衛","星術師","行商","工匠"][i]
			var record={"node":node,"name":AureliaWorld.REGIONS[r].name+title,"role":title,"type":role,"id":npcs.size(),"motion":["idle","cast","talk","work"][i]}
			npcs.append(record)
			interactables.append(record)
			Art.label3d(node,title,Vector3(0,2.4,0),Art.IVORY,24).visibility_range_end=18
			Art.body_box(node,Vector3(0,.8,0),Vector3(.5,1.6,.5))
		var shrine=Node3D.new()
		add_child(shrine)
		shrine.position=center+Vector3(5,0,8)
		PublicAssets.place(shrine,"dungeon-remastered/column",Vector3.ZERO,1.8)
		PublicAssets.place(shrine,"dungeon-remastered/candle_triple",Vector3(0,1.8,0),.5)
		Art.label3d(shrine,"曦光碑 · 休息與保存",Vector3(0,3,0),Art.GOLD,25)
		interactables.append({"node":shrine,"type":"shrine","name":"曦光碑"})

func _spawn_gathering() -> void:
	var locations:Array[Vector3]=[]
	for i in range(20):locations.append(Vector3(11+(i%5)*7,0,34-floori(float(i)/5)*17))
	for camp in WorldAtlas.camps:
		locations.append(camp.center+Vector3(0,0,4))
		locations.append(camp.center+Vector3(2,0,5))
	for p in locations:
		p.y=world.ground_height(p.x,p.z)
		var herb=Node3D.new()
		add_child(herb)
		herb.position=p
		PublicAssets.place(herb,"medieval-hexagon-pack/waterplant_B",Vector3.ZERO,.65)
		interactables.append({"node":herb,"type":"herb","name":"月露草"})

func _nearby() -> void:
	current_interaction={}
	interact_hint=""
	var nearest=3.0
	for item in interactables:
		if not is_instance_valid(item.node) or not item.node.visible:
			continue
		var d=player.global_position.distance_to(item.node.global_position)
		if d<nearest:
			nearest=d
			current_interaction=item
	if not current_interaction.is_empty():
		interact_hint=("採集 " if current_interaction.type=="herb" else "休息於 " if current_interaction.type=="shrine" else "交談 · ")+current_interaction.name

func interact() -> void:
	if net.online:
		if not current_interaction.is_empty():
			if current_interaction.type in ["herb","shrine"]:net.request("interact",interactables.find(current_interaction))
			else:open_dialogue(current_interaction)
		return
	if current_interaction.is_empty():
		return
	if player.mounted:
		toggle_mount()
	var item=current_interaction
	if item.type=="herb":
		player.herbs+=1
		item.node.hide()
		toast("獲得月露草 ×1","交給烹飪師製作燉湯，或請藥草師調製聖露。")
		sound("pickup")
		return
	if item.type=="shrine":
		var enemy=nearest_enemy(player.global_position,12)
		if enemy and enemy.engaged:
			toast("戰鬥中無法休息","先脫離附近的敵人。")
			return
		checkpoint=item.node.global_position+Vector3(0,0.3,2)
		player.restore()
		_clear_effects()
		_spawn_enemies()
		for resource in interactables:
			if resource.type=="herb":
				resource.node.show()
		save_game()
		toast("已在曦光碑休息並存檔","生命、魔力與聖露瓶已恢復；野外敵人與草藥重新出現。")
		sound("heal")
		return
	open_dialogue(item)

func open_dialogue(item: Dictionary) -> void:
	speaker=item.name+"  /  "+item.role
	dialogue_options=[]
	match item.type:
		"elder":
			if boss_defeated and kills>=3 and quest_active and not quest_rewarded:
				dialogue_text="你回來了……我已經聽見王城久違的鐘聲。\n謝謝你，讓奧瑞利昂終於得以放下那份漫長的誓言。"
				dialogue_options.append({"label":"領取報酬：180 金幣 + 3 月露草","action":reward_quest})
			elif not quest_active:
				dialogue_text="歡迎來到晨鐘村，旅人。這裡的每一盞燈，都為歸來的人而亮。\n但曦白城北方的古龍已迷失於日輪的力量。\n請先清除三名野外敵人，再去日冕聖域解放奧瑞利昂。"
				dialogue_options.append({"label":"接受委託 · 日冕下的古老誓約","action":accept_quest})
			else:
				dialogue_text="願你一路有光，旅人。\n先準備好補給。古龍的爪擊，常在你以為已經結束時落下。\n清除野外威脅：%d / 3　　古龍：%s" % [mini(kills,3),"已解放" if boss_defeated else "尚未解放"]
		"merchant":
			dialogue_text="好貨不必誇口，能讓旅人平安回來，就是最好的招牌。\n聖露瓶可立即恢復 75 點生命；月露草可用於烹飪。"
			dialogue_options.append({"label":"購買聖露瓶 ×1   ·   25 金幣","action":func():trade("flask")})
			dialogue_options.append({"label":"購買月露草 ×2   ·   15 金幣","action":func():trade("herbs")})
		"cook":
			dialogue_text="坐下來，喝點熱湯吧。肚子暖了，握劍的手才不會發抖。\n帶兩株月露草給我，我就替你煮一份暖心燉湯。\n效果：恢復 50 生命，體力恢復速度提升，持續三分鐘。"
			dialogue_options.append({"label":"烹飪暖心燉湯   ·   月露草 ×2","action":func():trade("food")})
		"smith":
			dialogue_text="劍會記住每一次戰鬥留下的痕跡。讓我替它重新開鋒。\n強化會提升劍技與法術傷害；最多可以強化五次。\n目前武器：曦光長劍 +%d" % player.upgrades
			dialogue_options.append({"label":"強化長劍   ·   %d 金幣" % (60+player.upgrades*40),"action":func():trade("upgrade")})
		"herbalist":
			dialogue_text="鏡露湖旁長著銀白花朵的，就是月露草。\n兩株足夠我調製一瓶聖露。"+("共同世界的草藥會在採集後 90 秒重新生長。" if net.online else "休息後草藥也會重新生長。")
			dialogue_options.append({"label":"調製聖露瓶 ×1   ·   月露草 ×2","action":func():trade("brew")})
		"mage":
			dialogue_text="魔法不是命令光，而是學會與它同行。\n星火適合遠攻；霜矢讓敵人緩步；日輪斬可以擊破架勢。\n魔力會緩慢恢復。不要在還有劍可用時耗盡最後一點魔力。"
		"stable":
			dialogue_text="這匹馬叫晨風。牠喜歡蘋果，也喜歡勇敢的旅人。\n按 H 呼喚牠，再靠近按 H 上馬。騎乘時按 Shift 加速。\n馬上可以揮劍和施法；需要翻滾時，記得先下馬。"
		"guard":
			dialogue_text="曦白城的城門仍然向旅人敞開。\n穿過庭院與北門，便是日冕聖域。庭院右側有一座曦光碑。\n東邊裂晶禁林的重衛比原野遊兵更危險，別貿然被包圍。"
		"bard":
			dialogue_text="我寫了一首還沒有結尾的歌，關於日光與遠行的人。\n也許等你回來，我就知道最後一句該怎麼唱了。"
		"baker":
			dialogue_text="今早的麵包加了蜂蜜和迷迭香。\n露茜老師說，廚房也有魔法，只是我們用鍋子來施放。"
		"fisher":
			dialogue_text="湖面越平靜，越能看清天上的雲。人也一樣。\n如果戰鬥讓你心浮氣躁，就來這裡坐一會兒吧。"
		"scholar":
			dialogue_text="奧瑞利昂曾是王國守護天穹的古龍，如今卻被誓言困住。\n生命降至 66% 時甦醒星焰，30% 時降下天穹審判。\n觀察光環與龍翼的動作；震波必須迎面翻滾穿過。"
	dialogue_options.append({"label":"願光與你同在 · 離開","action":func():set_mode("play")})
	set_mode("dialogue")

func accept_quest() -> void:
	if net.online:
		net.request("quest",0)
		set_mode("play")
		return
	quest_active=true
	set_mode("play")
	save_game()
	toast("委託已接受","清除三名野外敵人，前往聖域解放古龍。按 J 查看手記。")

func reward_quest() -> void:
	if net.online:
		net.request("reward",0)
		set_mode("play")
		return
	if quest_rewarded:
		return
	quest_rewarded=true
	player.gold+=180
	player.herbs+=3
	set_mode("play")
	save_game()
	toast("委託完成","獲得 180 金幣與 3 株月露草。晨鐘村永遠歡迎你。")

func trade(item: String, actor: Hero = null) -> bool:
	if net.online and actor==null:
		net.request("trade",RealmSession.TRADES.find(item))
		set_mode("play")
		return true
	var buyer=actor if actor else player
	var cost=25 if item=="flask" else 15 if item=="herbs" else 60+buyer.upgrades*40 if item=="upgrade" else 0
	if buyer.gold<cost:
		toast("金幣不足","探索野外、擊敗敌人後可以獲得更多金幣。")
		return false
	if item in ["food","brew"] and buyer.herbs<2:
		toast("月露草不足","需要兩株月露草，可在野外採集或向商人購買。")
		return false
	if item in ["flask","brew"] and buyer.flasks>=8:
		toast("聖露瓶已達攜帶上限","最多攜帶八瓶。")
		return false
	if item=="upgrade" and buyer.upgrades>=5:
		toast("長劍已達最高強化","曦光長劍 +5")
		return false
	buyer.gold-=cost
	match item:
		"flask": buyer.flasks+=1
		"herbs": buyer.herbs+=2
		"upgrade": buyer.upgrades+=1
		"brew":
			buyer.herbs-=2
			buyer.flasks+=1
		"food":
			buyer.herbs-=2
			buyer.hp=minf(buyer.max_hp,buyer.hp+50)
			buyer.food_time=180
	if actor==null:
		sound("pickup")
		toast("準備好了","補給與裝備已更新。")
		set_mode("play")
	save_game()
	return true

func toggle_mount() -> void:
	if net.online:
		net.request("mount",0)
		return
	if not player.can_act():
		return
	if player.mounted:
		player.mounted=false
		# Keep the dismount at the collision-tested player position.
		horse.position=player.position+player.visual.global_basis.x*1.5
		toast("已下馬","可以再次翻滾與徒步探索。")
	elif player.global_position.distance_to(horse.global_position)<4:
		player.mounted=true
		toast("騎乘晨風","Shift 加速 · H 下馬 · 馬上可使用劍技與魔法")
	else:
		var summon=player.global_position+player.visual.global_basis.x*2.3
		var query=PhysicsRayQueryParameters3D.create(player.global_position+Vector3.UP,summon+Vector3.UP,1)
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			toast("這裡太狹窄","到開闊處再呼喚晨風。")
			return
		horse.global_position=summon
		horse.rotation.y=player.visual.rotation.y
		toast("晨風來到身旁","再按 H 騎上晨風。")

func nearest_enemy(pos: Vector3, radius: float) -> Foe:
	var result:Foe=null
	for e in enemies:
		if is_instance_valid(e) and not e.dead:
			var d=pos.distance_to(e.global_position)
			if d<radius and can_see(pos+Vector3.UP,e.global_position+Vector3.UP,player):
				radius=d
				result=e
	return result

func can_see(a: Vector3, b: Vector3, exclude: CollisionObject3D) -> bool:
	var query=PhysicsRayQueryParameters3D.create(a,b,1,[exclude.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func player_melee(radius: float, damage: float, all_around: bool, actor: Hero = null) -> void:
	var attacker=actor if actor else player
	var forward=-attacker.visual.global_basis.z
	for e in enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		var d=e.global_position-attacker.global_position
		d.y=0
		if d.length()<=radius and (all_around or forward.dot(d.normalized())>0.1) and can_see(attacker.global_position+Vector3.UP,e.global_position+Vector3.UP,attacker):
			e.take_damage(damage,false,all_around or attacker.heavy,attacker)

func fire_projectile(pos: Vector3, direction: Vector3, speed: float, damage: float, source: Node3D, frost: bool) -> void:
	if net.online and net.authoritative():net.broadcast_fx("projectile",[pos,direction,speed,damage,net.actor_id(source),frost])
	var color=Color("9ce3eb") if frost else Color("ebbe78")
	if not source is Hero:
		color=Color("d2977e")
	var n=Art.sphere(self,pos,Vector3.ONE*0.26,color,1.6)
	var ring=Art.torus(n,Vector3.ZERO,0.24,0.025,color,0.7)
	ring.rotation.x=PI/2
	effects.append({"node":n,"type":"projectile","time":3.0,"dir":direction,"speed":speed,"damage":damage,"source":source,"frost":frost,"trail":0.0})

func make_hazard(pos: Vector3, radius: float, delay: float, damage: float, source: Node3D) -> void:
	if net.online and net.authoritative():net.broadcast_fx("hazard",[pos,radius,delay,damage])
	pos.y=maxf(0.21,world.ground_height(pos.x,pos.z)+0.12)
	magic.circle(pos,radius,Color("f3a365"),delay)
	var node=Node3D.new()
	add_child(node)
	node.position=pos
	Art.torus(node,Vector3.ZERO,radius,0.055,Color("eab574"),0.8)
	Art.cylinder(node,Vector3.ZERO,radius,0.025,Color(0.92,0.61,0.31,0.16),-1,40)
	effects.append({"node":node,"type":"hazard","time":delay,"radius":radius,"damage":damage,"source":source})

func shockwave(pos: Vector3, stage: int) -> void:
	if net.online and net.authoritative():net.broadcast_fx("wave",[pos,stage])
	var n=Art.torus(self,Vector3(pos.x,0.38,pos.z),1.0,0.075,Color("efc98b"),1.0)
	effects.append({"node":n,"type":"wave","time":2.2,"radius":1.0,"hit":false,"victims":[],"speed":8.0 if stage==1 else 10.0})

func burst(pos: Vector3, color: Color, radius: float) -> void:
	magic.sparks(pos,color,24,maxf(1,radius*2))

func ring_effect(pos: Vector3, radius: float, color: Color, duration: float) -> void:
	var n=Art.torus(self,pos+Vector3.UP*0.24,radius,0.07,color,0.7)
	effects.append({"node":n,"type":"ring","time":duration,"duration":duration})

func slash(pos: Vector3, angle: float, big: bool) -> void:
	if net.online and net.authoritative():net.broadcast_fx("slash",[pos,angle,big])
	magic.slash_fx(pos,angle,big)

func floating_text(text: String, pos: Vector3, color: Color) -> void:
	if net.online and net.authoritative():net.broadcast_fx("damage",[text,pos,color])
	var n=Art.label3d(self,text,pos,color,40)
	effects.append({"node":n,"type":"text","time":0.9})

func _effects(delta: float) -> void:
	# Iterate backward so newly spawned particles are processed next frame.
	effects_running=true
	for i in range(effects.size()-1,-1,-1):
		var effect=effects[i]
		if not is_instance_valid(effect.node):
			effects.remove_at(i)
			continue
		var n:Node3D=effect.node
		effect.time-=delta
		match effect.type:
			"projectile":
				if not is_instance_valid(effect.source):
					n.queue_free()
					effects.remove_at(i)
					continue
				effect.trail-=delta
				if effect.trail<=0:
					magic.trail(n.global_position,effect.dir,Color("8ee9ff") if effect.frost else Color("ffbc6b"))
					effect.trail=0.05
				var target=n.global_position+effect.dir*effect.speed*delta
				var query=PhysicsRayQueryParameters3D.create(n.global_position,target,1|4 if effect.source is Hero else 1|2,[effect.source.get_rid()])
				var hit=get_world_3d().direct_space_state.intersect_ray(query)
				if not hit.is_empty():
					magic.impact(hit.position,Color("8ee9ff") if effect.frost else Color("ffbc6b"),1.0)
					if hit.collider is Foe:
						hit.collider.take_damage(effect.damage,effect.frost,false,effect.source)
					elif hit.collider is Hero:
						hit.collider.take_damage(effect.damage,n.global_position)
					burst(hit.position,Color("ead29f"),0.6)
					effect.time=0
				n.global_position=target
			"hazard":
				n.rotation.y+=delta*0.5
				if effect.time<=0:
					magic.impact(n.global_position,Color("ffab70"),effect.radius,true)
					burst(n.global_position+Vector3.UP,Color("efc990"),3)
					ring_effect(n.global_position,effect.radius,Color("f5d493"),0.5)
					for actor in living_players():
						var d=actor.global_position-n.global_position
						d.y=0
						if d.length()<effect.radius:actor.take_damage(effect.damage,n.global_position)
			"wave":
				effect.radius+=delta*effect.speed
				n.scale=Vector3(effect.radius,1,effect.radius)
				for actor in living_players():
					var dist=Vector2(actor.global_position.x-n.global_position.x,actor.global_position.z-n.global_position.z).length()
					if absf(dist-effect.radius)<0.65 and not effect.victims.has(actor.get_instance_id()):
						effect.victims.append(actor.get_instance_id())
						actor.take_damage(35,n.global_position)
			"spark":
				n.position+=effect.dir*delta*3
				n.scale*=1.0-delta*2
			"text":
				n.position.y+=delta*0.85
				n.modulate.a=minf(1,effect.time*2)
			"ring":
				n.scale=Vector3.ONE*(1.0+(1-effect.time/effect.duration)*0.2)
			"slash":
				n.rotation.y+=delta*5
		if effects_clear_requested:
			break
		if effect.time<=0:
			n.queue_free()
			effects.remove_at(i)
	effects_running=false
	if effects_clear_requested:
		effects_clear_requested=false
		_clear_effects()

func _clear_effects() -> void:
	if magic:magic.clear()
	if effects_running:
		effects_clear_requested=true
		return
	for effect in effects:
		if is_instance_valid(effect.node):
			effect.node.queue_free()
	effects.clear()

func enemy_defeated(enemy: Foe) -> void:
	if net.online:
		net.enemy_defeated(enemy)
		return
	if enemy.rewarded:return
	enemy.rewarded=true
	var xp=Progression.reward(enemy)
	var gained=player.gain_experience(xp)
	call_deferred("experience_feedback",player,xp,gained)
	if enemy.is_boss and enemy!=boss:
		if not enemy.boss_profile in cleared_guardians:cleared_guardians.append(enemy.boss_profile)
		player.gold+=350
		toast("擊敗 "+enemy.title,"獲得 350 金幣；繼續探索其他地城。")
		save_game()
		return
	if enemy.is_boss:
		boss_defeated=true
		player.gold+=500
		_clear_effects()
		save_game()
		set_mode("victory")
	else:
		kills+=1
		var reward=45 if enemy.kind=="elite" else 18
		player.gold+=reward
		if kills%2==0:
			player.herbs+=1
		toast("擊敗 "+enemy.title,"+%d 金幣" % reward)
		save_game()
	sound("pickup")

func hero_died(actor: Hero = null) -> void:
	if net.online:
		net.hero_died(actor)
		return
	player.gold=int(player.gold*0.85)
	player.mounted=false
	_clear_effects()
	set_mode("dead")
	save_game()

func respawn() -> void:
	if net.online:
		net.request("respawn",0)
		return
	world.stream.update_centers([checkpoint],true)
	player.position=checkpoint
	player.restore()
	player.mounted=false
	horse.position=checkpoint+Vector3(2,0,2)
	_clear_effects()
	_spawn_enemies()
	set_mode("play")
	toast("旅途仍在繼續","曦光碑的光，會記得每一次歸來。")

func toast(title: String, body: String = "") -> void:
	toast_title=title
	toast_body=body
	toast_time=4.2

func save_game(path: String = SAVE_PATH) -> void:
	if net.online:
		net.save_world()
		return
	if test_mode and path==SAVE_PATH:
		return
	var data={"version":4,"world_layout":WorldAtlas.LAYOUT_VERSION,"level":player.level,"experience":player.experience,"cleared_guardians":cleared_guardians,"profile":player.profile,"gold":player.gold,"herbs":player.herbs,"upgrades":player.upgrades,"flasks":4 if player.dead else player.flasks,"food_time":player.food_time,"quest_active":quest_active,"quest_rewarded":quest_rewarded,"boss_defeated":boss_defeated,"kills":kills,"checkpoint":[checkpoint.x,checkpoint.y,checkpoint.z]}
	var f=FileAccess.open(path,FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data,"\t"))
		has_save=true

func load_game(path: String = SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var f=FileAccess.open(path,FileAccess.READ)
	if not f:
		return false
	var d=JSON.parse_string(f.get_as_text())
	if not d is Dictionary or not int(d.get("version",0)) in [1,2,3,4]:
		return false
	var cp=d.get("checkpoint",[4,0.4,30])
	if not cp is Array or cp.size()!=3:
		return false
	for key in ["gold","herbs","upgrades","kills","flasks","food_time"]:
		if not (d.get(key,0) is float or d.get(key,0) is int):
			return false
	for v in cp:
		if not (v is float or v is int):
			return false
	if d.get("profile",{}) is Dictionary:player.apply_profile(d.get("profile",{}))
	player.load_progress(d)
	player.gold=clampi(int(d.get("gold",80)),0,999999)
	player.herbs=clampi(int(d.get("herbs",0)),0,9999)
	player.upgrades=clampi(int(d.get("upgrades",0)),0,5)
	quest_active=bool(d.get("quest_active",false))
	quest_rewarded=bool(d.get("quest_rewarded",false)) and d.get("version",1)>=2
	boss_defeated=bool(d.get("boss_defeated",false)) and d.get("version",1)>=2
	cleared_guardians.clear()
	var cleared=d.get("cleared_guardians",[])
	if cleared is Array:
		for item in cleared.slice(0,19):
			if (item is int or item is float) and is_finite(float(item)) and int(item)>=0 and int(item)<19 and not int(item) in cleared_guardians:cleared_guardians.append(int(item))
	kills=maxi(0,int(d.get("kills",0)))
	checkpoint=WorldAtlas.restore_checkpoint(Vector3(cp[0],cp[1],cp[2]),int(d.get("world_layout",1)))
	world.stream.update_centers([checkpoint],true)
	player.position=checkpoint
	player.restore()
	player.flasks=clampi(int(d.get("flasks",4)),0,8)
	player.food_time=clampf(float(d.get("food_time",0)),0,180)
	player.mounted=false
	_clear_effects()
	_spawn_enemies()
	return true

func _audio() -> void:
	for key in ["sword","spell","hurt","heal","pickup","roll","boss","skill","arcane_lightning","arcane_meteor","arcane_blizzard","arcane_wind","arcane_swords","arcane_beam","arcane_ward","arcane_comet"]:
		var path="res://assets/audio/"+key+".wav"
		if ResourceLoader.exists(path):
			sounds[key]=load(path)
	if ResourceLoader.exists("res://assets/audio/meadow.wav"):
		music=AudioStreamPlayer.new()
		music.stream=load("res://assets/audio/meadow.wav")
		music.volume_db=-15
		add_child(music)
		music.finished.connect(music.play)
		if not test_mode and DisplayServer.get_name()!="headless":
			music.play()

func sound(key: String) -> void:
	if test_mode or not sounds.has(key):
		return
	var s=AudioStreamPlayer.new()
	s.stream=sounds[key]
	s.volume_db=-12
	add_child(s)
	s.finished.connect(s.queue_free)
	s.play()

func _run_smoke() -> void:
	var suite=load("res://tests/smoke.gd").new()
	await suite.run(self)

func _run_magic_tests() -> void:
	var suite=load("res://tests/magic.gd").new()
	await suite.run(self)

func _capture_magic() -> void:
	var capture=load("res://tests/magic_capture.gd").new()
	await capture.run(self)

func _capture() -> void:
	await get_tree().create_timer(3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://screenshots/01-title.png")
	set_mode("play")
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	await get_tree().create_timer(1).timeout
	await get_tree().create_timer(2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://screenshots/02-village.png")
	print("VILLAGE_RENDER: fps=",Engine.get_frames_per_second()," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," primitives=",Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	set_mode("map")
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://screenshots/03-map.png")
	player.position=Vector3(0,0.5,-39)
	player.yaw=0
	set_mode("play")
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	await get_tree().create_timer(0.7).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://screenshots/04-castle.png")
	player.position=Vector3(0,0.5,-94)
	await get_tree().create_timer(0.7).timeout
	set_mode("pause")
	mode="play"
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://screenshots/05-boss.png")
	print("CAPTURE COMPLETE")
	get_tree().quit()

func _run_motion_tests() -> void:
	await load("res://tests/motion.gd").new().run(self)

func _capture_motion() -> void:
	await load("res://tests/motion_capture.gd").new().run(self)

func world_running() -> bool:
	return mode=="play" or (net!=null and net.online)

func living_players() -> Array:
	var result=[]
	for actor in net.avatars.values() if net!=null and net.online else [player]:
		if is_instance_valid(actor) and not actor.dead:result.append(actor)
	return result

func closest_player(pos: Vector3) -> Hero:
	var result:Hero=null
	var best=INF
	for actor in living_players():
		var distance=pos.distance_squared_to(actor.global_position)
		if distance<best:
			best=distance
			result=actor
	return result

func _spawn_continental_people() -> void:
	for site in WorldAtlas.settlements:
		for i in 3:
			var node=Node3D.new()
			add_child(node)
			node.position=site.center+Vector3(-5+i*5,0,8)
			var role=["merchant","cook","smith"][i]
			var title=["行商","烹飪師","工匠"][i]
			var record={"node":node,"name":site.name+title,"role":title,"type":role,"id":npcs.size(),"motion":"work" if i==2 else "talk","streamed":true,"asset":["Rogue","Mage","Barbarian"][i]}
			npcs.append(record)
			interactables.append(record)
			Art.body_box(node,Vector3(0,.8,0),Vector3(.55,1.6,.55))
			var label=Art.label3d(node,record.name,Vector3(0,2.4,0),Art.IVORY,24)
			label.visibility_range_end=17
		var shrine=Node3D.new()
		add_child(shrine)
		shrine.position=site.center+Vector3(0,0,15)
		var label=Art.label3d(shrine,"曦光路標 · "+site.name,Vector3(0,2.6,0),Art.GOLD,24)
		label.visibility_range_end=22
		interactables.append({"node":shrine,"type":"shrine","name":site.name+"曦光碑"})

func travel_to(index: int, actor: Hero = null) -> bool:
	if actor==null:actor=player
	if index<0 or index>WorldAtlas.settlements.size() or not actor.can_act():return false
	var near=false
	for item in interactables:
		if item.type=="shrine" and actor.position.distance_to(item.node.position)<5:near=true;break
	if not near:
		toast("請先靠近曦光碑","在城鎮曦光碑旁開啟地圖，即可使用驛站旅行。")
		return false
	for foe in enemies:
		if not foe.dead and foe.engaged and foe.position.distance_to(actor.position)<35:return false
	var destination=Vector3(4,.4,30) if index==0 else WorldAtlas.settlements[index-1].center+Vector3(0,.4,18)
	var points:Array=[destination]
	if net.online and net.authoritative():
		for other in net.avatars.values():
			if other!=actor:points.append(other.position)
	world.stream.update_centers(points,true)
	actor.position=destination
	actor.velocity=Vector3.ZERO
	actor.personal_checkpoint=destination
	if actor==player:
		checkpoint=destination
		set_mode("play")
		save_game()
	return true

func _exit_tree() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream=null

func experience_feedback(actor: Hero, xp: int, gained: int) -> void:
	if not is_instance_valid(actor):return
	var message="+%d EXP"%xp
	if gained>0:message+=" · 升至 Lv.%d，生命、魔力與傷害提升"%actor.level
	if net.online:
		net._notify(actor.network_id,message)
	elif mode=="play":
		floating_text("+%d EXP"%xp,actor.position+Vector3.UP*2,Color("a5e8da"))
		if gained>0:
			ring_effect(actor.position,2.5,Color("f2d287"),1.2)
			toast("等級提升 · Lv.%d"%actor.level,message)
