"""Fetch the first free upload exposed by a creator's zero-price download page."""
import urllib.request,urllib.parse,http.cookiejar,re,json,zipfile,io,sys
from pathlib import Path
url=sys.argv[1];out=Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=True)
op=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
def token(s):return re.search(r'name="csrf_token" value="([^"]+)',s).group(1)
def post(u,data,referer):return json.load(op.open(urllib.request.Request(u,data=urllib.parse.urlencode(data).encode(),headers={'Referer':referer,'X-Requested-With':'XMLHttpRequest'}),timeout=60))
s=op.open(url).read().decode();j=post(url+'/download_url',{'csrf_token':token(s)},url)
page_url=j['url'];page=op.open(page_url).read().decode()
upload=re.search(r'data-upload_id="(\d+)"',page).group(1)
j=post(url+'/file/'+upload,{'csrf_token':token(page)},page_url)
data=op.open(j['url'],timeout=120).read()
zipfile.ZipFile(io.BytesIO(data)).extractall(out)
(out/'download-source.json').write_text(json.dumps({'source':url,'upload':upload,'bytes':len(data)},indent=2))
print(url,len(data),flush=True)
