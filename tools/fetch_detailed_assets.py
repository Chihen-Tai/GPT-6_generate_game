"""Download public Poly Haven glTF files and their declared dependencies."""
from pathlib import Path
import urllib.request,urllib.parse,json,concurrent.futures,hashlib
ROOT=Path(__file__).resolve().parents[1]
def fetch(asset):
 out=ROOT/'assets/vendor/detailed'/asset;out.mkdir(parents=True,exist_ok=True)
 url=f'https://dl.polyhaven.org/file/ph-assets/Models/gltf/2k/{asset}/{asset}_2k.gltf'
 raw=urllib.request.urlopen(url,timeout=60).read();j=json.loads(raw)
 (out/(asset+'.gltf')).write_bytes(raw)
 dependencies=[x['uri'] for x in j.get('buffers',[])+j.get('images',[]) if 'uri' in x]
 def download(uri):
  target=out/uri;target.parent.mkdir(parents=True,exist_ok=True)
  source=urllib.parse.urljoin(url,uri) if uri.endswith('.bin') else f'https://dl.polyhaven.org/file/ph-assets/Models/jpg/2k/{asset}/'+Path(uri).name
  data=urllib.request.urlopen(source,timeout=60).read();target.write_bytes(data)
  return {'file':uri,'url':source,'sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data)}
 with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:records=list(pool.map(download,dependencies))
 (out/'sources.json').write_text(json.dumps({'source':'https://polyhaven.com/a/'+asset,'license':'CC0-1.0','files':records},indent=2))
 (out/'LICENSE.txt').write_text('Poly Haven '+asset+' / CC0-1.0\nhttps://polyhaven.com/a/'+asset+'\nhttps://polyhaven.com/license\n')
 print(asset,len(dependencies),flush=True)
fetch('modular_fort_01')
