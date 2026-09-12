extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var g=load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await process_frame
	await load("res://tests/continental.gd").new().run(g)
