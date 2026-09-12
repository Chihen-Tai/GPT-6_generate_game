class_name WorldSnapshot
extends RefCounted

# Keep each unreliable RPC below the transport MTU. A lost part drops only
# that snapshot; the next complete tick replaces it without retransmission.
const CHUNK_SIZE = 1000
const MAX_PARTS = 128
const MAX_DECODED_SIZE = 262144
var tick = -1
var parts: Dictionary = {}
var expected = 0

static func encode(state: Dictionary) -> Array:
	var bytes=var_to_bytes(state).compress(FileAccess.COMPRESSION_DEFLATE)
	var chunks=[]
	for offset in range(0,bytes.size(),CHUNK_SIZE):
		chunks.append(bytes.slice(offset,offset+CHUNK_SIZE))
	return chunks

func receive(frame: int, index: int, count: int, bytes: PackedByteArray) -> Dictionary:
	if frame<tick or count<1 or count>MAX_PARTS or index<0 or index>=count or bytes.size()>CHUNK_SIZE:return {}
	if frame>tick:
		tick=frame
		parts.clear()
		expected=count
	if expected!=count:return {}
	parts[index]=bytes
	if parts.size()!=expected:return {}
	var compressed=PackedByteArray()
	for i in expected:compressed.append_array(parts[i])
	parts.clear()
	var decoded=compressed.decompress_dynamic(MAX_DECODED_SIZE,FileAccess.COMPRESSION_DEFLATE)
	if decoded.is_empty():return {}
	var state=bytes_to_var(decoded)
	return state if state is Dictionary else {}
