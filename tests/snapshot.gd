extends SceneTree
var passed=0
var failed=0
func check(value: bool, message: String) -> void:
	if value:passed+=1;print("SNAPSHOT PASS: ",message)
	else:failed+=1;push_error("SNAPSHOT FAIL: "+message)
func _initialize() -> void:
	var random=RandomNumberGenerator.new()
	random.seed=47291
	var actors={}
	for i in 32:
		var positions=[]
		for j in 20:positions.append(Vector3(random.randf(),random.randf(),random.randf()))
		actors[i]={"name":"旅人"+str(i),"positions":positions,"hp":140-i}
	var state={"tick":100,"actors":actors}
	var chunks=WorldSnapshot.encode(state)
	check(chunks.size()>1 and chunks.all(func(c):return c.size()<=1000),"Large world is split into payloads below the MTU")
	var stream=WorldSnapshot.new()
	var received={}
	for i in chunks.size():received=stream.receive(100,i,chunks.size(),chunks[i])
	check(received==state,"All 32 actors retain names, positions and HP after transport")
	stream=WorldSnapshot.new()
	for i in chunks.size()-1:received=stream.receive(101,i,chunks.size(),chunks[i])
	check(received.is_empty(),"A missing final packet never applies a partial world")
	for i in chunks.size():received=stream.receive(102,i,chunks.size(),chunks[i])
	check(received==state,"The next complete snapshot recovers after packet loss")
	check(stream.receive(101,0,chunks.size(),chunks[0]).is_empty(),"Delayed older packets cannot roll back a newer world")
	stream=WorldSnapshot.new()
	for i in range(chunks.size()-1,-1,-1):received=stream.receive(103,i,chunks.size(),chunks[i])
	check(received==state,"Fragment assembly tolerates reordered packets")
	check(stream.receive(104,0,129,chunks[0]).is_empty(),"Excessive fragment counts are rejected")
	var oversized=PackedByteArray()
	oversized.resize(1001)
	check(stream.receive(104,0,1,oversized).is_empty(),"Oversized fragments are rejected")
	print("SNAPSHOT RESULT: %d passed, %d failed" % [passed,failed])
	quit(1 if failed else 0)
