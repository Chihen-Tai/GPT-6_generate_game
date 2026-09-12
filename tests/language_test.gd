extends SceneTree
var passed=0
var failed=0
var lang:Node
func _initialize() -> void:call_deferred("run")
func check(ok:bool,message:String) -> void:
	if ok:passed+=1
	else:failed+=1;push_error(message)
func run() -> void:
	lang=root.get_node("Language")
	lang.settings_path="user://language-test.cfg"
	lang.set_language("en",false)
	var chinese=RegEx.new()
	chinese.compile("[\\x{3400}-\\x{9fff}]")
	var token=RegEx.new()
	token.compile("%[-+0-9.]*[dsf]|%%")
	for key:String in lang.catalog:
		check(chinese.search(lang.render(key))==null,"Missing exact translation: "+key)
		var rendered=key
		if token.search(key):
			var values:Array=[]
			for match_ in token.search_all(key):
				if match_.get_string()=="%%":continue
				values.append("魔劍士" if match_.get_string().ends_with("s") else 12.5 if match_.get_string().ends_with("f") else 12)
			rendered=key%values
			check(chinese.search(lang.render(rendered))==null,"Missing formatted translation: "+rendered)
	check(lang.render("+180 EXP · 升至 Lv.12，生命、魔力與傷害提升")=="+180 EXP · Reached Lv.12: health, mana and damage increased","Level-up feedback preserves numbers")
	check(lang.render("晨露東鄉行商")=="Morningdew East Hamlet Merchant","Composed English names keep word boundaries")
	WorldAtlas.initialize()
	for site in WorldAtlas.settlements+WorldAtlas.dungeons:check(chinese.search(lang.render(site.name))==null,"Generated place name: "+site.name)
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.test_mode=true
	var p=game.player.position
	game.hud._rebuild_buttons()
	check(game.hud.controls.has_node("LanguageSelector"),"Language selector appears on title screen")
	for label in get_nodes_in_group("localized_labels"):check(chinese.search(label.text)==null,"Untranslated world label: "+label.text)
	game.hud.controls.get_node("LanguageSelector").item_selected.emit(0)
	await process_frame
	check(lang.locale=="zh_TW","Title dropdown changes the actual locale")
	lang.set_language("en",false)
	for path_ in ["res://THIRD_PARTY_NOTICES.md","res://LICENSE","res://licenses/CC0-1.0.txt","res://licenses/Noto-COPYRIGHT.txt","res://licenses/Godot-COPYRIGHT.txt"]:
		check(FileAccess.file_exists(path_) and FileAccess.get_file_as_string(path_).length()>30,"Pack contains license notice: "+path_)
	game.set_mode("credits")
	await process_frame
	var found_credits=false
	for control in game.hud.controls.get_children():
		if control is RichTextLabel:found_credits=control.text.contains("Kay Lousberg") and control.text.contains("Rico Cilliers") and control.text.contains("Adobe")
	check(found_credits,"Credits view identifies original artists and font author")
	var raw=Art.label3d(game,"霜矢",Vector3.ZERO,Color.WHITE,22,false)
	lang.set_language("zh_TW",false)
	var labels_restored=true
	for label in get_nodes_in_group("localized_labels"):
		if label.text!=label.get_meta("source_text"):labels_restored=false
	check(labels_restored,"Chinese switch restores existing world labels")
	check(lang.render("日輪斬")=="日輪斬","Chinese text unchanged")
	check(game.player.position==p,"Language change does not reset game state")
	check(raw.text=="霜矢","Player names are not translated")
	lang.set_language("en",false)
	check(raw.text=="霜矢","Player names survive locale changes")
	check(game.player.profile.job==0,"Language does not change class")
	var path="user://language-test.cfg"
	lang.settings_path=path
	lang.set_language("en",true)
	lang.set_language("zh_TW",false)
	lang.load_preferences()
	check(lang.locale=="en","Saved locale reloads through the actual preference service")
	lang.set_language("unsupported",false)
	check(lang.locale=="en","Unsupported locale leaves the preference unchanged")
	lang.settings_path=lang.SETTINGS_PATH

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("LANGUAGE RESULT: %d passed, %d failed"%[passed,failed])
	quit(0 if failed==0 else 1)
