class_name Progression
extends RefCounted

const MAX_LEVEL=50
const HEALTH_GROWTH=[8.0,11.0,6.0,7.0,9.0]
const MANA_GROWTH=[3.0,2.0,5.0,3.0,4.0]

static func required(level: int) -> int:
	if level>=MAX_LEVEL:return 0
	var n=maxi(0,level-1)
	return 120+60*n+12*n*n

static func reward(foe: Foe) -> int:
	if foe.kind=="boss":return 5000
	if foe.is_boss:return 1500+maxi(0,foe.boss_profile)*100
	return {"slime":40,"bat":40,"sentinel":60,"mage":90,"elite":180}.get(foe.kind,60)

static func safe_integer(value: Variant, fallback: int, maximum: int) -> int:
	if not (value is int or value is float) or not is_finite(float(value)):return fallback
	return clampi(int(value),0,maximum)
