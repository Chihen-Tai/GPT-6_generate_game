"""Create Blender-authored hero props and the assembled, editable village scene."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
import build_assets as a
import bpy
import json
import math
from mathutils import Vector

a.materials()


def lathe(name,profile,material,parent,n=64):
    vertices=[];faces=[]
    for r,y in profile:
        for i in range(n):
            angle=i*math.tau/n
            vertices.append((math.cos(angle)*r,y,math.sin(angle)*r))
    for j in range(len(profile)-1):
        for i in range(n):
            p=j*n+i;q=j*n+(i+1)%n
            faces.append((p,p+n,q+n,q))
    return a.mesh(name,vertices,faces,material,parent)


def fountain():
    a.new_asset();r=a.empty('Fountain')
    lathe('Octagonal stepped plinth',[(0,0),(3.25,0),(3.25,.16),(3.07,.23),(3.07,.31),(2.86,.31),(2.86,.44),(0,.44)],'cut_stone',r,64)
    lathe('Carved basin',[(2.48,.32),(2.74,.36),(2.8,.62),(2.74,.82),(2.56,.82),(2.48,.69),(2.48,.46)],'limestone',r)
    for y,rr in [(.37,2.75),(.76,2.75)]:a.ring('Basin moulding',(0,y,0),rr,.048,'cut_stone',r)
    lathe('Turned central pedestal',[(.6,.4),(.6,.59),(.43,.63),(.28,.85),(.22,1.49),(.38,1.65),(.39,1.76)],'limestone',r)
    lathe('Upper fluted bowl',[(.3,1.64),(.7,1.72),(1.15,1.99),(1.29,2.12),(1.26,2.27),(1.13,2.27),(.81,2.0),(.31,1.86)],'limestone',r)
    a.ring('Gilt upper rim',(0,2.25,0),1.26,.029,'gold',r)
    lathe('Spire pedestal',[(.17,1.88),(.22,2.28),(.14,2.47),(.12,2.98)],'cut_stone',r)
    a.sun('Solar relic',(0,3.53,0),.62,'gold',r)
    for i in range(16):
        angle=i*math.tau/16
        x=math.cos(angle);z=math.sin(angle)
        a.tube('Basin carved leaf',[(x*2.76,.43,z*2.76),(x*2.81,.61,z*2.81),(x*2.73,.72,z*2.73)],.027,'gold_shadow',r)
    a.finish('sunwell_fountain')


def column():
    a.new_asset();r=a.empty('Column')
    a.box('Column plinth',(0,.16,0),(1.55,.32,1.55),'cut_stone',r,.05)
    lathe('Attic base',[(.71,.31),(.71,.42),(.56,.53),(.53,.63),(.49,.71)],'limestone',r)
    a.loft('Tapered marble shaft',[(.6,.47,.47,0,0),(5.45,.39,.39,0,0)],'limestone',r,n=48)
    for i in range(16):
        angle=i*math.tau/16
        a.tube('Column fluting',[(math.cos(angle)*.473,.79,math.sin(angle)*.473),(math.cos(angle)*.397,5.24,math.sin(angle)*.397)],.026,'cut_stone',r,resolution=2)
    for y,rr in [(.67,.51),(5.37,.44),(5.5,.48)]:a.ring('Capital moulding',(0,y,0),rr,.054,'cut_stone',r)
    for i in range(12):
        angle=i*math.tau/12
        direction=Vector((math.cos(angle),0,math.sin(angle)))
        points=[]
        for j in range(6):
            t=j/5
            p=direction*(.42+.25*math.sin(t*math.pi/2))+Vector((0,5.43+t*.58,0))
            points.append(tuple(p))
        a.tube('Acanthus capital leaf',points,.055,'limestone',r,radii=[.6,1,1.1,1,.7,.25],resolution=2)
    a.box('Abacus',(0,6.10,0),(1.42,.19,1.42),'cut_stone',r,.036)
    a.finish('sanctuary_column')


def shield():
    a.new_asset();r=a.empty('Sunshield')
    outline=[(0,.43),(.22,.40),(.34,.28),(.32,-.04),(.21,-.26),(0,-.44),(-.21,-.26),(-.32,-.04),(-.34,.28),(-.22,.4)]
    vs=[(0,0,-.11)]+[(x,y,-.01) for x,y in outline]
    fs=[(0,i+1,(i+1)%len(outline)+1) for i in range(len(outline))]
    o=a.mesh('Convex heater shield',vs,fs,'teal_cloth',r)
    m=o.modifiers.new('Steel backing','SOLIDIFY');m.thickness=.024
    points=[(x,y,-.02) for x,y in outline+[outline[0]]]
    a.tube('Rolled gilt shield rim',points,.022,'gold',r)
    a.sun('Heraldic dawn',(0,.065,-.125),.135,'gold',r)
    for x,y in outline:a.ellipsoid('Border rivet',(x*.91,y*.91,-.045),(.023,.023,.018),'gold',r,12,8)
    a.tube('Leather hand strap',[(-.12,.05,.04),(0,.05,.10),(.12,.05,.04)],.03,'leather',r)
    a.finish('sunshield')


def grass():
    a.new_asset();r=a.empty('GrassTuft')
    vertices=[];faces=[]
    for i in range(12):
        angle=i*2.39996
        radius=.025+(i%4)*.045
        height=.26+(i%5)*.07
        base=Vector((math.cos(angle)*radius,0,math.sin(angle)*radius))
        side=Vector((-math.sin(angle),0,math.cos(angle)))
        direction=Vector((math.cos(angle),0,math.sin(angle)))
        start=len(vertices)
        for j in range(4):
            t=j/3
            p=base+Vector((0,height*t,0))+direction*(t*t*.17)
            width=.019*(1-t)**.65
            vertices.extend([tuple(p-side*width),tuple(p+side*width)])
        for j in range(3):
            k=start+j*2;faces.append((k,k+1,k+3,k+2))
    a.mesh('Curved individual meadow blades',vertices,faces,'leaf_green',r)
    a.finish('grass_tuft')


fountain();column();shield();grass()
manifest_path=a.OUTPUT/'asset_manifest.json'
manifest=json.loads(manifest_path.read_text())
names={item['asset'] for item in a.REPORT}
manifest_path.write_text(json.dumps([m for m in manifest if m['asset'] not in names]+a.REPORT,indent=2))

# A Blender scene assembled from real linked asset collections, using the same
# spatial layout as the game. Collection instances keep the source compact.
a.new_asset()
collections={}
def instance(asset,pos=(0,0,0),yaw=0,scale=(1,1,1)):
    if asset not in collections:
        with bpy.data.libraries.load(str(a.SOURCE/(asset+'.blend')),link=False) as (src,dst):
            dst.collections=[src.collections[0]]
        collection=dst.collections[0]
        collection.name='ASSET_'+asset
        collections[asset]=collection
    o=bpy.data.objects.new(asset,None)
    o.instance_type='COLLECTION';o.instance_collection=collections[asset]
    bpy.context.collection.objects.link(o)
    o.location=a.V(pos)
    o.rotation_euler.z=yaw
    o.scale=(scale[0],scale[2],scale[1])
    return o

for pos,yaw,w,d in [((-13,0,17),-math.pi/2,7,5.5),((13,0,19),math.pi/2,7,5.5),((-14,0,2),-math.pi/2,8,6.4),((14,0,2),math.pi/2,7.5,6),((-13,0,-15),-math.pi/2,7,6),((14,0,-16),math.pi/2,8,6),((-27,0,25),-.2,6,5),((28,0,26),.3,6.5,5)]:
    instance('cottage',pos,yaw,(w/7,1,d/6))
for x in [-13,13]:
    instance('castle_tower',(x,0,-49),0,(1,1,1))
    instance('castle_tower',(x,0,-75),0,(1,1.2,1))
    a.box('Curtain wall',(x,4.2,-62),(1.7,8.4,25),'limestone')
for z in [-49,-75]:instance('castle_gate',(0,0,z))
for pos in [(-7,0,30),(8,0,30),(-7,0,-8),(7,0,-8),(-25,0,10),(25,0,11)]:instance('blossom_tree',pos)
for i in range(42):
    s=-1 if i%2 else 1
    x=s*(31+(i%5)*6);z=39-(i//2)*6
    instance('golden_oak' if i%3 else 'pine_tree',(x,0,z),i*2.4,(1.2,1.2,1.2))
instance('sunwell_fountain',(0,0,11))
instance('traveler',(4,0,30))
instance('horse',(23,0,36),-.4)
for x,z in [(-4.9,18),(-7.9,17),(6.7,21),(7.8,1.8),(-6.2,-4),(21,33),(7,29),(4.6,-44)]:instance('villager',(x,0,z))
a.box('Ground',(0,-.16,-20),(150,.3,210),'leaf_green',edge=0)
a.box('King road',(0,.01,-25),(6.5,.025,140),'cut_stone',edge=0)
for x in range(-8,9):
    for z in range(-7,30):
        if abs(x)>3 and z>20:continue
        a.box('Village paving',(x*.91+(z%2)*.42,.045,z*.95),(.85,.08,.89),'limestone',edge=.02)

scene=bpy.context.scene
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
scene.render.resolution_x=1600;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.42,.61,.67,1)
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.6
data=bpy.data.lights.new('Afternoon sun','SUN');data.energy=2.2;data.angle=.12
sun=bpy.data.objects.new('Afternoon sun',data);bpy.context.collection.objects.link(sun)
sun.rotation_euler=(.56,-.35,-.62)
bpy.ops.object.camera_add(location=a.V((35,21,47)))
camera=bpy.context.object
camera.rotation_euler=(a.V((-1,3,-8))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.lens=35;scene.camera=camera
scene.view_settings.view_transform='AgX'
scene.render.filepath=str(a.ROOT/'screenshots'/'blender-village.png')
scene['description']='Editable village and castle scene assembled from authored Blender assets; layout matches the Godot world.'
bpy.ops.wm.save_as_mainfile(filepath=str(a.SOURCE/'aurelia_village.blend'))
bpy.ops.render.render(write_still=True)
print('BLENDER SCENE COMPLETE',flush=True)
