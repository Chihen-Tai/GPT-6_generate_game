"""Download only official Godot 4.6 Windows x64 release templates using ZIP ranges."""
import io,json,urllib.request,zipfile,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
with urllib.request.urlopen('https://api.github.com/repos/godotengine/godot-builds/releases/tags/4.6-stable',timeout=30) as response:
 metadata=json.load(response)
asset=next(a for a in metadata['assets'] if a['name']=='Godot_v4.6-stable_export_templates.tpz')
class RemoteZip(io.RawIOBase):
 def __init__(self):self.pos=0;self.size=asset['size'];self.url=asset['browser_download_url']
 def seekable(self):return True
 def readable(self):return True
 def tell(self):return self.pos
 def seek(self,offset,whence=0):
  self.pos=offset if whence==0 else self.pos+offset if whence==1 else self.size+offset
  return self.pos
 def read(self,n=-1):
  if n<0:n=self.size-self.pos
  n=min(n,self.size-self.pos)
  if n<=0:return b''
  req=urllib.request.Request(self.url,headers={'Range':f'bytes={self.pos}-{self.pos+n-1}','User-Agent':'Aurelia-build'})
  with urllib.request.urlopen(req,timeout=120) as response:
   if response.status!=206:raise RuntimeError(f'Range download unavailable: {response.status}')
   result=response.read()
  if len(result)!=n:raise RuntimeError(f'Expected {n} bytes, got {len(result)}')
  self.pos+=n
  return result
with zipfile.ZipFile(RemoteZip()) as archive:
 for info in archive.infolist():
  if 'windows' in info.filename or '.dll' in info.filename:print(info.filename,info.file_size,flush=True)
 selected=[i for i in archive.infolist() if 'windows_release_x86_64' in i.filename]
 dest=ROOT/'tools/export_templates/4.6.stable'
 dest.mkdir(parents=True,exist_ok=True)
 records=[]
 for info in selected:
  print('Downloading',info.filename,flush=True)
  data=archive.read(info)
  target=dest/Path(info.filename).name
  target.write_bytes(data)
  records.append({'file':target.name,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()})
 (dest/'source.json').write_text(json.dumps({'source':asset['browser_download_url'],'archive_sha256':asset.get('digest'),'files':records},indent=2))
 for original,target in [('LICENSE.txt','GODOT-LICENSE.txt'),('COPYRIGHT.txt','GODOT-COPYRIGHT.txt')]:
  with urllib.request.urlopen('https://raw.githubusercontent.com/godotengine/godot/4.6-stable/'+original,timeout=30) as response:
   (dest/target).write_bytes(response.read())
