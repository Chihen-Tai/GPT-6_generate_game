extends SceneTree
var passed=0
var failed=0
func check(ok:bool,label:String) -> void:
	if ok:passed+=1
	else:failed+=1;push_error(label)
func _initialize() -> void:
	WorldAtlas.initialize()
	check(WorldAtlas.settlements.size()==72 and WorldAtlas.dungeons.size()==19,"Preserve settlements and bosses")
	check(WorldAtlas.camps.size()==32,"32 roadside stops")
	var sites=WorldAtlas.settlements+WorldAtlas.dungeons
	for site in sites:
		check(absf(site.center.x)+WorldAtlas.footprint(site)<WorldAtlas.HALF_SIZE and absf(site.center.z)+WorldAtlas.footprint(site)<WorldAtlas.HALF_SIZE,"Site footprint within boundary: "+site.id)
	for dungeon in WorldAtlas.dungeons:
		for site in sites:
			if site.id==dungeon.id:continue
			check(dungeon.center.distance_to(site.center)>=80+WorldAtlas.footprint(site)+8,"Dungeon clear of other sites: "+dungeon.id+" / "+site.id)
	var farthest=0.0
	for site in WorldAtlas.settlements:
		var nearest=INF
		for other in WorldAtlas.settlements:
			if site.id!=other.id:nearest=minf(nearest,site.center.distance_to(other.center))
		farthest=maxf(farthest,nearest)
	check(farthest<200,"Every settlement has another settlement within 200 metres")
	for camp in WorldAtlas.camps:
		for site in sites:check(camp.center.distance_to(site.center)>=28+WorldAtlas.footprint(site)+8,"Camp does not overlap site")
	for row in 5:
		for col in 5:
			var index=row*5+col
			if index==12:continue
			for offset in [0,-1,1]:
				var old=Vector3(-4000+col*2000,.4,-4000+row*2000)
				if offset!=0:old+=Vector3(offset*560,0,350 if index%2==0 else -350)
				old.z+=18
				var id="settlement_%02d"%index if offset==0 else "hamlet_%02d_%d"%[index,offset]
				for site in WorldAtlas.settlements:
					if site.id==id:check(WorldAtlas.restore_checkpoint(old,1).is_equal_approx(site.center+Vector3(0,.4,18)),"Migrate old checkpoint: "+id)
	check(WorldAtlas.restore_checkpoint(Vector3(5,.3,-65),1).is_equal_approx(Vector3(5,.3,-65)),"Preserve starter checkpoint")
	check(WorldAtlas.restore_checkpoint(Vector3(4500,.4,4500),2).is_equal_approx(Vector3(4,.4,30)),"Invalid checkpoint returns to starter shrine")
	check(WorldAtlas.key(Vector3(-1199,0,-1199))==Vector2i.ZERO and WorldAtlas.key(Vector3(1199,0,1199))==Vector2i(11,11),"Edge chunks match compact bounds")
	print("COMPACT RESULT: %d passed, %d failed; maximum nearest settlement %.1fm"%[passed,failed,farthest])
	quit(0 if failed==0 else 1)
