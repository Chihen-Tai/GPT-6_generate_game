class_name WorldStream
extends Node3D

var chunks: Dictionary={}
var desired: Dictionary={}
var terrain_material: ShaderMaterial
var generation=0
var visual_enabled=true
var structures: Dictionary={}

func configure() -> void:
	WorldAtlas.initialize()
	visual_enabled=DisplayServer.get_name()!="headless"
	terrain_material=ShaderMaterial.new()
	terrain_material.shader=load("res://shaders/public_terrain.gdshader")
	terrain_material.set_shader_parameter("ground_texture",load("res://assets/vendor/terrain/diff.jpg"))
	terrain_material.set_shader_parameter("ground_normal",load("res://assets/vendor/terrain/nor_gl.jpg"))
	for site in WorldAtlas.settlements+WorldAtlas.dungeons+WorldAtlas.camps:
		var k=WorldAtlas.key(site.center)
		if not structures.has(k):structures[k]=[]
		structures[k].append(site)
	for x in [-WorldAtlas.HALF_SIZE,WorldAtlas.HALF_SIZE]:Art.body_box(self,Vector3(x,50,0),Vector3(2,150,WorldAtlas.HALF_SIZE*2))
	for z in [-WorldAtlas.HALF_SIZE,WorldAtlas.HALF_SIZE]:Art.body_box(self,Vector3(0,50,z),Vector3(WorldAtlas.HALF_SIZE*2,150,2))
	if visual_enabled:
		var horizon=MeshInstance3D.new()
		add_child(horizon)
		var plane=PlaneMesh.new()
		plane.size=Vector2.ONE*WorldAtlas.HALF_SIZE*2
		horizon.mesh=plane
		horizon.position.y=-.11
		var material=terrain_material.duplicate()
		material.shader=load("res://shaders/continental_terrain.gdshader")
		horizon.material_override=material
	update_centers([Vector3.ZERO],true)

func update_centers(points: Array, immediate: bool = false) -> void:
	desired.clear()
	for p in points:
		var key=WorldAtlas.key(p)
		for dx in range(-1,2):
			for dz in range(-1,2):
				var k=key+Vector2i(dx,dz)
				if k.x>=0 and k.x<WorldAtlas.CHUNK_COUNT and k.y>=0 and k.y<WorldAtlas.CHUNK_COUNT:desired[k]=true
	for k in chunks.keys():
		if not desired.has(k):
			chunks[k].queue_free()
			chunks.erase(k)
	if immediate:
		for k in desired:
			if not chunks.has(k):_build(k)

func _process(_delta: float) -> void:
	# One patch per frame bounds the work while the outer ring preloads ahead.
	for k in desired:
		if not chunks.has(k):
			_build(k)
			break

func _build(key: Vector2i) -> void:
	var chunk=Node3D.new()
	chunk.name="Patch_%d_%d"%[key.x,key.y]
	add_child(chunk)
	chunks[key]=chunk
	generation+=1
	var size=WorldAtlas.CHUNK_SIZE
	var start=Vector3(key.x*size-WorldAtlas.HALF_SIZE,0,key.y*size-WorldAtlas.HALF_SIZE)
	var mesh=PlaneMesh.new()
	mesh.size=Vector2.ONE*size
	mesh.subdivide_width=8
	mesh.subdivide_depth=8
	if visual_enabled:
		var surface=MeshInstance3D.new()
		chunk.add_child(surface)
		surface.position=start+Vector3(size/2,-.075,size/2)
		surface.mesh=mesh
		var m=terrain_material.duplicate()
		# World UVs and biomes stay continuous across chunk boundaries.
		m.shader=load("res://shaders/continental_terrain.gdshader")
		surface.material_override=m
	Art.body_box(chunk,start+Vector3(size/2,-.6,size/2),Vector3(size,1,size))
	# A structure spanning a boundary is owned by its centre chunk; collision streams with it.
	for site in structures.get(key,[]):
		if site.has("hostile"):_camp(chunk,site)
		elif site.has("boss"):_dungeon(chunk,site)
		else:_settlement(chunk,site)
	if visual_enabled:
		var rng=RandomNumberGenerator.new()
		rng.seed=key.x*7817+key.y*1973+427
		for i in 150:
			var p=start+Vector3(rng.randf()*size,0,rng.randf()*size)
			if absf(p.x)<245 and p.z>-390 and p.z<120:continue
			if _near_site(p,12) or _road_distance(p)<10:continue
			var tree=i%4!=0
			var asset="medieval-hexagon-pack/tree_single_"+("A" if i%2 else "B") if tree else "medieval-hexagon-pack/rock_single_C"
			var height=rng.randf_range(6,14) if tree else rng.randf_range(1,3)
			PublicAssets.place(chunk,asset,p,height,rng.randf()*TAU)
		_roads(chunk,start)
		Art.batch_static(chunk)

