"""Lossless structural GLB cleanup; retains textures, morphs, skins and clip names.
Bootstrap: npx --cache tools/npm-cache --yes @gltf-transform/cli@4.3.0 --help
"""
import subprocess,json,sys
from pathlib import Path
from fix_sparse_views import normalize
ROOT=Path(__file__).resolve().parents[1]
cli=next((ROOT/'tools/npm-cache').glob('_npx/*/node_modules/@gltf-transform/cli/bin/cli.js'))
results=[]
for path in sorted((ROOT/'assets/models').glob('*_rigged.glb')):
 before=path.stat().st_size
 temp=ROOT/'art'/('dedup_'+path.name)
 for args in [['dedup',str(path),str(temp)],['prune',str(temp),str(path)]]:
  subprocess.run(['/usr/local/bin/node',str(cli),*args],check=True)
 normalize(path)
 temp.unlink()
 results.append({'asset':path.name,'before_bytes':before,'after_bytes':path.stat().st_size})
(ROOT/'art/character-optimization.json').write_text(json.dumps(results,indent=2))
print(results)
