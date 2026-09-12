class_name Art
extends RefCounted

# Shared primitives are instanced into material batches by the world builder.
static var materials: Dictionary = {}
static var meshes: Dictionary = {}
static var surface_grain: NoiseTexture2D
static var surface_normal: NoiseTexture2D
static var packed_models: Dictionary = {}
static var neutral_cloth: ImageTexture
static var toon_materials: Dictionary = {}
static var label_font: SystemFont

static func toon(root: Node) -> void:
	# VRoid facial transparency and authored texture layers must stay intact.
	if root is AnimatedCharacter:return
	if root is MeshInstance3D:
		for surface in root.mesh.get_surface_count():
			var source=root.get_active_material(surface)
			if not source is StandardMaterial3D:
				continue
			var key=source.get_instance_id()
			if not toon_materials.has(key):
				var shaded=ShaderMaterial.new()
				shaded.shader=load("res://shaders/anime.gdshader")
				shaded.set_shader_parameter("base_color",source.albedo_color)
				shaded.set_shader_parameter("textured",source.albedo_texture!=null)
				if source.albedo_texture:
					shaded.set_shader_parameter("color_texture",source.albedo_texture)
				shaded.set_shader_parameter("metal_glint",source.metallic)
				var face="anime_skin" in source.resource_name
				shaded.set_shader_parameter("face_material",face)
				if not ("anime_iris" in source.resource_name or "anime_white" in source.resource_name or "anime_ink" in source.resource_name or "anime_lip" in source.resource_name or "anime_blush" in source.resource_name or "anime_skin_detail" in source.resource_name):
					var outline=ShaderMaterial.new()
					outline.shader=load("res://shaders/anime_outline.gdshader")
					outline.set_shader_parameter("thickness",0.0012 if face else 0.0025)
					shaded.next_pass=outline
				toon_materials[key]=shaded
			root.set_surface_override_material(surface,toon_materials[key])
	for child in root.get_children():
		toon(child)

static func field_enemy(parent: Node3D, cloth: Color) -> Node3D:
	var detailed=imported_rig(parent,"field_enemy","Rig")
	if not detailed:
		return knight(parent,cloth)
	recolor(detailed,"teal_cloth",cloth)
	toon(detailed)
	return detailed
const STONE = Color("d5c8aa")
const STONE_DARK = Color("a3947d")
const WOOD = Color("614c3b")
const GOLD = Color("d6b46c")
const TEAL = Color("285958")
const ROOF = Color("456b6c")
const IVORY = Color("f0e4c9")

static func model(parent: Node3D, asset: String) -> Node3D:
	var path="res://assets/models/"+asset+".glb"
	if not packed_models.has(asset):
		if not ResourceLoader.exists(path):
			return null
		packed_models[asset]=load(path)
	var instance:Node3D=packed_models[asset].instantiate()
	parent.add_child(instance)
	return instance

static func character(parent: Node3D, asset: String) -> AnimatedCharacter:
	var rig=AnimatedCharacter.new()
	parent.add_child(rig)
	rig.configure(asset)
	return rig

static func socket(rig: Node3D, part: String) -> Node3D:
	return rig.socket(part) if rig is AnimatedCharacter else rig.get_node(part)

static func citizen(parent: Node3D, role: String, index: int) -> AnimatedCharacter:
	var asset="citizen_rigged"
	if role in ["cook","baker","herbalist"]:asset="vivi_rigged"
	elif role in ["elder","mage","scholar"]:asset="victoria_rigged"
	elif role=="guard":asset="hero_rigged"
	var rig=character(parent,asset)
	if asset=="vivi_rigged":rig.scale=Vector3.ONE*(1.12 if role!="baker" else 1.0)
	elif asset=="citizen_rigged":rig.scale=Vector3.ONE*(0.94+float(index%3)*0.04)
	return rig

static func imported_rig(parent: Node3D, asset: String, rig_name: String) -> Node3D:
	var instance=model(parent,asset)
	if instance==null:
		return null
	if instance.name==rig_name:
		return instance
	var rig=instance.find_child(rig_name,true,false)
	if rig:
		instance.remove_child(rig)
		parent.add_child(rig)
		instance.queue_free()
		return rig
	instance.name=rig_name
	return instance