func _near_site(p: Vector3, distance: float) -> bool:
	for s in WorldAtlas.settlements+WorldAtlas.dungeons+WorldAtlas.camps:
		var clearance=30.0 if s.has("hostile") else WorldAtlas.footprint(s)
		if Vector2(p.x-s.center.x,p.z-s.center.z).length_squared()<pow(distance+clearance,2):return true
	return false

func _road_distance(p: Vector3) -> float:
	var best=INF
	var q=Vector2(p.x,p.z)
	for segment in WorldAtlas.roads:
		var a=Vector2(segment[0].x,segment[0].z)
		var b=Vector2(segment[1].x,segment[1].z)
		var t=clampf((q-a).dot(b-a)/(b-a).length_squared(),0,1)
		best=minf(best,q.distance_to(a.lerp(b,t)))
	return best

func _roads(chunk: Node3D, start: Vector3) -> void:
	for x in range(0,int(WorldAtlas.CHUNK_SIZE),8):
		for z in range(0,int(WorldAtlas.CHUNK_SIZE),8):
			var p=start+Vector3(x+4,0,z+4)
			if absf(p.x)<245 and p.z>-390 and p.z<120:continue
			if _road_distance(p)<6.0:
				_tile(chunk,"floor_dirt_large",p,.13,Vector2(8.1,8.1))

func _piece(parent: Node3D, asset: String, p: Vector3, height: float, solid: bool = false, yaw: float = 0) -> void:
	if visual_enabled:PublicAssets.place(parent,asset,p,height,yaw,false)
	if solid:Art.body_box(parent,p+Vector3(0,height*.4,0),Vector3(height*.8,height*.8,height*.7))

func _settlement(chunk: Node3D, site: Dictionary) -> void:
	var center:Vector3=site.center
	var count=24 if site.type=="town" else 10 if site.type=="village" else 5
	var colors=["blue","green","yellow","red"]
	for i in count:
		var row=floori(float(i)/8)
		var a=(i%8)*TAU/8+PI/8
		var p=center+Vector3(cos(a)*(26+row*18),0,sin(a)*(26+row*18))
		if _road_distance(p)<12:continue
		var building=["home_A","home_B","market","tavern","blacksmith","lumbermill","windmill","church"][i%8]
		if i%4!=3:_village_house(chunk,p,-a,i)
		else:
			_piece(chunk,"medieval-hexagon-pack/building_"+building+"_"+colors[(i+int(absf(center.x)/1000))%4],p,10 if building!="church" else 17,true,-a)
		_piece(chunk,"medieval-hexagon-pack/"+["barrel","crate_open","wheelbarrow","sack"][i%4],p+Vector3(7,0,3),1.2)
	# Furnish the plaza with existing market props and trees between the approach lanes.
	for i in 8:
		var angle=i*TAU/8+PI/8
		var p=center+Vector3(cos(angle)*15,0,sin(angle)*15)
		if _road_distance(p)<7:continue
		_piece(chunk,"medieval-hexagon-pack/"+["crate_open","barrel","sack","wheelbarrow"][i%4],p,1.2)
	for i in 16:
		var angle=i*TAU/16
		var p=center+Vector3(cos(angle)*105,0,sin(angle)*105)
		if site.type!="town" or _road_distance(p)<10 or p.distance_to(center+Vector3(75,0,-60))<25:continue
		_piece(chunk,"medieval-hexagon-pack/tree_single_A",p,7)
	_piece(chunk,"medieval-hexagon-pack/building_well_blue",center+Vector3(7,0,-7),2.8)
	_piece(chunk,"dungeon-remastered/column",center+Vector3(0,0,15),1.8)
	if site.type=="town":_piece(chunk,"detailed/modular_fort_01",center+Vector3(75,0,-60),16)

func _camp(chunk: Node3D, site: Dictionary) -> void:
	var p:Vector3=site.center
	_piece(chunk,"medieval-hexagon-pack/tent" if not site.hostile else "dungeon-remastered/wall_cracked",p+Vector3(0,0,-7),3.8)
	_piece(chunk,"medieval-hexagon-pack/weaponrack" if site.hostile else "medieval-hexagon-pack/wheelbarrow",p+Vector3(-5,0,-3),1.7)
	for i in 3:
		_piece(chunk,"dungeon-remastered/crates_stacked" if i==0 else "medieval-hexagon-pack/barrel",p+Vector3(5+i*1.5,0,-4),1.1)

