"""Real multi-process ENet integration test; uses an isolated UDP port and test saves."""
import subprocess,time,sys,argparse
from pathlib import Path
import os,shutil
ROOT=Path(__file__).resolve().parents[1]
GODOT=Path(os.environ.get('GODOT') or shutil.which('godot') or ROOT/'tools/Godot.app/Contents/MacOS/Godot')
PORT='24671'
parser=argparse.ArgumentParser()
parser.add_argument('--pack',type=Path,help='Verify an exported PCK instead of the source project')
pack=parser.parse_args().pack
pack_args=['--main-pack',str(pack.resolve())] if pack else []
processes=[]
files=[]
def launch(name,extra):
 pth=ROOT/'art'/('network-'+name+'.log');out=pth.open('w');files.append(out)
 p=subprocess.Popen([str(GODOT),'--headless','--path',str(ROOT),*pack_args,'--','--net-test','--port='+PORT,*extra],stdout=out,stderr=subprocess.STDOUT)
 processes.append((name,p,pth));return p,pth
try:
 server,log=launch('server',['--server'])
 deadline=time.monotonic()+80
 while 'REALM_READY' not in log.read_text():
  if server.poll() is not None or time.monotonic()>deadline:raise RuntimeError('server did not start')
  time.sleep(.2)
 launch('alpha',['--join=127.0.0.1','--name=Alpha'])
 launch('beta',['--join=127.0.0.1','--name=Beta'])
 late=False
 while server.poll() is None:
  if not late and 'NET_WAIT_LATE' in log.read_text():
   launch('late',['--join=127.0.0.1','--name=Late']);late=True
  if time.monotonic()>deadline:raise RuntimeError('network test timed out')
  time.sleep(.2)
 failed=False
 for name,p,pth in processes:
  code=p.wait(timeout=8)
  contents=pth.read_text()
  result=[line for line in contents.splitlines() if 'RESULT:' in line or 'ERROR' in line or 'FAIL:' in line]
  print(name,'exit',code,'\n'+'\n'.join(result))
  failed|=code!=0 or 'SCRIPT ERROR' in contents or 'NET FAIL' in contents
 sys.exit(1 if failed else 0)
finally:
 for _,p,_ in processes:
  if p.poll() is None:p.terminate()
 for _,p,_ in processes:
  try:p.wait(timeout=4)
  except subprocess.TimeoutExpired:p.kill();p.wait()
 for file in files:file.close()
