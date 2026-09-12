class_name AureliaWorld
extends Node3D

var rng = RandomNumberGenerator.new()
var geometry: Node3D
var stream: WorldStream
var landmarks: Array[Dictionary] = []
const ARENA = Vector3(0, 0, -310)
const ROUTES = [[Vector3(0,0,40),Vector3(0,0,-310)],[Vector3(0,0,0),Vector3(145,0,-20)],[Vector3(0,0,-75),Vector3(-135,0,-95)],[Vector3(0,0,-180),Vector3(110,0,-200)]]
const REGIONS = [
	{"name":"晨鐘平原", "center":Vector3(0,0,20), "detail":"晨鐘村 · 農莊 · 商旅營地"},
	{"name":"鏡露森林", "center":Vector3(145,0,-20), "detail":"湖畔林地 · 史萊姆 · 古樹遺跡"},
	{"name":"曦白王城", "center":Vector3(-135,0,-95), "detail":"王城 · 衛隊 · 石造迴廊"},
	{"name":"霜冠高地", "center":Vector3(110,0,-200), "detail":"危險區域 · 骸骨軍團 · 雪峰"},
	{"name":"日冕聖域", "center":ARENA, "detail":"最終 Boss · 天穹古龍"}
]

func build() -> void:
	rng.seed=872413
	geometry=Node3D.new()
	geometry.name="Architecture"
	add_child(geometry)
	_environment()
	_terrain()
	_settlements()
	_wilderness()
	for region in REGIONS:
		landmarks.append(region)
	Art.batch_static(geometry)
	stream=WorldStream.new()
	add_child(stream)
	stream.configure()

func region_at(p: Vector3) -> Dictionary:
	if absf(p.x)>250 or p.z<-390 or p.z>120:return WorldAtlas.region_at(p)
	var best=REGIONS[0]
	var distance=INF
	for region in REGIONS:
		var d=Vector2(p.x,p.z).distance_squared_to(Vector2(region.center.x,region.center.z))
		if d<distance:
			distance=d
			best=region
	return best

func ground_height(_x: float, _z: float) -> float:
	return 0.0

func put(key: String, x: float, z: float, height: float, yaw: float = 0, solid: bool = false) -> Node3D:
	return PublicAssets.place(geometry,key,Vector3(x,0,z),height,yaw,solid)

func _terrain() -> void:
	# Navigation surface and collision are infrastructure; visible dressing is authored asset art.
	var st=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(-240,240,8):
		for z in range(-390,110,8):
			for p in [Vector2(x,z),Vector2(x+8,z),Vector2(x,z+8),Vector2(x+8,z),Vector2(x+8,z+8),Vector2(x,z+8)]:
				var snow=smoothstep(-135,-220,p.y)*smoothstep(-30,50,p.x)
				var c=Color("799752").lerp(Color("8dac61"),(sin(p.x*.04)*cos(p.y*.06)+1)*.3)
				st.set_uv(p/3.0)
				st.set_color(c.lerp(Color("d4e4e3"),snow))
				st.add_vertex(Vector3(p.x,-.04,p.y))
	st.generate_normals()
	st.generate_tangents()
	var terrain=MeshInstance3D.new()
	terrain.mesh=st.commit()
	var mat=ShaderMaterial.new()
	mat.shader=load("res://shaders/public_terrain.gdshader")
	mat.set_shader_parameter("ground_texture",load("res://assets/vendor/terrain/diff.jpg"))
	mat.set_shader_parameter("ground_normal",load("res://assets/vendor/terrain/nor_gl.jpg"))
	terrain.material_override=mat
	geometry.add_child(terrain)
	terrain.create_trimesh_collision()
	# Authored road tiles connect every region; no teleport required.
	for pair in ROUTES:
		var count=ceili(pair[0].distance_to(pair[1])/5.0)
		for i in count+1:
			var p:Vector3=pair[0].lerp(pair[1],float(i)/count)
			var tile=put("dungeon-remastered/floor_dirt_large",p.x,p.z,.12)
			tile.scale.x=1.8
			tile.scale.z=1.8