func _dungeon(chunk: Node3D, site: Dictionary) -> void:
	var c:Vector3=site.center
	# A traversable entry corridor leads through an antechamber into an enclosed boss room.
	for x in range(-24,25,8):
		for z in range(-24,25,8):
			if visual_enabled:_tile(chunk,"floor_tile_large",c+Vector3(x,.05,z),.18,Vector2(8.05,8.05))
	for x in [-4,4]:
		for z in range(32,69,8):
			if visual_enabled:_tile(chunk,"floor_tile_large",c+Vector3(x,.05,z),.18,Vector2(8.05,8.05))
	for side in [-1,1]:
		for z in range(-28,37,8):
			_piece(chunk,"dungeon-remastered/wall_cracked" if site.type==3 else "dungeon-remastered/wall_arched",c+Vector3(side*28,0,z),8,false,PI/2)
			Art.body_box(chunk,c+Vector3(side*29,4,z),Vector3(2,8,8))
		for z in range(36,69,8):
			_piece(chunk,"dungeon-remastered/wall_arched",c+Vector3(side*8,0,z),7,false,PI/2)
			Art.body_box(chunk,c+Vector3(side*9,3.5,z),Vector3(2,7,8))
	for x in range(-24,25,8):
		_piece(chunk,"dungeon-remastered/wall_arched",c+Vector3(x,0,-28),8)
		Art.body_box(chunk,c+Vector3(x,4,-29),Vector3(8,8,2))
	for x in [-20,-12,12,20]:
		_piece(chunk,"dungeon-remastered/wall_arched",c+Vector3(x,0,32),8)
		Art.body_box(chunk,c+Vector3(x,4,33),Vector3(8,8,2))
	for z in range(36,69,8):
		Art.body_box(chunk,c+Vector3(0,7.4,z),Vector3(18,.5,8))
		if visual_enabled:
			_tile(chunk,"floor_tile_large",c+Vector3(0,7,z),.5,Vector2(18.1,8.1),true)
	if visual_enabled:
		for i in 12:
			_piece(chunk,"dungeon-remastered/"+["pillar","barrel_small_stack","rubble_large","candle_triple"][i%4],c+Vector3(-22 if i%2 else 22,0,-18+floori(i/2.0)*8),3 if i%4==0 else 1.2)
		var light=OmniLight3D.new()
		chunk.add_child(light);light.position=c+Vector3(0,5,5)
		light.omni_range=34;light.light_color=Color("ffcf91");light.light_energy=1.2

func _village_house(chunk: Node3D, p: Vector3, yaw: float, variant: int) -> void:
	var root=Node3D.new()
	chunk.add_child(root)
	root.position=p
	root.rotation.y=yaw
	root.scale=Vector3.ONE*1.55
	Art.body_box(root,Vector3(0,1.5,0),Vector3(4,3,6))
	if not visual_enabled:return
	var wall="Wall_Plaster_Straight" if variant%2==0 else "Wall_UnevenBrick_Straight"
	for side in [-1,1]:
		for x in [-1,1]:
			_module(root,"Wall_Plaster_Door_Round" if side==1 and x==-1 else wall,Vector3(x,0,side*3),PI if side==-1 else 0)
		for z in [-2,0,2]:
			_module(root,"Wall_Plaster_Window_Thin_Round",Vector3(side*2,0,z),side*PI/2)
			_module(root,"Window_Thin_Round1",Vector3(side*2,0,z),side*PI/2)
	_module(root,"Door_2_Round" if variant%2 else "Door_4_Round",Vector3(-1,0,3.02))
	_module(root,"DoorFrame_Round_WoodDark",Vector3(-1,0,3.02))
	_module(root,"Roof_RoundTiles_4x6",Vector3(0,3.12,0))
	_module(root,"Roof_Front_Brick4",Vector3(0,3.12,3))
	_module(root,"Roof_Front_Brick4",Vector3(0,3.12,-3),PI)
	_module(root,"Prop_Vine2",Vector3(2.05,0,-2),PI/2)
	for i in 3:_module(root,"Prop_WoodenFence_Single",Vector3(-2+i*2,0,5))

func _module(parent: Node3D, key: String, p: Vector3, yaw: float=0) -> void:
	var part=PublicAssets.instantiate(parent,"medieval-village/"+key)
	part.position=p
	part.rotation.y=yaw
	Art.limit_visibility(part,180)

func _tile(parent:Node3D, key:String, p:Vector3, height:float, size:Vector2, double_sided:bool=false) -> void:
	var tile=PublicAssets.place(parent,"dungeon-remastered/"+key,p,height)
	var bounds:AABB=PublicAssets.bounds["dungeon-remastered/"+key]
	var factor=height/bounds.size.y
	tile.scale.x=size.x/(bounds.size.x*factor)
	tile.scale.z=size.y/(bounds.size.z*factor)
	if double_sided:_ceiling_material(tile)

func _ceiling_material(root:Node) -> void:
	if root is MeshInstance3D:
		for surface in root.mesh.get_surface_count():
			var source=root.get_active_material(surface)
			if source is StandardMaterial3D:
				var material=source.duplicate()
				material.cull_mode=BaseMaterial3D.CULL_DISABLED
				root.set_surface_override_material(surface,material)
	for child in root.get_children():_ceiling_material(child)
