"""Give sparse index accessors individual views for Godot 4.6's strict decoder.

GLB binary payloads (vertices, skins, animations, textures) remain byte-identical.
https://github.com/godotengine/godot/blob/4.6-stable/modules/gltf/structures/gltf_accessor.cpp
Run after glTF Transform dedup/prune, which may merge these index views.
"""
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SIZES = {5121: 1, 5123: 2, 5125: 4}


def normalize(path: Path) -> int:
    original = path.read_bytes()
    assert original[:4] == b'glTF'
    length, kind = struct.unpack_from('<II', original, 12)
    assert kind == 0x4E4F534A
    document = json.loads(original[20:20 + length])
    payload = original[20 + length:]
    views = document.get('bufferViews', [])
    fixed = 0
    for accessor in document.get('accessors', []):
        sparse = accessor.get('sparse')
        if not sparse:
            continue
        indices = sparse['indices']
        source = views[indices['bufferView']]
        offset = indices.get('byteOffset', 0)
        size = sparse['count'] * SIZES[indices['componentType']]
        assert offset + size <= source['byteLength']
        if offset == 0 and source['byteLength'] == size:
            continue
        # Add a view instead of changing a view shared by another accessor.
        views.append({'buffer': source['buffer'],
                      'byteOffset': source.get('byteOffset', 0) + offset,
                      'byteLength': size})
        indices['bufferView'] = len(views) - 1
        indices.pop('byteOffset', None)
        fixed += 1
    if fixed:
        encoded = json.dumps(document, separators=(',', ':')).encode()
        encoded += b' ' * (-len(encoded) % 4)
        result = (struct.pack('<4sII', b'glTF', 2, 20 + len(encoded) + len(payload))
                  + struct.pack('<II', len(encoded), kind) + encoded + payload)
        assert result[20 + len(encoded):] == payload
        path.write_bytes(result)
    return fixed


if __name__ == '__main__':
    for path in sorted((ROOT / 'assets/models').glob('*_rigged.glb')):
        count = normalize(path)
        if count:
            print(f'{path.name}: {count} sparse index views normalized; binary payload unchanged')
