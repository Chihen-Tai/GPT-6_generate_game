"""32 real lightweight ENet clients plus a rejected 33rd. Not a GPU/load benchmark."""
import subprocess,time,sys
from pathlib import Path
import os,shutil
ROOT=Path(__file__).resolve().parents[1];GODOT=Path(os.environ.get('GODOT') or shutil.which('godot') or ROOT/'tools/Godot.app/Contents/MacOS/Godot')
flag=ROOT/'art/capacity-stop.flag';flag.unlink(missing_ok=True)
ps=[];files=[]
def launch(name,args):
 log=ROOT/'art'/('capacity-'+name+'.log');f=log.open('w');files.append(f)
 p=subprocess.Popen([str(GODOT),'--headless','--path',str(ROOT),*args],stdout=f,stderr=subprocess.STDOUT);ps.append((name,p,log));return p,log
try:
 server,log=launch('server',['--','--server','--net-test','--capacity-server','--port=24672'])
 deadline=time.monotonic()+65
 while 'REALM_READY' not in log.read_text():
  if server.poll() is not None or time.monotonic()>deadline:raise RuntimeError('server startup failed')
  time.sleep(.1)
 for i in range(32):launch(str(i+1),['--script','res://tests/capacity_client.gd','--','--port=24672','--name=Guest'+str(i+1)])
 while 'count=32' not in log.read_text():
  if server.poll() is not None or time.monotonic()>deadline:raise RuntimeError('32-client registration timed out')
  if any('SCRIPT ERROR' in output.read_text() for _,_,output in ps[1:]):raise RuntimeError('client startup error')
  time.sleep(.2)
 while not all('CAPACITY_VERIFIED' in output.read_text() for _,_,output in ps[1:]):
  if time.monotonic()>deadline:raise RuntimeError('32-client snapshot delivery timed out')
  if any(p.poll() is not None for _,p,_ in ps[1:]):raise RuntimeError('a client exited before verification')
  time.sleep(.2)
 overflow,overflow_log=launch('overflow',['--script','res://tests/capacity_client.gd','--','--port=24672','--overflow'])
 if overflow.wait(timeout=10)!=0 or 'CAPACITY_REJECTED' not in overflow_log.read_text():raise RuntimeError('33rd connection was not rejected')
 flag.write_text('done')
 for name,p,output in ps[1:]:
  code=p.wait(timeout=12)
  text=output.read_text()
  if code!=0 or 'ERROR' in text:raise RuntimeError(name+' failed: '+text[-1200:])
 print('CAPACITY RESULT: 32 clients each saw 32 actors and received at least five snapshots; client 33 rejected.')
 print('This validates connection capacity and membership, not 32-player combat performance.')
finally:
 for _,p,_ in ps:
  if p.poll() is None:p.terminate()
 for _,p,_ in ps:
  try:p.wait(timeout=5)
  except subprocess.TimeoutExpired:p.kill();p.wait()
 for f in files:f.close()
 flag.unlink(missing_ok=True)
