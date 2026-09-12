class_name CharacterProfile
extends RefCounted

const CLASSES=["魔劍士","守護騎士","元素法師","疾風遊俠","曦光祭司"]
const HEALTH=[140.0,180.0,115.0,125.0,150.0]
const MANA=[100.0,85.0,140.0,100.0,120.0]
const SPEED=[1.0,.92,1.0,1.13,1.0]

static func clean(value: Dictionary) -> Dictionary:
	var gender=_selection(value.get("gender",0),1)
	var job=_selection(value.get("job",0),4)
	var order:Array=[]
	var selected=value.get("skills",[0,1,2,3])
	if selected is Array:
		for item in selected.slice(0,12):
			if (item is int or item is float) and is_finite(float(item)) and int(item)>=0 and int(item)<12 and not int(item) in order and order.size()<4:order.append(int(item))
	for i in 12:
		if not i in order:order.append(i)
	return {"gender":gender,"job":job,"skills":order}

static func _selection(value: Variant, maximum: int) -> int:
	if not (value is int or value is float):return 0
	if not is_finite(float(value)):return 0
	return clampi(int(value),0,maximum)