static func recolor(root: Node, token: String, color: Color) -> void:
	if root is MeshInstance3D:
		for surface in root.mesh.get_surface_count():
			var source=root.mesh.surface_get_material(surface)
			if source and token in source.resource_name:
				var replacement=source.duplicate()
				if source.albedo_texture and token=="teal_cloth":
					if neutral_cloth==null:
						var source_image=source.albedo_texture.get_image()
						if source_image.is_compressed():
							source_image.decompress()
						var fabric=Image.create(source_image.get_width(),source_image.get_height(),false,Image.FORMAT_RGBA8)
						for y in source_image.get_height():
							for x in source_image.get_width():
								var weave=clampf(source_image.get_pixel(x,y).g/(84.0/255.0),0.5,1.0)
								fabric.set_pixel(x,y,Color(weave,weave,weave))
						neutral_cloth=ImageTexture.create_from_image(fabric)
					replacement.albedo_texture=neutral_cloth
				replacement.albedo_color=color
				root.set_surface_override_material(surface,replacement)
	for child in root.get_children():
		recolor(child,token,color)

static func limit_visibility(root: Node, distance: float) -> void:
	if root is GeometryInstance3D:
		root.visibility_range_end=distance
		root.visibility_range_end_margin=5
	for child in root.get_children():
		limit_visibility(child,distance)

static func material(color: Color, metal: float = 0.0, glow: float = 0.0) -> StandardMaterial3D:
	var key = str(color) + str(metal) + str(glow)
	if not materials.has(key):
		var m = StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.78 if metal == 0.0 else 0.32
		m.metallic = metal
		if metal==0.0 and glow==0.0 and color.a>=1.0:
			if surface_grain==null:
				var noise=FastNoiseLite.new()
				noise.seed=93
				noise.frequency=0.14
				noise.fractal_octaves=3
				surface_grain=NoiseTexture2D.new()
				surface_grain.width=256
				surface_grain.height=256
				surface_grain.seamless=true
				surface_grain.noise=noise
				var ramp=Gradient.new()
				ramp.colors=PackedColorArray([Color(0.78,0.78,0.78),Color.WHITE])
				surface_grain.color_ramp=ramp
				surface_normal=NoiseTexture2D.new()
				surface_normal.width=256
				surface_normal.height=256
				surface_normal.seamless=true
				surface_normal.noise=noise
				surface_normal.as_normal_map=true
				surface_normal.bump_strength=0.25
			m.albedo_texture=surface_grain
			m.normal_enabled=true
			m.normal_texture=surface_normal
			m.normal_scale=0.28
			m.uv1_triplanar=true
			m.uv1_scale=Vector3.ONE*0.85
		if color.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if glow > 0:
			m.emission_enabled = true
			m.emission = Color(color, 1.0)
			m.emission_energy_multiplier = glow
		materials[key] = m
	return materials[key]

static func mesh_node(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color, metal: float = 0.0, glow: float = 0.0) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color, metal, glow)
	node.position = pos
	parent.add_child(node)
	return node

static func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, metal: float = 0.0) -> MeshInstance3D:
	var key = "b" + str(size)
	if not meshes.has(key):
		var m = BoxMesh.new()
		m.size = size
		meshes[key] = m
	return mesh_node(parent, meshes[key], pos, color, metal)

static func sphere(parent: Node3D, pos: Vector3, size: Vector3, color: Color, glow: float = 0.0) -> MeshInstance3D:
	if not meshes.has("sphere"):
		var m = SphereMesh.new()
		m.radius = 0.5
		m.height = 1.0
		m.radial_segments = 16
		m.rings = 8
		meshes["sphere"] = m
	var n = mesh_node(parent, meshes.sphere, pos, color, 0.0, glow)
	n.scale = size
	return n

static func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, top: float = -1.0, segments: int = 16) -> MeshInstance3D:
	if top < 0:
		top = radius
	var key = "c" + str(radius) + ":" + str(height) + ":" + str(top) + ":" + str(segments)
	if not meshes.has(key):
		var m = CylinderMesh.new()
		m.bottom_radius = radius
		m.top_radius = top
		m.height = height
		m.radial_segments = segments
		meshes[key] = m
	return mesh_node(parent, meshes[key], pos, color)

