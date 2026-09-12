class_name PublicAssets
extends RefCounted

static var catalog: Dictionary = {}
static var scenes: Dictionary = {}
static var bounds: Dictionary = {}
static var used: Dictionary = {}

static func path(key: String) -> String:
	if catalog.is_empty():
		catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/vendor/catalog.json"))
	if key.begins_with("ultimate-monsters/"):return "res://assets/vendor/"+key+".gltf"
	if key.begins_with("medieval-village/"):return "res://assets/vendor/medieval-village/glTF/"+key.get_file()+".gltf"
	if key.begins_with("detailed/"):return "res://assets/vendor/"+key+"/"+key.get_file()+".gltf"
	if key.begins_with("monsters/") or key.begins_with("animals/"):return "res://assets/vendor/"+key+".glb"
	assert(catalog.has(key),"Unknown public asset: "+key)
	return catalog[key].path

static func instantiate(parent: Node3D, key: String) -> Node3D:
	if not scenes.has(key):scenes[key]=load(path(key))
	var node:Node3D=scenes[key].instantiate()
	parent.add_child(node)
	used[key]=int(used.get(key,0))+1
	return node

static func measure(node: Node3D, transform: Transform3D = Transform3D.IDENTITY) -> AABB:
	var box=AABB()
	var t=transform*node.transform
	if node is MeshInstance3D and node.mesh:box=t*node.get_aabb()
	for child in node.get_children():
		if child is Node3D:
			var b=measure(child,t)
			if b.size.length()>0:box=b if box.size.length()==0 else box.merge(b)
	return box

static func place(parent: Node3D, key: String, position: Vector3, height: float, yaw: float = 0.0, solid: bool = false) -> Node3D:
	var pivot=Node3D.new()
	parent.add_child(pivot)
	var node=instantiate(pivot,key)
	if not bounds.has(key):bounds[key]=measure(node)
	var box:AABB=bounds[key]
	var factor=height/maxf(0.01,box.size.y)
	node.scale*=factor
	node.position-=Vector3(box.get_center().x,box.position.y,box.get_center().z)*factor
	pivot.position=position
	pivot.rotation.y=yaw
	if solid:
		# Conservative building footprint leaves streets and entrances usable.
		Art.body_box(pivot,Vector3(0,height*0.45,0),Vector3(box.size.x*factor*0.82,height*0.9,box.size.z*factor*0.82))
	Art.limit_visibility(pivot,220 if height>8 else 110)
	return pivot
