class_name Localizer
extends Node

static var current:Localizer

signal changed
const SETTINGS_PATH="user://preferences.cfg"
var locale="zh_TW"
var settings_path=SETTINGS_PATH
var catalog:Dictionary={}
var cache:Dictionary={}
var literals=RegEx.new()
var formats:Array[Dictionary]=[]
var formatter=RegEx.new()

func _ready() -> void:
	current=self
	catalog=JSON.parse_string(FileAccess.get_file_as_string("res://translations/en.json"))
	formatter.compile("%[-+0-9.]*[dsf]|%%")
	var keys:Array=catalog.keys()
	keys.sort_custom(func(a,b):return a.length()>b.length())
	var escaped:PackedStringArray=[]
	for key:String in keys:
		var tokens=formatter.search_all(key)
		if tokens.is_empty():
			escaped.append(escape(key))
			continue
		var pattern=""
		var cursor=0
		var count=0
		for token in tokens:
			pattern+=escape(key.substr(cursor,token.get_start()-cursor))
			pattern+="%" if token.get_string()=="%%" else "([-+]?[0-9]+(?:\\.[0-9]+)?)" if token.get_string().ends_with("f") else "([-+]?[0-9]+)" if token.get_string().ends_with("d") else "(.+?)"
			if token.get_string()!="%%":count+=1
			cursor=token.get_end()
		pattern+=escape(key.substr(cursor))
		var regex=RegEx.new()
		regex.compile("^"+pattern+"$" if key.begins_with("%") else pattern)
		formats.append({"regex":regex,"english":catalog[key],"count":count})
	literals.compile("|".join(escaped))
	load_preferences()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--language="):set_language(argument.trim_prefix("--language="),false)

func load_preferences() -> void:
	var config=ConfigFile.new()
	if config.load(settings_path)==OK:set_language(str(config.get_value("interface","language","zh_TW")),false)

func escape(value:String) -> String:
	var result=""
	for c in value:
		if c in "\\.^$|?*+()[]{}":result+="\\"
		result+=c
	return result

func render(source:String) -> String:
	if locale!="en" or source.is_empty():return source
	if catalog.has(source):return catalog[source]
	if cache.has(source):return cache[source]
	var output=source
	for entry in formats:
		var match_=entry.regex.search(source)
		if match_==null:continue
		var cursor=0
		var index=1
		output=source.substr(0,match_.get_start())
		for token in formatter.search_all(entry.english):
			output+=entry.english.substr(cursor,token.get_start()-cursor)
			if token.get_string()=="%%":output+="%"
			else:
				output+=match_.get_string(index)
				index+=1
			cursor=token.get_end()
		output+=entry.english.substr(cursor)+source.substr(match_.get_end())
		break
	# Composed place names, labels and dialog status fragments use the same catalog.
	var translated=""
	var cursor=0
	for match_ in literals.search_all(output):
		var gap=output.substr(cursor,match_.get_start()-cursor)
		var replacement:String=catalog[match_.get_string()]
		if gap.is_empty() and not translated.is_empty() and translated.right(1).to_lower() in "abcdefghijklmnopqrstuvwxyz" and replacement.left(1).to_lower() in "abcdefghijklmnopqrstuvwxyz":translated+=" "
		translated+=gap+replacement
		cursor=match_.get_end()
	translated+=output.substr(cursor)
	if cache.size()>=2048:cache.clear()
	cache[source]=translated
	return translated

func set_language(value:String, persist:bool=true) -> void:
	if value not in ["zh_TW","en"]:return
	locale=value
	cache.clear()
	TranslationServer.set_locale(value)
	if persist:
		var config=ConfigFile.new()
		config.load(settings_path)
		config.set_value("interface","language",locale)
		config.save(settings_path)
	for label in get_tree().get_nodes_in_group("localized_labels"):
		label.text=render(label.get_meta("source_text"))
	changed.emit()

func bind_label(label:Label3D, source:String) -> void:
	label.set_meta("source_text",source)
	label.add_to_group("localized_labels")
	label.text=render(source)