func _settlements() -> void:
	var houses=[[-16,21,"home_A"],[-17,2,"tavern"],[17,8,"blacksmith"],[18,25,"market"],[-21,-19,"church"],[30,42,"lumbermill"],[-39,39,"windmill"],[43,49,"home_B"],[-44,3,"home_B"],[31,-20,"archeryrange"]]
	for h in houses:
		put("medieval-hexagon-pack/building_"+h[2]+"_blue",h[0],h[1],9 if h[2]!="church" else 16,0,true)
	put("medieval-hexagon-pack/building_well_blue",0,12,2.2)
	# Market and work stations have authored food, furniture and tools.
	var props=["table_long_tablecloth_decorated_A","barrel_small_stack","crates_stacked","keg_decorated","table_medium_tablecloth_decorated_B","shelf_small","plate_food_A","chair","stool","bottle_A_brown"]
	for i in props.size():
		put("dungeon-remastered/"+props[i],-10+i%5*5,39+floori(i/5.0)*4,1.0 if i!=6 else .28)
	for r in [1,2,3]:
		var center:Vector3=REGIONS[r].center
		if r==3:
			for i in 12:
				var a=i*TAU/12
				put("dungeon-remastered/wall_cracked" if i%3 else "dungeon-remastered/wall_arched",center.x+cos(a)*37,center.z-25+sin(a)*25,6,-a+PI/2)
			put("medieval-hexagon-pack/building_mine_red",center.x,center.z-40,12)
		for i in (3 if r==3 else 5 if r==1 else 7):
			var a=i*TAU/7
			var type=["home_A","tavern","market","blacksmith","lumbermill","barracks","church"][i]
			put("medieval-hexagon-pack/building_"+type+"_"+["blue","green","yellow","red"][r],center.x+cos(a)*29,center.z+sin(a)*29,8+float(i%3)*2,a,true)
		put("medieval-hexagon-pack/building_well_blue",center.x+5,center.z+5,2.4)
	var dressing=["bucket_water","wheelbarrow","crate_long_A","crate_open","resource_lumber","resource_stone","sack","barrel","flag_blue","flag_green","flag_yellow","flag_red","target","tent","ladder","pallet","bucket_empty","weaponrack"]
	for r in range(4):
		var c:Vector3=REGIONS[r].center
		for i in dressing.size():
			var a=i*TAU/dressing.size()
			put("medieval-hexagon-pack/"+dressing[i],c.x+cos(a)*22,c.z+sin(a)*22,1.3 if i<8 else 2.3,a)
	# Monumental castle stays outside the walkable central plaza.
	put("medieval-hexagon-pack/building_castle_yellow",-135,-144,35,0,true)
	for x in [-170,-100]:
		put("medieval-hexagon-pack/building_tower_A_yellow",x,-121,18,0,true)
	# Authored ruin modules frame the open final arena without obstructing combat.
	for i in 24:
		var a=i*TAU/24
		put("dungeon-remastered/pillar",ARENA.x+cos(a)*25,ARENA.z+sin(a)*25,7)
		if i%3!=0:put("dungeon-remastered/wall_arched",cos(a)*29,ARENA.z+sin(a)*29,9,-a+PI/2)
	for i in 8:
		put("dungeon-remastered/banner_patternB_yellow",-23 if i%2==0 else 23,ARENA.z-18+floori(i/2.0)*12,5)
	put("medieval-hexagon-pack/building_church_yellow",0,-357,34,0,true)
	for i in 28:
		put("dungeon-remastered/"+["rubble_large","trunk_large_B","barrel_small","weaponrack","crates_stacked" ][i%5] if i%5!=3 else "medieval-hexagon-pack/weaponrack",-145+(i%7)*5,-72+floori(i/7.0)*5,1.0)

func _wilderness() -> void:
	for i in 650:
		var x=rng.randf_range(-225,225)
		var z=rng.randf_range(-375,96)
		if absf(x)<12:continue
		var near_town=false
		for region in REGIONS:
			if Vector2(x,z).distance_to(Vector2(region.center.x,region.center.z))<43:near_town=true
		if near_town or absf(z+75+x*.148)<9 or absf(z+x*.138)<9 or absf(z+180+x*.18)<9:continue
		var snow=z<-150 and x>25
		var key="rock_single_"+["A","B","C","D","E"][i%5] if snow or i%5==0 else "tree_single_"+["A","B"][i%2]
		put("medieval-hexagon-pack/"+key,x,z,rng.randf_range(.7,2.4) if snow or i%5==0 else rng.randf_range(5,11),rng.randf()*TAU,i%8==0)
	for i in 130:
		var x=rng.randf_range(70,230)
		var z=rng.randf_range(-110,85)
		if Vector2(x-145,z+20).length()<43 or absf(z+x*.138)<8 or (x>175 and z>0):continue
		put("medieval-hexagon-pack/trees_"+["A","B"][i%2]+"_medium",x,z,rng.randf_range(7,12),rng.randf()*TAU)
	# Lake uses existing authored water tiles and aquatic plants.
	for x in 5:
		for z in 4:
			var water=put("medieval-hexagon-pack/hex_water",181+x*7,12+z*7,.55)
			water.scale.x=5
			water.scale.z=5
	for i in 22:
		put("medieval-hexagon-pack/waterplant_"+["A","B","C"][i%3],179+i%7*5,8+floori(i/7.0)*10,1)

func _environment() -> void:
	var env = WorldEnvironment.new()
	var e = Environment.new()
	var sky = Sky.new()
	var sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("5d93a6")
	sky_mat.sky_horizon_color = Color("d7e3d2")
	sky_mat.ground_horizon_color = Color("d8dfce")
	sky_mat.ground_bottom_color = Color("647d65")
	sky_mat.sky_curve = 0.18
	sky_mat.sun_angle_max = 12.0
	sky.sky_material = sky_mat
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("bed6ce")
	e.ambient_light_energy = 0.38
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.ssao_enabled = true
	e.ssao_radius = 1.8
	e.ssao_intensity = 1.15
	e.glow_enabled = true
	e.glow_intensity = 0.45
	e.fog_enabled = true
	e.fog_light_color = Color("bbcfc1")
	e.fog_density = 0.0008
	e.fog_sky_affect = 0.24
	e.fog_depth_begin = 180.0
	e.fog_depth_end = 550.0
	env.environment = e
	add_child(env)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-43, -32, 0)
	sun.light_color = Color("fff1ce")
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 110
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	add_child(sun)
