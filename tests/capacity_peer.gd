extends Node
# Matches the production RPC contract, with no meshes or gameplay simulation.
var elapsed=0.0
var maximum_seen=0
var snapshots=0
var sequence=0
var registered=false
var send_elapsed=0.0
var expected_rejection=false
var snapshot_stream=WorldSnapshot.new()
var verified=false
func _ready() -> void:
	var port=24672
	var title="Load guest"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port="):port=int(arg.trim_prefix("--port="))
		if arg.begins_with("--name="):title=arg.trim_prefix("--name=")
		if arg=="--overflow":expected_rejection=true
	multiplayer.connected_to_server.connect(func():register.rpc_id(1,"aurelia-realm-5",title,{"gender":1,"job":2,"skills":[11,8,4,3]} if title=="Guest1" else {}))
	multiplayer.connection_failed.connect(func():get_tree().quit(1))
	var peer=ENetMultiplayerPeer.new()
	peer.create_client("127.0.0.1",port,3)
	multiplayer.multiplayer_peer=peer
func _process(delta: float) -> void:
	elapsed+=delta
	if elapsed>60:get_tree().quit(1)
	send_elapsed+=delta
	if registered and send_elapsed>=0.05:
		send_elapsed=0
		sequence+=1
		movement.rpc_id(1,sequence,Vector2.ZERO,0.0,false)
	if FileAccess.file_exists("res://art/capacity-stop.flag") and registered:
		print("CAPACITY_CLIENT max_seen=",maximum_seen," snapshots=",snapshots)
		multiplayer.multiplayer_peer.close()
		get_tree().quit(0 if maximum_seen==32 and snapshots>=5 else 1)
@rpc("any_peer","call_remote","reliable",0)
func register(version: String, display_name: String, profile: Dictionary) -> void:pass
@rpc("authority","call_remote","reliable",0)
func rejected(reason: String) -> void:
	print("CAPACITY_REJECTED ",reason)
	get_tree().quit(0 if expected_rejection else 1)
@rpc("authority","call_remote","reliable",0)
func welcome(version: String, state: Dictionary) -> void:
	registered=true
	var self_state:Dictionary=state.actors[multiplayer.get_unique_id()]
	if self_state.name=="Guest1":
		if self_state.profile.gender!=1 or self_state.max_mana!=140 or self_state.profile.skills[0]!=11:
			push_error("Character registration profile was lost")
			get_tree().quit(1)
	maximum_seen=maxi(maximum_seen,state.actors.size())
@rpc("any_peer","call_remote","unreliable_ordered",1)
func movement(seq: int, axis: Vector2, angle: float, sprinting: bool) -> void:pass
@rpc("any_peer","call_remote","reliable",0)
func command(seq: int, action: String, value: int, angle: float, axis: Vector2, enemy: int) -> void:pass
@rpc("authority","call_remote","reliable",2)
func effect(kind: String, data: Array) -> void:pass
@rpc("authority","call_remote","unreliable",1)
func snapshot(frame: int, index: int, count: int, bytes: PackedByteArray) -> void:
	var state=snapshot_stream.receive(frame,index,count,bytes)
	if state.is_empty():return
	snapshots+=1
	maximum_seen=maxi(maximum_seen,state.actors.size())
	if maximum_seen==32 and snapshots>=5 and not verified:
		verified=true
		print("CAPACITY_VERIFIED")
@rpc("authority","call_remote","reliable",0)
func notice(message: String) -> void:pass
