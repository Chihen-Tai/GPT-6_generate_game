"""Capture native Godot UI and two actual clients sharing one staged Boss encounter."""
import subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
GODOT=ROOT/'tools/Godot.app/Contents/MacOS/Godot'
processes=[]
files=[]
def launch(name,args):
 log=ROOT/'art'/('network-review-'+name+'.log')
 output=log.open('w');files.append(output)
 p=subprocess.Popen([str(GODOT),'--path',str(ROOT),*args],stdout=output,stderr=subprocess.STDOUT)
 processes.append(p)
 return p,log
try:
 menu,_=launch('menu',['--script','tests/network_menu_review.gd','--','--net-test','--capacity-server'])
 if menu.wait(timeout=45)!=0:raise RuntimeError('menu capture failed')
 common=['--','--net-test','--capacity-server','--network-review','--port=24673']
 server,log=launch('server',['--headless',*common,'--server'])
 deadline=time.monotonic()+30
 while 'REALM_READY' not in log.read_text():
  if server.poll() is not None or time.monotonic()>deadline:raise RuntimeError('server failed')
  time.sleep(.2)
 primary,_=launch('primary',[*common,'--join=127.0.0.1','--name=青葉'])
 secondary,_=launch('secondary',['--headless',*common,'--join=127.0.0.1','--name=晨星'])
 for p in [primary,secondary,server]:
  if p.wait(timeout=45)!=0:raise RuntimeError('capture process failed')
 print('NETWORK CAPTURE COMPLETE')
finally:
 for p in processes:
  if p.poll() is None:p.terminate()
 for p in processes:
  try:p.wait(timeout=4)
  except subprocess.TimeoutExpired:p.kill();p.wait()
 for f in files:f.close()