static func torus(parent: Node3D, pos: Vector3, radius: float, thickness: float, color: Color, glow: float = 0.0) -> MeshInstance3D:
	var key = "t" + str(radius) + ":" + str(thickness)
	if not meshes.has(key):
		var m = TorusMesh.new()
		m.inner_radius = maxf(0.01, radius - thickness)
		m.outer_radius = radius + thickness
		m.rings = 40
		m.ring_segments = 8
		meshes[key] = m
	return mesh_node(parent, meshes[key], pos, color, 0.3, glow)

static func beam(parent: Node3D, a: Vector3, b: Vector3, width: float, color: Color) -> MeshInstance3D:
	var n = box(parent, (a + b) / 2, Vector3(width, a.distance_to(b), width), color)
	n.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	return n

static func body_box(parent: Node3D, pos: Vector3, size: Vector3) -> StaticBody3D:
	var b = StaticBody3D.new()
	b.position = pos
	b.collision_layer = 1
	b.collision_mask = 0
	var c = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	c.shape = shape
	b.add_child(c)
	parent.add_child(b)
	return b

static func pivot(parent: Node3D, title: String, pos: Vector3) -> Node3D:
	var n = Node3D.new()
	n.name = title
	n.position = pos
	parent.add_child(n)
	return n

static func knight(parent: Node3D, cloth: Color = TEAL, armored: bool = true) -> Node3D:
	var asset="hero_rigged" if armored else "citizen_rigged"
	if ResourceLoader.exists("res://assets/models/"+asset+".glb"):
		return character(parent,asset)
	var detailed=imported_rig(parent,"traveler" if armored else "villager","Rig")
	if detailed:
		recolor(detailed,"teal_cloth",cloth)
		toon(detailed)
		return detailed
	var rig = pivot(parent, "Rig", Vector3.ZERO)
	var torso = pivot(rig, "Torso", Vector3(0, 1.05, 0))
	var armor = Color("c6d3ce") if armored else cloth.lightened(0.15)
	var skin = Color("d9b18d")
	sphere(torso, Vector3(0, 0.25, 0), Vector3(0.64, 0.78, 0.39), armor)
	box(torso, Vector3(0, -0.01, 0), Vector3(0.61, 0.11, 0.41), WOOD)
	box(torso, Vector3(0, -0.01, -0.23), Vector3(0.13, 0.13, 0.055), GOLD, 0.7)
	box(torso, Vector3(0, 0.3, -0.2), Vector3(0.25, 0.46, 0.035), cloth)
	box(torso, Vector3(0, 0.3, -0.229), Vector3(0.035, 0.26, 0.02), GOLD)
	box(torso, Vector3(0, 0.36, -0.231), Vector3(0.15, 0.035, 0.02), GOLD)
	cylinder(rig, Vector3(0, 1.02, 0), 0.33, 0.5, cloth, 0.26)
	var head = pivot(rig, "Head", Vector3(0, 1.74, 0))
	sphere(head, Vector3.ZERO, Vector3(0.39, 0.45, 0.38), armor if armored else skin)
	if armored:
		box(head, Vector3(0, 0, -0.175), Vector3(0.31, 0.06, 0.048), Color("263a3d"))
		box(head, Vector3(0, -0.07, -0.19), Vector3(0.036, 0.2, 0.055), GOLD)
		for i in [-1, 1]:
			box(head, Vector3(i * 0.085, -0.10, -0.18), Vector3(0.018, 0.045, 0.032), Color("566565"))
		var plume = sphere(head, Vector3(0, 0.25, 0.07), Vector3(0.14, 0.38, 0.35), cloth)
		plume.rotation.x = -0.3
	else:
		sphere(head, Vector3(0, 0.13, 0.03), Vector3(0.43, 0.28, 0.39), WOOD)
		for i in [-1, 1]:
			sphere(head, Vector3(i * 0.08, 0.015, -0.174), Vector3(0.035, 0.035, 0.02), Color("33443d"))
	for side in [-1, 1]:
		var arm = pivot(rig, "ArmL" if side < 0 else "ArmR", Vector3(side * 0.36, 1.5, 0))
		sphere(arm, Vector3.ZERO, Vector3(0.32, 0.26, 0.39), armor)
		cylinder(arm, Vector3(0, -0.24, 0), 0.1, 0.4, cloth, 0.12)
		sphere(arm, Vector3(0, -0.39, 0), Vector3(0.23, 0.29, 0.23), armor)
		sphere(arm, Vector3(0, -0.54, 0), Vector3(0.15, 0.18, 0.18), WOOD if armored else skin)
		var leg = pivot(rig, "LegL" if side < 0 else "LegR", Vector3(side * 0.17, 0.91, 0))
		cylinder(leg, Vector3(0, -0.2, 0), 0.12, 0.38, WOOD)
		sphere(leg, Vector3(0, -0.43, -0.015), Vector3(0.24, 0.28, 0.26), armor)
		cylinder(leg, Vector3(0, -0.57, 0), 0.095, 0.3, armor, 0.11)
		box(leg, Vector3(0, -0.77, -0.05), Vector3(0.22, 0.18, 0.38), WOOD)
	if armored:
		var cape = pivot(rig, "Cape", Vector3(0, 1.51, 0.19))
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for v in [Vector3(-0.26, 0, 0), Vector3(0.4, -0.98, 0.2), Vector3(0.26, 0, 0), Vector3(-0.26, 0, 0), Vector3(-0.4, -0.98, 0.2), Vector3(0.4, -0.98, 0.2)]:
			st.add_vertex(v)
		st.generate_normals()
		var cape_mesh = mesh_node(cape, st.commit(), Vector3.ZERO, cloth)
		var cape_mat = material(cloth).duplicate()
		cape_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		cape_mesh.material_override = cape_mat
		for side in [-1, 1]:
			beam(cape, Vector3(side * 0.26, 0, 0), Vector3(side * 0.4, -0.98, 0.2), 0.026, GOLD)
	return rig

