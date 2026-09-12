"""Retrieve Quaternius' public CC0 Ultimate Monsters glTF models."""
import urllib.request,re,json,concurrent.futures
from pathlib import Path
root=Path(__file__).resolve().parents[1]/'assets/vendor/ultimate-monsters';root.mkdir(exist_ok=True)
id='1sOXLt5U3ofaujPlQRL11s4ub2UsqN8V8'
s=urllib.request.urlopen('https://drive.google.com/drive/folders/'+id).read().decode();s=re.sub(r'\\x([0-9a-fA-F]{2})',lambda m:chr(int(m[1],16)),s)
files=re.findall(r'\["([a-zA-Z0-9_-]{20,})",\["'+id+r'"\],"([^"]+)"',s)
def fetch(item):
 fid,name=item
 data=urllib.request.urlopen('https://drive.usercontent.google.com/download?id='+fid+'&export=download',timeout=120).read()
 if name.endswith('.gltf'):json.loads(data)
 (root/name).write_bytes(data);print(name,len(data),flush=True)
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:list(pool.map(fetch,files))
(root/'LICENSE.txt').write_text('Quaternius Ultimate Monsters — CC0 1.0\nhttps://quaternius.com/packs/ultimatemonsters.html\nhttps://creativecommons.org/publicdomain/zero/1.0/\n')
(root/'sources.json').write_text(json.dumps({'source':'https://quaternius.com/packs/ultimatemonsters.html','folder':'https://drive.google.com/drive/folders/'+id,'files':files},indent=2))
