"""Copy authored public assets, preserving dependencies and recording checksums."""
from pathlib import Path
import json, shutil, hashlib
ROOT=Path(__file__).resolve().parents[1]
V=ROOT/'art/vendor/expansion'; OUT=ROOT/'assets/vendor'; OUT.mkdir(exist_ok=True)
catalog={}; packs=[]
for source in sorted(V.glob('KayKit-*')):
 key=source.name.replace('KayKit-','').replace('-1.0-main','').lower()
 dest=OUT/key
 for p in source.rglob('*'):
  if p.is_file() and p.suffix.lower() in ['.gltf','.glb','.bin','.png','.txt','.md']:
   q=dest/p.relative_to(source);q.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,q)
   if p.suffix in ['.gltf','.glb']:
    name=key+'/'+p.name.replace('.gltf','').replace('.glb','')
    catalog[name]={'path':'res://'+str(q.relative_to(ROOT)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
 packs.append({'name':key,'source':'https://github.com/KayKit-Game-Assets/'+source.name.removesuffix('-main'),'license':'CC0-1.0','models':sum(k.startswith(key+'/') for k in catalog)})
p=V/'kenney-particles';shutil.copytree(p,OUT/'particles',dirs_exist_ok=True)
packs += [{'name':'particles','source':'https://kenney.nl/assets/particle-pack','license':'CC0-1.0'}, {'name':'quaternius-monsters','source':'https://opengameart.org/content/lowpoly-animated-monsters','license':'CC0-1.0'}]
(OUT/'catalog.json').write_text(json.dumps(catalog,indent=2))
existing=json.loads((OUT/'sources.json').read_text()) if (OUT/'sources.json').exists() else []
for record in existing:
 if not any(p['name']==record['name'] for p in packs):packs.append(record)
(OUT/'sources.json').write_text(json.dumps(packs,indent=2))
(OUT/'LICENSES.md').write_text('# Public asset expansion\n\nAll new models and particle textures: CC0-1.0. Original authors Kay Lousberg (KayKit), Kenney, Quaternius. Source URLs in sources.json; original license texts included in each pack. Models are authored third-party assets; only transforms, animation adaptation and scene assembly are performed here.\n')
print('Catalog:',len(catalog))