static func sword(parent: Node3D, large: bool = false) -> Node3D:
	var sword_node=PublicAssets.place(parent,"character-pack-adventures/sword_2handed" if large else "character-pack-adventures/sword_1handed",Vector3.ZERO,1.5 if large else 1.1)
	sword_node.name="Sword"
	sword_node.rotation.x=-PI/2
	sword_node.position.z=0.14
	sword_node.set_meta("trail_base",Vector3(0,0.22,0))
	sword_node.set_meta("trail_tip",Vector3(0,1.5 if large else 1.1,0))
	return sword_node

static func horse(parent: Node3D) -> Node3D:
	var mount=PublicCharacter.new()
	parent.add_child(mount)
	mount.configure("animals/Horse")
	mount.name="HorseRig"
	return mount

static func label3d(parent: Node3D, text: String, pos: Vector3, color: Color = IVORY, size: int = 36) -> Label3D:
	var l = Label3D.new()
	l.text = text
	l.position = pos
	l.font_size = size
	l.pixel_size = 0.009
	l.modulate = color
	l.outline_modulate = Color("243b36")
	l.outline_size = 7
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = false
	if label_font==null:
		label_font=SystemFont.new()
		label_font.font_names=PackedStringArray(["PingFang TC", "Noto Sans CJK TC", "Microsoft JhengHei"])
		label_font.fallbacks=[load("res://assets/fonts/NotoSansCJKtc-Regular.otf")]
	l.font=label_font
	parent.add_child(l)
	return l

static func batch_static(root: Node3D) -> void:
	var groups: Dictionary = {}
	_collect(root, root, groups)
	for key in groups:
		var nodes: Array = groups[key]
		if nodes.size() < 3:
			continue
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = nodes[0].mesh.duplicate()
		for surface in mm.mesh.get_surface_count():
			var override=nodes[0].get_surface_override_material(surface)
			if override:mm.mesh.surface_set_material(surface,override)
		mm.instance_count = nodes.size()
		var instance = MultiMeshInstance3D.new()
		instance.multimesh = mm
		instance.material_override = nodes[0].material_override
		root.add_child(instance)
		for i in nodes.size():
			mm.set_instance_transform(i, root.global_transform.affine_inverse() * nodes[i].global_transform)
			nodes[i].queue_free()

static func _collect(root: Node3D, current: Node, groups: Dictionary) -> void:
	for c in current.get_children():
		if c.is_queued_for_deletion():
			continue
		if c is MeshInstance3D and c.mesh != null:
			var key = str(c.mesh.get_instance_id()) + ":" + (str(c.material_override.get_instance_id()) if c.material_override else "embedded")
			# Surface overrides represent per-building colour variants.
			for surface in c.mesh.get_surface_count():
				var override=c.get_surface_override_material(surface)
				if override:
					key += ":"+str(override.get_instance_id())
			if not groups.has(key):
				groups[key] = []
			groups[key].append(c)
		_collect(root, c, groups)
