class_name AureliaHUD
extends Control

var game: Node3D
var sans: SystemFont
var serif: SystemFont
var controls: Control
var atlas_view=true
var last_mode = ""
var last_speaker = ""
const INK = Color("192f30")
const PAPER = Color("f2e6cb")
const MUTED = Color("a8bdb1")
const GOLD = Color("d8b77a")

func setup(owner_game: Node3D) -> void:
	game=owner_game
	Localizer.current.changed.connect(_rebuild_buttons)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	sans=SystemFont.new()
	sans.font_names=PackedStringArray(["PingFang TC","Noto Sans CJK TC","Microsoft JhengHei","sans-serif"])
	sans.fallbacks=[load("res://assets/fonts/NotoSansCJKtc-Regular.otf")]
	serif=SystemFont.new()
	serif.font_names=PackedStringArray(["Baskerville","Georgia","serif"])
	controls=Control.new()
	controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	controls.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(controls)

func _process(_delta: float) -> void:
	if game.mode!=last_mode or game.speaker!=last_speaker:
		last_mode=game.mode
		last_speaker=game.speaker
		_rebuild_buttons()
	queue_redraw()

func txt(text: String, p: Vector2, size: int = 18, color: Color = PAPER, font: Font = null, width: float = -1, localize: bool = true) -> void:
	var f=sans if font==null else font
	var value=Localizer.current.render(text) if localize else text
	var limit=width if width>0 else 1560-p.x
	var measured=f.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	var fitted=mini(size,maxi(10,floori(size*limit/maxf(1,measured))))
	draw_string(f,p,value,HORIZONTAL_ALIGNMENT_LEFT,-1,fitted,color)

func centered(text: String, p: Vector2, size: int = 18, color: Color = PAPER, font: Font = null, width: float = -1) -> void:
	var f=sans if font==null else font
	var value=Localizer.current.render(text)
	var limit=width if width>0 else minf(p.x,1600-p.x)*2-40
	var measured=f.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	var fitted=mini(size,maxi(10,floori(size*limit/maxf(1,measured))))
	txt(value,p-Vector2(f.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,fitted).x/2,0),fitted,color,f,limit,false)

