class_name BladeTrail
extends MeshInstance3D

var blade: Node3D
var active = false
var points: Array[Dictionary] = []
var ribbon = ImmediateMesh.new()

func setup(sword: Node3D) -> void:
	blade=sword
	top_level=true
	global_transform=Transform3D.IDENTITY
	mesh=ribbon
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo=true
	material.albedo_color=Color(0.4,0.9,1,0.75)
	material_override=material

func _process(delta: float) -> void:
	for point in points:point.life-=delta
	while not points.is_empty() and points[0].life<=0:points.pop_front()
	if active and is_instance_valid(blade):
		points.append({"a":blade.to_global(blade.get_meta("trail_base",Vector3(0,0,-0.30))),"b":blade.to_global(blade.get_meta("trail_tip",Vector3(0,0,-1.42))),"life":0.10})
	if points.size()>8:points.pop_front()
	ribbon.clear_surfaces()
	if points.size()<2:return
	ribbon.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1,points.size()):
		var old=points[i-1]
		var next=points[i]
		for item in [[old,"a"],[old,"b"],[next,"b"],[old,"a"],[next,"b"],[next,"a"]]:
			ribbon.surface_set_color(Color(0.45,0.92,1.0,item[0].life/0.10))
			ribbon.surface_add_vertex(item[0][item[1]])
	ribbon.surface_end()
