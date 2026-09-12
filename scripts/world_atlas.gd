class_name WorldAtlas
extends RefCounted

const HALF_SIZE=1200.0
const CHUNK_SIZE=200.0
const CHUNK_COUNT=12
const LAYOUT_VERSION=2
const REGIONS=[
	{"name":"晨曦腹地","center":Vector3(0,0,0),"color":"839b5e"},
	{"name":"翠風林海","center":Vector3(560,0,100),"color":"64876a"},
	{"name":"琥珀田野","center":Vector3(-560,0,310),"color":"b0a36f"},
	{"name":"霜冠雪境","center":Vector3(620,0,-650),"color":"d8e6e9"},
	{"name":"銀灣海岸","center":Vector3(-620,0,-550),"color":"99bfb1"},
	{"name":"赤砂峽谷","center":Vector3(720,0,700),"color":"c79d78"},
	{"name":"紫藤丘陵","center":Vector3(-170,0,720),"color":"899b7b"},
	{"name":"星隕荒原","center":Vector3(-790,0,840),"color":"99977e"},
	{"name":"天穹群峰","center":Vector3(0,0,-890),"color":"a5b8bd"}
]
static var settlements: Array[Dictionary]=[]
static var dungeons: Array[Dictionary]=[]
static var roads: Array=[]
static var camps: Array[Dictionary]=[]

static func initialize() -> void:
	if not settlements.is_empty():return
	# Authored landmarks remain in the origin region; distant settlements have stable ids.
	var names=["晨露","白鹿","星溪","麥穗","銀松","月灣","琥珀","風車","翠羽","霜葉","虹石","杉影","落霞","晴川","紫藤","遠鐘","明泉","雲雀","晨星","雪紋","鹿鳴","金棘","映月","蒼石","新芽"]
	for row in 5:
		for col in 5:
			var i=row*5+col
			if i==12:continue
			var p=Vector3(-880+col*440,0,-880+row*440)
			if i==7:p.z=-560 # Leave the authored final sanctuary clear.
			var kind="town" if i%3==0 else "village"
			settlements.append({"id":"settlement_%02d"%i,"name":names[i]+("城" if kind=="town" else "村"),"center":p,"type":kind,"region":region_at(p).name})
			for offset in [-1,1]:
				var q=p+Vector3(offset*145,0,115)
				settlements.append({"id":"hamlet_%02d_%d"%[i,offset],"name":names[i]+("東鄉" if offset==1 else "西鄉"),"center":q,"type":"hamlet","region":region_at(q).name})
				roads.append([p,q])
	# Regional grid routes connect to the preserved starter world at the origin.
	for i in 5:
		var c=-880+i*440
		roads.append([Vector3(-1080,0,c),Vector3(1080,0,c)])
		roads.append([Vector3(c,0,-1080),Vector3(c,0,1080)])
	var boss_names=["蒼苔古衛","月泉祭司","赤棘獸王","霜翼巨蝠","銅鐘騎士","星沙巨像","斷誓雙刃","銀灣潮使","熾爐領主","紫藤幻術師","石脊山王","雪葬守門人","林海獵王","雷鳴裁決者","日蝕劍聖","深井咒師","琥珀龍裔","天星看守","長夜王冠"]
	for i in 19:
		var town:Dictionary=settlements[(i*3)%settlements.size()]
		var p=Vector3.ZERO
		var found=false
		for offset in [Vector3(210,0,-175),Vector3(-210,0,-175),Vector3(210,0,230),Vector3(-210,0,230),Vector3(0,0,-230),Vector3(0,0,-160),Vector3(260,0,-40),Vector3(-260,0,-40)]:
			var candidate:Vector3=town.center+offset
			if clear_site(candidate,80):
				p=candidate;found=true;break
		assert(found,"No safe dungeon footprint for "+town.id)
		dungeons.append({"id":"dungeon_%02d"%i,"name":["古堡","地下墓室","封印神殿","廢棄礦坑"][i%4]+" · "+town.name,"center":p,"boss":boss_names[i],"profile":i,"type":i%4})
		roads.append([town.center,p+Vector3(0,0,95)])
		roads.append([p+Vector3(0,0,95),p+Vector3(0,0,68)])

	# Small roadside stops break up travel: alternate supplies and guarded ruins.
	for step in range(1,16):
		for segment in roads:
			var length:float=segment[0].distance_to(segment[1])
			if length<500 or step*140>=length:continue
			var direction:Vector3=(segment[1]-segment[0]).normalized()
			var point:Vector3=segment[0]+direction*step*140+Vector3(-direction.z,0,direction.x)*24
			if not clear_site(point,28):continue
			camps.append({"id":"camp_%02d"%camps.size(),"center":point,"hostile":camps.size()%2==1})
			if camps.size()>=32:break
		if camps.size()>=32:break

static func footprint(site: Dictionary) -> float:
	if site.has("boss"):return 80.0
	return 115.0 if site.type=="town" else 65.0 if site.type=="village" else 48.0

static func clear_site(p: Vector3, radius: float) -> bool:
	if absf(p.x)+radius>HALF_SIZE-15 or absf(p.z)+radius>HALF_SIZE-15:return false
	if p.x>-250-radius and p.x<250+radius and p.z>-395-radius and p.z<125+radius:return false
	for site in settlements+dungeons:
		if p.distance_to(site.center)<radius+footprint(site)+8:return false
	for camp in camps:
		if p.distance_to(camp.center)<radius+65:return false
	return true

static func restore_checkpoint(p: Vector3, layout: int) -> Vector3:
	initialize()
	if layout<LAYOUT_VERSION and (absf(p.x)>250 or p.z<-395 or p.z>125):
		# Old shrines used stable settlement IDs; relocate their saved checkpoints.
		for row in 5:
			for col in 5:
				var index=row*5+col
				if index==12:continue
				var old=Vector3(-4000+col*2000,0,-4000+row*2000)
				for offset in [0,-1,1]:
					var location=old if offset==0 else old+Vector3(offset*560,0,350 if index%2==0 else -350)
					if Vector2(p.x-location.x,p.z-location.z).length()>40:continue
					var id="settlement_%02d"%index if offset==0 else "hamlet_%02d_%d"%[index,offset]
					for site in settlements:
						if site.id==id:return site.center+Vector3(0,.4,18)
		return Vector3(4,.4,30)
	if not p.is_finite() or not in_bounds(p):return Vector3(4,.4,30)
	return Vector3(p.x,clampf(p.y,0,4),p.z)

static func region_at(p: Vector3) -> Dictionary:
	var best=REGIONS[0]
	var distance=INF
	for r in REGIONS:
		var d=Vector2(p.x-r.center.x,p.z-r.center.z).length_squared()
		if d<distance:distance=d;best=r
	return best

static func key(p: Vector3) -> Vector2i:
	return Vector2i(floori((p.x+HALF_SIZE)/CHUNK_SIZE),floori((p.z+HALF_SIZE)/CHUNK_SIZE))

static func in_bounds(p: Vector3) -> bool:
	return absf(p.x)<HALF_SIZE and absf(p.z)<HALF_SIZE
