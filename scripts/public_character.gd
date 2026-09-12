class_name PublicCharacter
extends AnimatedCharacter

func configure(asset: String) -> void:
	source_asset=asset
	name="Rig"
	var model=PublicAssets.instantiate(self,asset)
	skeleton=_find_type(model,"Skeleton3D")
	animator=_find_type(model,"AnimationPlayer")
	assert(skeleton and animator,"Public character needs authored animation")
	animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var available=animator.get_animation_list()
	var mappings={
		"idle":["Idle","Horse_Idle","Cow_Idle","Sheep_Idle","Slime_Idle","Skeleton_Idle","Dragon_Flying","Bat_Flying"],
		"relax":["Unarmed_Idle","Idle"], "talk":["Interact","Cheer","Idle"],
		"walk":["Walking_A","Horse_Walk","Walk","Slime_Walk","Skeleton_Running","Dragon_Flying","Bat_Flying"],
		"run":["Running_A","Horse_Run","Run","Slime_Walk","Skeleton_Running"],
		"heavy":["2H_Melee_Attack_Chop","Weapon","Dragon_Attack2","Slime_Attack","Skeleton_Attack","Bat_Attack2"],
		"slash_a":["1H_Melee_Attack_Slice_Diagonal","Punch","Dragon_Attack","Slime_Attack","Skeleton_Attack","Bat_Attack"],
		"slash_b":["1H_Melee_Attack_Slice_Horizontal","Weapon","Dragon_Attack2","Slime_Attack","Skeleton_Attack","Bat_Attack2"],
		"slash_c":["2H_Melee_Attack_Spin","Punch","Dragon_Attack","Slime_Attack","Skeleton_Attack","Bat_Attack"],
		"cast":["Spellcast_Long","Weapon","Dragon_Attack2","Slime_Attack","Skeleton_Attack","Bat_Attack"],
		"hurt":["Hit_A","HitReact","Dragon_Hit","Bat_Hit","Slime_Idle","Skeleton_Idle"],
		"death":["Death","Death_A","Dragon_Death","Bat_Death","Skeleton_Death"],
		"work":["Interact","PickUp","Idle"],"cheer":["Cheer","Idle"],
		"sit":["Sit_Chair_Idle","Idle"],"roll":["Dodge_Forward","Idle"]}
	for alias in mappings:
		for candidate in mappings[alias]:
			for full in available:
				if String(full).get_file()==candidate:
					clips[alias]=full
					break
			if clips.has(alias):break
	if not clips.has("idle") and available.size()>0:clips.idle=available[0]
	for alias in mappings:
		if not clips.has(alias):clips[alias]=clips.idle
	clips.recover_a=clips.idle
	clips.recover_b=clips.idle
	# Preserve original skin; fit the authored model to gameplay dimensions.
	var box=PublicAssets.measure(model)
	var height=2.4 if "Horse" in asset else 5.8 if "Dragon" in asset else (1.0 if "Slime" in asset or "Bat" in asset else 1.8)
	var factor=height/maxf(.01,box.size.y)
	model.rotation.y=PI
	model.scale*=factor
	model.position.y-=box.position.y*factor
	for part in ["Head","ArmR","ArmL"]:
		var attachment=BoneAttachment3D.new()
		skeleton.add_child(attachment)
		var names=["head","Head"] if part=="Head" else (["handslot.r","hand.r"] if part=="ArmR" else ["handslot.l","hand.l"])
		for bone in names:
			if skeleton.find_bone(bone)>=0:
				attachment.bone_name=bone
				break
		if attachment.bone_name.is_empty():attachment.bone_idx=0
		var socket_node=Node3D.new()
		attachment.add_child(socket_node)
		sockets[part]=socket_node
	pose("idle",0,0,0)