func wrapped(text:String, width:float, size:int) -> PackedStringArray:
	var value=Localizer.current.render(text)
	var lines:PackedStringArray=[]
	var line=""
	var words=value.split(" ") if Localizer.current.locale=="en" else value.split("")
	var separator=" " if Localizer.current.locale=="en" else ""
	for word in words:
		var next=word if line.is_empty() else line+separator+word
		if not line.is_empty() and sans.get_string_size(next,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width:
			lines.append(line);line=word
		else:line=next
	if not line.is_empty():lines.append(line)
	return lines

func panel(rect: Rect2, alpha: float = 0.9) -> void:
	draw_style_box(style(Color(INK,alpha),Color(GOLD,0.34)),rect)

func style(bg: Color, border: Color, radius: int = 4) -> StyleBoxFlat:
	var s=StyleBoxFlat.new()
	s.bg_color=bg
	s.border_color=border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left=20
	s.content_margin_right=20
	return s

func _draw() -> void:
	if game==null:
		return
	var mode=game.mode
	if mode=="menu":
		_menu()
	elif mode=="character":
		draw_rect(Rect2(0,0,1600,900),Color(INK,.96))
		centered("創建你的旅人",Vector2(800,150),40)
		centered("選擇外觀、職業與第一組術式；其餘技能仍可用 Tab 切換",Vector2(800,195),18,MUTED)
		if game.toast_time>0:centered(game.toast_title,Vector2(800,722),18,GOLD)
		for i in 6:txt(["角色性別","冒險職業","技能 1","技能 2","技能 3","技能 4"][i],Vector2(450,273+i*68),20,GOLD)
		centered("騎士生命較高 · 法師魔力較高 · 遊俠移動較快",Vector2(800,690),18,MUTED)
	elif mode=="network":
		_menu()
		panel(Rect2(485,170,700,620),0.98)
		centered("共同世界",Vector2(835,226),35)
		centered("與其他旅人一起探索、挑戰同一位古龍",Vector2(835,264),17,MUTED)
		txt("角色名稱",Vector2(535,312),17,GOLD)
		txt("伺服器位址",Vector2(535,410),17,GOLD)
		txt("連接埠",Vector2(1000,410),17,GOLD)
		centered(game.net.status,Vector2(835,520),15,GOLD)
		centered("聯機時開啟選單不會暫停世界 · 合作 PvE",Vector2(835,749),16,MUTED)
	elif mode=="play":
		_play()
	elif mode=="dialogue":
		_play()
		draw_rect(Rect2(0,0,1600,900),Color(0.03,0.08,0.08,0.36))
		panel(Rect2(345,170,910,550),0.98)
		txt("PEOPLE OF AURELIA",Vector2(390,215),14,GOLD)
		txt(game.speaker,Vector2(390,266),31)
		draw_line(Vector2(390,287),Vector2(1210,287),Color(GOLD,0.35))
		var lines=Localizer.current.render(game.dialogue_text).split("\n")
		for i in lines.size():
			txt(lines[i],Vector2(390,327+i*31),19,MUTED,null,820)
		txt("持有  %d 金幣  ·  %d 月露草" % [game.player.gold,game.player.herbs],Vector2(390,683),16,GOLD)
	elif mode=="map":
		_map()
	elif mode=="journal":
		_journal()
	elif mode=="spellbook":
		_spellbook()
	elif mode=="guide":
		_guide()
	elif mode=="credits":
		draw_rect(Rect2(0,0,1600,900),Color(INK,.98))
		txt("素材作者與授權",Vector2(100,120),36,GOLD)
	elif mode=="pause":
		_play()
		draw_rect(Rect2(0,0,1600,900),Color(0.025,0.065,0.065,0.7))
		panel(Rect2(575,200,450,495),0.96)
		centered("旅途暫歇",Vector2(800,270),34)
		centered("世界仍在運行，請找安全的地方停留" if game.net.online else "A MOMENT OF STILLNESS",Vector2(800,303),14,GOLD,serif)
	elif mode=="dead":
		draw_rect(Rect2(0,0,1600,900),Color(0.09,0.12,0.12,0.85))
		centered("光芒未熄",Vector2(800,366),60,PAPER,serif)
		centered("THE LIGHT REMAINS",Vector2(800,414),19,GOLD,serif)
		centered("失去 15% 金幣。於最近的曦光碑重生，再次踏上旅程。",Vector2(800,469),20,MUTED)
	elif mode=="victory":
		draw_rect(Rect2(0,0,1600,900),Color(0.07,0.17,0.15,0.87))
		_sun(Vector2(800,246),55,GOLD)
		centered("黎明，因你而至",Vector2(800,380),55,PAPER,serif)
		centered("OATH OF THE DAWN",Vector2(800,429),21,GOLD,serif)
		centered("奧瑞利昂終於收起龍翼。古老的誓約，化為守護這片大地的光。",Vector2(800,489),20,MUTED)
		centered("獲得 500 金幣 · 日冕之印     村長在晨鐘村等待你的消息。",Vector2(800,527),18,GOLD)
	if game.toast_time>0 and mode!="menu":
		panel(Rect2(540,103,520,84),minf(0.94,game.toast_time))
		centered(game.toast_title,Vector2(800,134),21,GOLD,null,480)
		centered(game.toast_body,Vector2(800,164),14,PAPER,null,480)

func _sun(p: Vector2, radius: float, color: Color) -> void:
	draw_arc(p,radius,0,TAU,64,color,1.5,true)
	draw_arc(p,radius*0.72,0,TAU,48,Color(color,0.4),1,true)
	for i in range(12):
		var d=Vector2.from_angle(i*TAU/12)
		draw_line(p+d*radius*1.13,p+d*radius*1.36,color,1.5,true)
	draw_line(p+Vector2(0,-radius*0.5),p+Vector2(0,radius*0.6),color,2,true)
	draw_line(p+Vector2(-radius*0.24,radius*0.18),p+Vector2(radius*0.24,radius*0.18),color,2,true)

func _menu() -> void:
	draw_polygon(PackedVector2Array([Vector2(0,0),Vector2(1100,0),Vector2(1100,900),Vector2(0,900)]),PackedColorArray([Color(0.03,0.09,0.085,0.96),Color(0.03,0.09,0.085,0),Color(0.03,0.09,0.085,0),Color(0.03,0.09,0.085,0.96)]))
	draw_rect(Rect2(0,840,1600,60),Color(0.055,0.11,0.1,0.72))
	_sun(Vector2(97,105),24,GOLD)
	txt("S W O R D   &   S P E L L",Vector2(145,112),17,GOLD,serif)
	txt("AURELIA",Vector2(70,285),103,PAPER,serif)
	txt("曦 光 之 境",Vector2(78,339),33,GOLD)
	draw_line(Vector2(80,380),Vector2(145,380),GOLD,2)
	txt("在仍有光的世界，寫下你的傳說。",Vector2(80,421),22,PAPER)
	txt("越過晨鐘村的石橋，前往古老王城。",Vector2(80,466),17,MUTED)
	txt("以劍與魔法，挑戰日冕下最後的古龍。",Vector2(80,495),17,MUTED)
	txt("01     開放原野",Vector2(83,749),16,PAPER)
	txt("02     劍術與法術",Vector2(263,749),16,PAPER)
	txt("03     古龍之戰",Vector2(464,749),16,PAPER)
	txt("原生 GODOT 3D  ·  可玩原型",Vector2(80,877),13,MUTED)
	txt("晨鐘村   /   初秋 · 晴",Vector2(1330,877),14,PAPER)
	panel(Rect2(1210,665,310,119),0.75)
	txt("THE SUNLIT REALMS",Vector2(1236,697),13,GOLD,serif)
	txt("晨鐘村",Vector2(1236,731),25,PAPER)
	txt("旅人的第一盞燈，永遠為你而亮。",Vector2(1236,762),14,MUTED)

func _bar(p: Vector2, width: float, value: float, maximum: float, color: Color, height: float = 8) -> void:
	draw_rect(Rect2(p,Vector2(width,height)),Color(0.035,0.09,0.09,0.7))
	draw_rect(Rect2(p+Vector2(1,1),Vector2((width-2)*clampf(value/maximum,0,1),height-2)),color)
	draw_rect(Rect2(p,Vector2(width,height)),Color(PAPER,0.22),false,1)

func _play() -> void:
	var p=game.player
	draw_polygon(PackedVector2Array([Vector2(0,710),Vector2(1600,710),Vector2(1600,900),Vector2(0,900)]),PackedColorArray([Color(INK,0),Color(INK,0),Color(INK,0.83),Color(INK,0.83)]))
	draw_polygon(PackedVector2Array([Vector2(460,0),Vector2(1140,0),Vector2(1140,103),Vector2(460,103)]),PackedColorArray([Color(INK,0.48),Color(INK,0.48),Color(INK,0),Color(INK,0)]))
	panel(Rect2(28,27,320,137),0.73)
	_sun(Vector2(65,66),18,GOLD)
	txt(game.net.nickname if game.net.online else "曦光旅人",Vector2(101,58),18,PAPER,null,220,not game.net.online)
	txt("%s · LV. %02d · 長劍 +%d" % [CharacterProfile.CLASSES[p.profile.job],p.level,p.upgrades],Vector2(101,81),12,GOLD,null,237)
	_bar(Vector2(49,97),277,p.hp,p.max_hp,Color("c57665"),11)
	_bar(Vector2(49,114),134,p.mana,p.max_mana,Color("79b7c4"),7)
	_bar(Vector2(192,114),134,p.stamina,100,Color("b2c681"),7)
	txt("%d / %d" % [p.hp,p.max_hp],Vector2(262,93),11,MUTED)
	var needed=Progression.required(p.level)
	_bar(Vector2(49,136),277,p.experience if needed>0 else 1,needed if needed>0 else 1,Color("8dd6bc"),5)
	txt("等級已滿 · Lv.50" if needed==0 else "%d / %d EXP"%[p.experience,needed],Vector2(49,156),11,MUTED)
	# Compact compass with destination bearing.
	draw_line(Vector2(596,47),Vector2(1004,47),Color(PAPER,0.35),1)
	for i in range(-4,5):
		var x=800+i*45
		draw_line(Vector2(x,43),Vector2(x,51 if i%2==0 else 48),Color(PAPER,0.5))
	centered("N",Vector2(800,32),15,GOLD,serif)
	draw_colored_polygon(PackedVector2Array([Vector2(795,59),Vector2(805,59),Vector2(800,64)]),GOLD)
	centered(game.zone_name,Vector2(800,88),18,PAPER)
	panel(Rect2(1301,27,271,96),0.73)
	txt("☼   %04d" % p.gold,Vector2(1323,61),20,GOLD)
	txt("M 地圖   J 手記   K 魔法書",Vector2(1323,96),15,MUTED)
	if game.net.online:
		txt("共同世界  %d / 32 人" % game.net.avatars.size(),Vector2(1310,148),17,Color("a9e9ff"))
	var active_boss:Foe=null
	for foe in game.enemies:
		if foe.is_boss and foe.engaged and not foe.dead and foe.position.distance_to(p.position)<40:active_boss=foe;break
	if active_boss:
		var b=active_boss
		panel(Rect2(400,660,800,125),0.83)
		centered(b.title+ ("  ·  天穹審判" if b.phase==3 else "  ·  星焰甦醒" if b.phase==2 else ""),Vector2(800,728),21,PAPER)
		_bar(Vector2(445,741),710,b.hp,b.max_hp,Color("c2a36b"),12)
		centered(str(int(b.hp))+" / "+str(int(b.max_hp)),Vector2(800,773),12,GOLD)
		if b.state=="windup":
			centered(b.attack.get("name",""),Vector2(800,688),23,Color("f4d19a"))
		elif b.state=="stagger":
			centered("架勢崩解",Vector2(800,688),23,GOLD)
	else:
		panel(Rect2(23,184,352,129 if game.quest_active else 105),0.65)
		txt("當前旅途",Vector2(34,206),13,GOLD)
		txt("日冕下的古老誓約",Vector2(34,239),22,PAPER,null,330)
		var objective="與村長伊蓮交談" if not game.quest_active else ("返回晨鐘村，告知村長" if game.boss_defeated else "穿過曦白城，挑戰天穹古龍")
		txt("◇  "+objective,Vector2(34,270),15,MUTED,null,330)
		if game.quest_active:
			txt("清除野外威脅  %d / 3" % mini(3,game.kills),Vector2(53,298),14,MUTED)
	# Skills, cooldown numbers, and resources stay visible during combat.
	txt("Tab  ◇  "+Spellcraft.PAGES[p.spell_page]+"   %d / 3" % (p.spell_page+1),Vector2(527,793),13,GOLD)
	for i in 4:
		var index=p.skill_index(i)
		var spell=Spellcraft.SPELLS[index]
		var x=520+i*108
		var remaining=p.cooldown(index)
		var color=Color(spell.color)
		panel(Rect2(x,801,100,80),0.92)
		draw_line(Vector2(x+2,803),Vector2(x+98,803),Color(color,0.8),2)
		if remaining>0:
			draw_rect(Rect2(x+2,804,96,75*remaining/spell.cd),Color(0.01,0.03,0.07,0.65))
		txt(str(i+1),Vector2(x+10,824),14,color)
		_spell_icon(index,Vector2(x+68,822),11,color if remaining<=0 else MUTED)
		centered(spell.name,Vector2(x+50,848),15,PAPER if remaining<=0 else MUTED,null,92)
		centered("%.1fs" % remaining if remaining>0 else "%d MP" % spell.cost,Vector2(x+50,871),12,Color("db8a77") if p.mana<spell.cost else MUTED)
	panel(Rect2(952,801,88,80),0.92)
	txt("R",Vector2(963,824),14,GOLD)
	centered("聖露瓶",Vector2(996,848),15,PAPER,null,80)
	centered(str(p.flasks)+" 瓶",Vector2(996,871),12,MUTED)
	if p.ward_time>0 and p.ward_hp>0:
		txt("星紗護壁  %d  ·  %.1fs" % [p.ward_hp,p.ward_time],Vector2(33,195 if p.food_time>0 else 174),14,Color("84ddff"))
	txt("左鍵  輕攻擊    右鍵  重攻擊",Vector2(31,813),15,PAPER,null,430)
	txt("Space  翻滾    Shift  奔跑    Q  鎖定",Vector2(31,841),14,MUTED,null,430)
	txt("H  "+("下馬" if p.mounted else "呼喚／騎馬")+"     E  互動     Esc  "+("選單" if game.net.online else "暫停"),Vector2(31,868),14,MUTED,null,430)
	if p.food_time>0:
		txt("暖心燉湯  ·  體力恢復提升 %ds" % p.food_time,Vector2(33,174),14,GOLD)
	if game.interact_hint!="":
		panel(Rect2(1110,794,456,79),0.86)
		txt("E",Vector2(1130,840),24,GOLD)
		txt(game.interact_hint,Vector2(1170,841),18,PAPER)
	if is_instance_valid(p.locked_target):
		var cam=p.camera
		var point=p.locked_target.global_position+Vector3.UP*1.6
		if not cam.is_position_behind(point):
			var xy=cam.unproject_position(point)
			draw_arc(xy,8,0,TAU,24,GOLD,1.5,true)
	if game.damage_flash>0:
		draw_rect(Rect2(0,0,1600,900),Color(0.6,0.12,0.04,game.damage_flash*0.3))

func _spell_icon(index: int, p: Vector2, r: float, color: Color) -> void:
	match index:
		0,5,11:
			draw_arc(p,r*0.55,0,TAU,16,color,1.6,true)
			for i in 3:draw_line(p+Vector2(-r*0.4+i*r*0.4,-r*0.25),p+Vector2(-r+i*r*0.35,-r*(1.6 if index==11 else 1.0)),color,1.5,true)
		1,6:
			for i in 6:
				var d=Vector2.from_angle(i*TAU/6)
				draw_line(p,p+d*r,color,1.3,true)
				if index==6:draw_circle(p+d*r,1.5,color)
		2:
			_sun(p,r,color)
		3:
			draw_line(p-Vector2(r,0),p+Vector2(r,0),color,3,true)
			draw_line(p-Vector2(0,r),p+Vector2(0,r),color,3,true)
		4:
			draw_polyline(PackedVector2Array([p+Vector2(r*.5,-r),p+Vector2(-r*.5,0),p+Vector2(r*.4,0),p+Vector2(-r*.6,r)]),color,2,true)
		7:
			for i in 3:draw_arc(p+Vector2(i*3-3,i*4-4),r,-2.8,-0.2,16,color,1.3,true)
		8:
			for i in 3:
				var v=p+Vector2(i*7-7,0)
				draw_line(v-Vector2(0,r),v+Vector2(0,r),color,1.8,true)
				draw_line(v+Vector2(-3,3),v+Vector2(3,3),color,1.2,true)
		9:
			draw_line(p-Vector2(r,r),p+Vector2(r,r),color,3,true)
			draw_arc(p,r,-2.5,0.5,20,color,1.2,true)
		10:
			draw_polyline(PackedVector2Array([p+Vector2(0,-r),p+Vector2(r,-r*.5),p+Vector2(r*.7,r*.5),p+Vector2(0,r),p+Vector2(-r*.7,r*.5),p+Vector2(-r,-r*.5),p+Vector2(0,-r)]),color,1.8,true)

func _spellbook() -> void:
	draw_rect(Rect2(0,0,1600,900),Color(INK,0.98))
	txt("THE ARCANE ARTS",Vector2(100,83),16,GOLD,serif)
	txt("星與劍的十二術式",Vector2(100,136),37)
	txt("Tab 切換術式組 · 1–4 施放 · Q 鎖定目標 · 冷卻跨組保留",Vector2(100,179),17,MUTED)
	for page in 3:
		var x=100+page*477
		txt("0%d   %s" % [page+1,Spellcraft.PAGES[page]],Vector2(x,228),24,GOLD)
		for slot in 4:
			var index=game.player.profile.skills[page*4+slot]
			var s=Spellcraft.SPELLS[index]
			var y=253+slot*137
			var color=Color(s.color)
			panel(Rect2(x,y,448,121),0.86)
			_spell_icon(index,Vector2(x+29,y+29),13,color)
			txt("%d  %s" % [slot+1,s.name],Vector2(x+55,y+35),22,color)
			txt("%d MP  ·  %.1fs 冷卻" % [s.cost,s.cd],Vector2(x+18,y+64),14,GOLD)
			var lines=wrapped(s.desc,408,16)
			for line in mini(lines.size(),2):txt(lines[line],Vector2(x+18,y+88+line*21),16,MUTED,null,408)
	txt("範圍法術會瞄準鎖定敵人或前方地面；大型術式有前搖，敵人可在期間攻擊。",Vector2(100,841),17,GOLD)

func _map_point(v: Vector3) -> Vector2:
	return Vector2(800+v.x*635.0/WorldAtlas.HALF_SIZE,465+v.z*305.0/WorldAtlas.HALF_SIZE) if atlas_view else Vector2(800+v.x*2.3,740+v.z*1.45)

func _map() -> void:
	draw_rect(Rect2(0,0,1600,900),Color("dcd5bb"))
	for i in range(45):
		draw_line(Vector2(110+i*32,138),Vector2(110+i*32,813),Color(INK,0.035))
	for i in range(22):
		draw_line(Vector2(96,137+i*32),Vector2(1504,137+i*32),Color(INK,0.035))
	txt("THE SUNLIT REALMS",Vector2(70,61),15,Color("8a754a"),serif)
	txt("曦光領地",Vector2(69,110),35,INK)
	txt("領地圖誌 · 2.4 × 2.4 公里" if atlas_view else "晨曦腹地 · 起始五區",Vector2(310,106),16,Color("63746a"))
	for pair in (WorldAtlas.roads if atlas_view else AureliaWorld.ROUTES):
		draw_line(_map_point(pair[0]),_map_point(pair[1]),Color("b39968"),3,true)
	if atlas_view:
		for region in WorldAtlas.REGIONS:
			var p=_map_point(region.center)
			centered(region.name,p+Vector2(0,-30),20,INK)
		for site in WorldAtlas.settlements:
			var p=_map_point(site.center)
			draw_circle(p,4 if site.type=="town" else 2.5,Color("44685e"))
			if site.type!="hamlet":txt(site.name,p+Vector2(6,13),11,INK)
		for camp in WorldAtlas.camps:
			draw_rect(Rect2(_map_point(camp.center)-Vector2(2,2),Vector2(4,4)),Color("b5814b") if camp.hostile else Color("6d8791"))
		for site in WorldAtlas.dungeons:
			var p=_map_point(site.center)
			draw_circle(p,4,Color("809682") if int(site.profile) in game.cleared_guardians else Color("aa5b43"))
			txt(str(site.profile+1),p+Vector2(5,-3),11,Color("93422e"))
		var final=_map_point(AureliaWorld.ARENA)
		draw_circle(final,6,Color("aa5b43"))
		txt("20 · 天穹古龍",final+Vector2(12,-5),13,INK)
	else:
		for region in AureliaWorld.REGIONS:
			var p=_map_point(region.center)
			draw_circle(p,58,Color("b4bea2"))
			draw_circle(p,7,INK)
			txt(region.name,p+Vector2(19,-5),23,INK)
			txt(region.detail,p+Vector2(19,20),13,Color("657268"))
	var pp=_map_point(game.player.global_position)
	draw_circle(pp,6,Color("b46c46"))
	draw_arc(pp,15,0,TAU,24,Color("b46c46"),2,true)
	txt("你的位置",pp+Vector2(-70,6),13,Color("a05236"))
	_sun(Vector2(1370,234),32,Color("9f8758"))
	centered("N",Vector2(1370,172),20,INK,serif)
	txt("◇ 曦光碑可休息與驛站旅行。 綠點：聚落 · 紅點：Boss · 藍方塊：補給 · 橙方塊：敵營。",Vector2(72,857),16,INK)

func _guide() -> void:
	draw_rect(Rect2(0,0,1600,900),Color(INK,0.97))
	txt("THE TRAVELER'S COMPANION",Vector2(150,112),16,GOLD,serif)
	txt("旅人的第一課",Vector2(150,169),42)
	var rows=[["W A S D","移動","滑鼠轉動第三人稱視角"],["Shift / Space","奔跑 / 翻滾","翻滾前段有無敵時間；保留體力"],["左鍵 / 右鍵","輕攻擊 / 重攻擊","輕攻擊三連段；重擊更容易破壞架勢"],["Q","鎖定 / 解除鎖定","鎖定附近敵人，法術自動瞄準"],["Tab / 1–4","切換術式 / 施放技能","三組共十二招；冷卻跨組保留"],["K / R","魔法書 / 聖露瓶","查看每招用途；高消耗法術需抓準時機"],["E / H","互動 / 呼喚與騎馬","走近 NPC、曦光碑、草藥後按 E"],["M / J / Esc","地圖 / 手記 / 選單","聯機時世界仍然運行" if game.net.online else "休息與離開時會保存進度"]]
	for i in rows.size():
		var y=232+i*63
		draw_line(Vector2(150,y+26),Vector2(1450,y+26),Color(GOLD,0.15))
		txt(rows[i][0],Vector2(150,y),20,GOLD)
		txt(rows[i][1],Vector2(400,y),21)
		txt(rows[i][2],Vector2(780,y),17,MUTED)
	txt("出發建議：先和村長交談 → 購買補給、烹飪與強化 → 騎馬探索 → 挑戰古龍。",Vector2(150,783),18,GOLD)

func _journal() -> void:
	draw_rect(Rect2(0,0,1600,900),Color(INK,0.97))
	txt("A TRAVELER'S JOURNAL",Vector2(150,112),16,GOLD,serif)
	txt("旅途手記",Vector2(150,170),43)
	panel(Rect2(150,215,610,510))
	txt("01   日冕下的古老誓約",Vector2(185,264),26,GOLD)
	var lines=["昔日的王城守護者仍守在日冕聖域。","日輪失序使祂無法辨認故友，只記得尚未完成的誓言。","村長請你解除古龍的束縛，讓商旅重返曦白城。","","◇ 與晨鐘村的村長伊蓮交談    "+("完成" if game.quest_active else "未完成"),"◇ 清除原野威脅    %d / 3" % mini(3,game.kills),"◇ 擊敗天穹古龍    "+("完成" if game.boss_defeated else "未完成"),"◇ 回報村長    "+("完成" if game.quest_rewarded else "未完成"),"","報酬：180 金幣與 3 株月露草"]
	for i in lines.size():
		txt(lines[i],Vector2(185,308+i*34),17,MUTED,null,535)
	txt("古龍觀察錄",Vector2(830,261),28)
	var tips=["迅翼二連  /  短前搖，接第二刀後再反擊。","遲暮龍爪  /  抬爪後會停頓，不要太早翻滾。","日蝕掃尾  /  快刀之後，還有一記延遲追擊。","天穹落印  /  離開金色圓圈，避免連續爆炸。","日輪震波  /  翻滾穿過擴散的光環。","星焰甦醒  /  生命 66% 甦醒星焰，30% 喚出天穹審判。","","重擊與日輪斬可累積架勢傷害。","古龍失衡時有較長的進攻窗口。","離開聖域過遠，Boss 將恢復力量。"]
	for i in tips.size():
		txt(tips[i],Vector2(830,310+i*36),18,MUTED,null,620)

	txt("旅人 Lv.%d  ·  生命 %d  ·  魔力 %d  ·  等級傷害加成 +%.1f%%"%[game.player.level,game.player.max_hp,game.player.max_mana,(game.player.damage_multiplier()-1)*100],Vector2(150,817),18,GOLD)

func button(text: String, rect: Rect2, action: Callable, primary: bool = false) -> void:
	var b=Button.new()
	b.text=Localizer.current.render(text)
	b.position=rect.position
	b.size=rect.size
	b.add_theme_font_override("font",sans)
	b.add_theme_font_size_override("font_size",mini(19,maxi(12,int(19*(rect.size.x-35)/maxf(1,sans.get_string_size(b.text,HORIZONTAL_ALIGNMENT_LEFT,-1,19).x)))))
	b.add_theme_color_override("font_color",INK if primary else PAPER)
	b.add_theme_color_override("font_hover_color",INK)
	b.add_theme_stylebox_override("normal",style(GOLD if primary else Color(INK,0.8),GOLD))
	b.add_theme_stylebox_override("hover",style(PAPER,GOLD))
	b.add_theme_stylebox_override("pressed",style(Color("b79b68"),PAPER))
	b.pressed.connect(action)
	controls.add_child(b)

func _rebuild_buttons() -> void:
	for c in controls.get_children():
		c.queue_free()
	match game.mode:
		"menu":
			button("踏入曦光之境     →",Rect2(80,546,359,59),game.start_game,true)
			button("多人聯機 · 共同世界",Rect2(80,686,359,45),func():game.character_return="network";game.set_mode("character"))
			button("旅人指南",Rect2(80,623,172,49),func(): game.guide_return="menu";game.set_mode("guide"))
			if game.has_save:
				button("繼續旅程",Rect2(267,623,172,49),game.continue_game)
		"character":
			var selectors:Array[OptionButton]=[]
			for i in 6:
				var option=OptionButton.new()
				controls.add_child(option)
				option.position=Vector2(650,240+i*68)
				option.size=Vector2(480,48)
				option.add_theme_font_override("font",sans)
				option.add_theme_font_size_override("font_size",20)
				var labels:Array=["男","女"] if i==0 else CharacterProfile.CLASSES if i==1 else []
				if i>1:
					for spell in Spellcraft.SPELLS:labels.append(spell.name)
				for label in labels:option.add_item(Localizer.current.render(label))
				option.select(game.player.profile.gender if i==0 else game.player.profile.job if i==1 else game.player.profile.skills[i-2])
				selectors.append(option)
			button("確認角色，開始冒險",Rect2(590,740,420,60),func():
				var skills:Array=[]
				for i in range(2,6):skills.append(selectors[i].selected)
				var unique={}
				for skill in skills:unique[skill]=true
				if unique.size()!=4:
					selectors[5].tooltip_text=Localizer.current.render("請選擇四種不同術式。")
					selectors[5].grab_focus()
					game.toast("技能不可重複","請選擇四種不同術式。")
					return
				game.player.apply_profile({"gender":selectors[0].selected,"job":selectors[1].selected,"skills":skills})
				game.player.restore()
				game.set_mode(game.character_return),true)
			button("返回",Rect2(70,60,160,48),func():game.set_mode("menu"))
		"network":
			var name_edit=LineEdit.new()
			var host_edit=LineEdit.new()
			var port_edit=LineEdit.new()
			for entry in [[name_edit,Rect2(535,330,600,50),game.net.nickname],[host_edit,Rect2(535,429,450,50),game.net.address],[port_edit,Rect2(1000,429,135,50),str(game.net.port)]]:
				var edit:LineEdit=entry[0]
				edit.position=entry[1].position
				edit.size=entry[1].size
				edit.text=entry[2]
				edit.add_theme_font_override("font",sans)
				edit.add_theme_font_size_override("font_size",20)
				controls.add_child(edit)
			name_edit.max_length=20
			host_edit.max_length=253
			port_edit.max_length=5
			button("加入共同世界",Rect2(535,552,600,52),func():game.net.join_world(host_edit.text,name_edit.text,int(port_edit.text)),true)
			button("在此電腦開啟世界",Rect2(535,620,290,48),func():game.net.nickname=name_edit.text.left(20);game.net.port=clampi(int(port_edit.text),1024,65535);game.net.host(true))
			button("返回／取消連線",Rect2(845,620,290,48),func():
				if game.net.connecting:game.net.leave()
				game.set_mode("menu"))
		"dialogue":
			for i in game.dialogue_options.size():
				var option=game.dialogue_options[i]
				button(option.label,Rect2(390,451+i*62,820,49),option.action,i==0)
		"pause":
			button("繼續旅程",Rect2(625,344,350,51),func():game.set_mode("play"),true)
			button("旅人指南",Rect2(625,411,350,51),func():game.guide_return="pause";game.set_mode("guide"))
			button("離開共同世界" if game.net.online else "保存並返回主選單",Rect2(625,478,350,51),game.return_menu)
			button("離開遊戲" if game.net.online else "保存並離開遊戲",Rect2(625,545,350,51),game.quit_game)
		"guide":
			button("返回",Rect2(1270,61,180,48),func():game.set_mode(game.guide_return))
		"map","journal","spellbook":
			button("返回旅途  [Esc]",Rect2(1240,60,260,49),func():game.set_mode("play"))
		"dead":
			button("於曦光碑重生",Rect2(620,540,360,59),game.respawn,true)
		"victory":
			button("繼續探索世界",Rect2(620,599,360,59),func():game.set_mode("play"),true)

	if game.mode=="map":
		button("查看起始五區" if atlas_view else "查看大陸全圖",Rect2(940,60,250,49),func():atlas_view=not atlas_view;_rebuild_buttons())
		var destination=OptionButton.new()
		controls.add_child(destination)
		destination.position=Vector2(600,798)
		destination.size=Vector2(450,43)
		destination.add_theme_font_override("font",sans)
		destination.add_theme_font_size_override("font_size",18)
		destination.add_item(Localizer.current.render("晨鐘村 · 起始領地"))
		for site in WorldAtlas.settlements:destination.add_item(Localizer.current.render(site.name+" · "+site.region))
		button("驛站旅行",Rect2(1080,798,190,43),func():
			if game.net.online:
				game.net.request("travel",destination.selected)
				game.set_mode("play")
			else:game.travel_to(destination.selected))

	if game.mode in ["menu","pause"]:
		var language=OptionButton.new()
		controls.add_child(language)
		language.name="LanguageSelector"
		language.position=Vector2(1240,55) if game.mode=="menu" else Vector2(625,612)
		language.size=Vector2(280,45) if game.mode=="menu" else Vector2(350,45)
		language.add_theme_font_override("font",sans)
		language.add_theme_font_size_override("font_size",18)
		language.add_item("語言 · 繁體中文")
		language.add_item("Language · English")
		language.select(1 if Localizer.current.locale=="en" else 0)
		language.item_selected.connect(func(index):Localizer.current.set_language("en" if index==1 else "zh_TW"))
	if game.mode=="menu":
		button("素材作者與授權",Rect2(1240,115,280,43),func():game.set_mode("credits"))
	if game.mode=="credits":
		var credits=RichTextLabel.new()
		controls.add_child(credits)
		credits.position=Vector2(100,175)
		credits.size=Vector2(1400,590)
		credits.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		credits.add_theme_font_override("normal_font",sans)
		credits.add_theme_font_size_override("normal_font_size",19)
		credits.text=FileAccess.get_file_as_string("res://THIRD_PARTY_NOTICES.md")
		button("返回",Rect2(1240,60,260,49),func():game.set_mode("menu"))
