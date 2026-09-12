extends SceneTree
func _initialize() -> void:
	var world=Node.new()
	world.name="Aurelia"
	root.add_child(world)
	var realm=load("res://tests/capacity_peer.gd").new()
	realm.name="Realm"
	world.add_child(realm)
