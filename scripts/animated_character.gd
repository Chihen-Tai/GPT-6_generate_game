class_name AnimatedCharacter
extends Node3D

# Imported, skinned characters; combat physics remain owned by Hero/Foe.
var skeleton: Skeleton3D
var animator: AnimationPlayer
var sockets: Dictionary = {}
var clips: Dictionary = {}
var current_clip = ""
var blend_elapsed = 0.0
var blend_rotations: Array[Quaternion] = []
var blend_positions: Array[Vector3] = []
var source_asset = ""
var seated_hip=Vector3.ZERO
var hip_index=-1

func configure(asset: String) -> void:
	source_asset=asset
	name="Rig"
	var model=Art.model(self,asset)
	if asset=="hero_female_rigged":model.scale*=1.12
	skeleton=_find_type(model,"Skeleton3D")
	animator=_find_type(model,"AnimationPlayer")
	assert(skeleton!=null and animator!=null,"Character asset needs skin and baked animation")
	animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for key in animator.get_animation_list():
		clips[String(key).get_file()]=key
	var is_vrm=skeleton.find_bone("J_Bip_C_Head")>=0
	for pair in [["Head","J_Bip_C_Head" if is_vrm else "Head"],["ArmR","J_Bip_R_Hand" if is_vrm else "hand_r"],["ArmL","J_Bip_L_Hand" if is_vrm else "hand_l"]]:
		var attachment=BoneAttachment3D.new()
		skeleton.add_child(attachment)
		attachment.bone_name=pair[1]
		var socket=Node3D.new()
		socket.name=pair[0]+"Socket"
		attachment.add_child(socket)
		var rest=skeleton.get_bone_global_rest(skeleton.find_bone(pair[1]))
		socket.basis=rest.basis.inverse()*(Basis.IDENTITY if is_vrm else Basis(Vector3.UP,PI))
		if pair[0]!="Head":
			var side="l" if pair[0]=="ArmL" else "r"
			if not is_vrm:
				var thumb=skeleton.get_bone_global_rest(skeleton.find_bone("thumb_01_"+side)).origin
				var pinky=skeleton.get_bone_global_rest(skeleton.find_bone("pinky_01_"+side)).origin
				var middle=skeleton.get_bone_global_rest(skeleton.find_bone("middle_01_"+side)).origin
				# The blade exits the thumb side of a closed fist.
				socket.basis=rest.basis.inverse()*Basis.looking_at((thumb-pinky).normalized(),Vector3.UP)
				socket.position=rest.basis.inverse()*(middle-rest.origin)*0.63
			else:
				socket.position=rest.basis.inverse()*Vector3(-0.045 if pair[0]=="ArmL" else 0.045,0,0)
		socket.set_meta("hand_socket",pair[0]!="Head")
		sockets[pair[0]]=socket
	if clips.has("sit"):
		pose("sit",0,0,0)
		hip_index=skeleton.find_bone("J_Bip_C_Hips" if is_vrm else "pelvis")
		if hip_index>=0:seated_hip=skeleton.get_bone_pose_position(hip_index)
	pose("idle" if clips.has("idle") else "relax",0,0,0)

func _find_type(root_node: Node, type: String) -> Node:
	if root_node.is_class(type):return root_node
	for child in root_node.get_children():
		var found=_find_type(child,type)
		if found:return found
	return null

func socket(part: String) -> Node3D:
	return sockets[part]

func pose(clip: String, progress: float, delta: float, blend: float = 0.09) -> void:
	if not clips.has(clip):return
	if current_clip!=clip:
		blend_rotations.clear()
		blend_positions.clear()
		for bone in skeleton.get_bone_count():
			blend_rotations.append(skeleton.get_bone_pose_rotation(bone))
			blend_positions.append(skeleton.get_bone_pose_position(bone))
		blend_elapsed=0
		current_clip=clip
		animator.play(clips[clip],0)
	blend_elapsed+=delta
	var animation=animator.get_animation(clips[clip])
	animator.seek(clampf(progress,0,0.9999)*animation.length,true)
	if blend>0 and blend_elapsed<blend:
		var t=smoothstep(0,blend,blend_elapsed)
		for bone in skeleton.get_bone_count():
			skeleton.set_bone_pose_rotation(bone,blend_rotations[bone].slerp(skeleton.get_bone_pose_rotation(bone),t))
			skeleton.set_bone_pose_position(bone,blend_positions[bone].lerp(skeleton.get_bone_pose_position(bone),t))

func cycle(clip: String, time: float, delta: float, rate: float = 1.0) -> void:
	if not clips.has(clip):return
	var duration=animator.get_animation(clips[clip]).length
	pose(clip,fposmod(time*rate,duration)/duration,delta,0.14)

func sword_pose(combo: int, heavy: bool, progress: float, delta: float) -> void:
	if heavy:
		pose("heavy",progress,delta,0.055)
	elif combo==2:
		pose("slash_c",progress,delta,0.055)
	elif progress<0.62:
		pose("slash_a" if combo==0 else "slash_b",progress/0.62,delta,0.055)
	else:
		pose("recover_a" if combo==0 else "recover_b",(progress-0.62)/0.38,delta,0.035)

func riding_pose(time: float, delta: float) -> void:
	cycle("sit",time,delta)
	apply_riding_posture()

func apply_riding_posture() -> void:
	if hip_index>=0:skeleton.set_bone_pose_position(hip_index,seated_hip)
	# Align each leg in world space so retargeted rigs straddle the horse consistently.
	for side in [-1,1]:
		var suffix="l" if side==-1 else "r"
		var vrm="L" if side==-1 else "R"
		var thigh=skeleton.find_bone("thigh_"+suffix)
		var calf=skeleton.find_bone("calf_"+suffix)
		var foot=skeleton.find_bone("foot_"+suffix)
		if thigh<0:
			thigh=skeleton.find_bone("J_Bip_"+vrm+"_UpperLeg")
			calf=skeleton.find_bone("J_Bip_"+vrm+"_LowerLeg")
			foot=skeleton.find_bone("J_Bip_"+vrm+"_Foot")
		if thigh<0 or calf<0 or foot<0:continue
		_align_bone(thigh,calf,Vector3(side*.72,-.65,-.2))
		_align_bone(calf,foot,Vector3(side*.08,-.95,.3))

func _align_bone(bone: int, child: int, direction: Vector3) -> void:
	skeleton.force_update_all_bone_transforms()
	var pose=skeleton.get_bone_global_pose(bone)
	var tip=skeleton.get_bone_global_pose(child).origin
	var wanted=(skeleton.global_basis.inverse()*global_basis*direction).normalized()
	var change=Quaternion((tip-pose.origin).normalized(),wanted)
	var parent=skeleton.get_bone_parent(bone)
	var parent_rotation=skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion() if parent>=0 else Quaternion.IDENTITY
	skeleton.set_bone_pose_rotation(bone,parent_rotation.inverse()*change*pose.basis.get_rotation_quaternion())
	skeleton.force_update_all_bone_transforms()
