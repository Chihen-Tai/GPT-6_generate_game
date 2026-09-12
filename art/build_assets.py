"""Aurelia's authored Blender asset library. Blender 5.2, metres, Godot-facing axes.

Run with Blender --background --factory-startup --python art/build_assets.py
Every asset is saved as an editable .blend and exported to embedded-material GLB.
Game coordinates throughout: X right, Y up, -Z forward. V() maps to Blender.
"""
import bpy
import math
import random
import json
import numpy as np
from pathlib import Path
from mathutils import Vector
from mathutils.noise import noise_vector

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'art' / 'blender'
OUTPUT = ROOT / 'assets' / 'models'
random.seed(2718)
PI = math.pi
TAU = math.tau
M = {}
REPORT = []


def V(p):
    return Vector((p[0], -p[2], p[1]))


def rgb(code):
    code = code.lstrip('#')
    srgb = [int(code[i:i+2], 16) / 255 for i in (0, 2, 4)]
    return tuple(v / 12.92 if v < .04045 else ((v + .055) / 1.055) ** 2.4 for v in srgb) + (1,)


def mat(name, color, metal=0, rough=.65):
    m = bpy.data.materials.new(name)
    m.diffuse_color = rgb(color)
    m.use_nodes = True
    bs = m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value = rgb(color)
    bs.inputs['Metallic'].default_value = metal
    bs.inputs['Roughness'].default_value = rough
    M[name] = m
    return m


def materials():
    for args in [
        ('limestone', 'd5c7ac', 0, .88), ('cut_stone', 'bcab90', 0, .87),
        ('mortar', '847f6f', 0, .95), ('plaster', 'e4d8bc', 0, .88),
        ('timber', '584233', 0, .79), ('wood_edge', '80664b', 0, .77),
        ('oak_planks', '997a50', 0, .8), ('slate', '416769', .08, .56),
        ('slate_light', '577b7b', .08, .55), ('slate_dark', '385555', .08, .6),
        ('gold', 'c8a362', .78, .27), ('gold_shadow', '92733c', .65, .38),
        ('steel', 'afbfc1', .8, .28), ('steel_edge', 'dae1db', .86, .22),
        ('steel_dark', '576b71', .72, .4), ('chainmail', '596363', .68, .56),
        ('leather', '493b31', 0, .7), ('leather_light', '79533b', 0, .7),
        ('teal_cloth', '245458', 0, .92), ('teal_light', '417576', 0, .9),
        ('ivory_cloth', 'd6c9ac', 0, .93), ('wine_cloth', '814e45', 0, .9),
        ('skin', 'd6a581', 0, .65), ('skin_shadow', 'ad785e', 0, .72),
        ('hair', '52372c', 0, .79), ('hair_highlight', '80583c', 0, .75),
        ('eye', '334c48', 0, .3), ('eye_white', 'd9cdb4', 0, .34),
        ('lips', 'a46f5c', 0, .65), ('glass', '598c8b', .32, .17),
        ('lamp', 'f2c781', .15, .35), ('leaf_gold', 'baa45e', 0, .82),
        ('leaf_light', 'd7c07e', 0, .85), ('leaf_green', '7b8e51', 0, .9),
        ('leaf_pink', 'd0a493', 0, .9), ('bark', '655744', 0, .94),
        ('horse', 'a5805e', 0, .84), ('horse_light', 'd8bd93', 0, .8),
        ('mane', 'd5c4a7', 0, .86), ('hoof', '43443e', 0, .72),
        ('rock', '859184', 0, .95), ('rock_light', 'a4ad9d', 0, .96),
        ('snow', 'dbe1d3', 0, .95), ('purple_cloth', '6d758b', 0, .92)
    ]:
        mat(*args)
    # Packed PBR colour maps survive the GLB export (unlike procedural shader nodes).
    for name in ['limestone','cut_stone','plaster','timber','wood_edge','oak_planks','slate','slate_light','slate_dark','leather','leather_light','teal_cloth','wine_cloth','ivory_cloth','chainmail','bark']:
        material=M[name]
        size=256
        yy,xx=np.mgrid[0:size,0:size].astype(np.float32)/size
        rng=np.random.default_rng(sum(ord(c) for c in name))
        grain=rng.uniform(-1,1,(size,size))
        if name in ['timber','wood_edge','oak_planks','bark']:
            pattern=.85+.08*np.sin(xx*170+np.sin(yy*8)*2+np.sin(xx*33)*2)+grain*.035
        elif 'cloth' in name or name=='chainmail':
            pattern=.90+.035*np.sin(xx*TAU*90)+.035*np.sin(yy*TAU*90)+grain*.025
        else:
            pattern=.90+grain*.035+.04*np.sin(xx*35+np.sin(yy*14))*np.cos(yy*29)
        pixels=np.ones((size,size,4),dtype=np.float32)
        linear=np.array(material.diffuse_color[:3])
        color=np.where(linear<=.0031308,linear*12.92,1.055*np.power(linear,1/2.4)-.055)
        pixels[:,:,:3]=pattern[:,:,None]*color[None,None,:]
        image=bpy.data.images.new(name+'_color',size,size,alpha=True)
        image.pixels.foreach_set(pixels.ravel())
        image.pack()
        nodes=material.node_tree.nodes
        tex=nodes.new('ShaderNodeTexImage');tex.image=image
        bs=nodes.get('Principled BSDF')
        material.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])


def empty(name, pos=(0, 0, 0), parent=None):
    o = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(o)
    o.parent = parent
    o.location = V(pos)
    return o


def assign(obj, material, parent=None, smooth=True):
    obj.data.materials.append(M[material])
    obj.parent = parent
    if smooth and obj.type == 'MESH':
        for p in obj.data.polygons:
            p.use_smooth = True
    return obj


def mesh(name, vertices, faces, material, parent=None, smooth=True):
    data = bpy.data.meshes.new(name)
    data.from_pydata([V(v) for v in vertices], [], faces)
    data.update()
    o = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(o)
    assign(o, material, parent, smooth)
    return o


def bevel(o, amount=.035, segments=2):
    m = o.modifiers.new('Crafted rounded edges', 'BEVEL')
    m.width = amount
    m.segments = segments
    m = o.modifiers.new('Weighted corner normals', 'WEIGHTED_NORMAL')
    m.keep_sharp = True
    m.weight = 30
    return o


def box(name, p, size, material, parent=None, edge=.025):
    bpy.ops.mesh.primitive_cube_add(size=1)
    o=bpy.context.object
    o.name=name
    o.location=V(p)
    o.scale=(size[0],size[2],size[1])
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    assign(o,material,parent,False)
    if edge:
        bevel(o,min(edge,min(size)/3),2)
    return o


def ellipsoid(name, p, size, material, parent=None, segments=24, rings=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,radius=1)
    o=bpy.context.object
    o.name=name
    o.location=V(p)
    o.scale=(size[0]/2,size[2]/2,size[1]/2)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return assign(o,material,parent)


def tube(name, points, radius, material, parent=None, radii=None, resolution=3):
    c=bpy.data.curves.new(name,'CURVE')
    c.dimensions='3D'
    c.resolution_u=5
    c.bevel_depth=radius
    c.bevel_resolution=resolution
    c.resolution_u=5
    s=c.splines.new('BEZIER')
    s.bezier_points.add(len(points)-1)
    for i,p in enumerate(points):
        q=s.bezier_points[i]
        q.co=V(p)
        q.handle_left_type='AUTO'
        q.handle_right_type='AUTO'
        q.radius=radii[i] if radii else 1
    o=bpy.data.objects.new(name,c)
    bpy.context.collection.objects.link(o)
    c.materials.append(M[material])
    o.parent=parent
    return o


def ring(name, p, radius, minor, material, parent=None, axis='y'):
    points=[]
    for i in range(25):
        a=i*TAU/24
        d=(math.cos(a)*radius,0,math.sin(a)*radius) if axis=='y' else (math.cos(a)*radius,math.sin(a)*radius,0)
        points.append(tuple(p[j]+d[j] for j in range(3)))
    o=tube(name,points,minor,material,parent,resolution=1)
    o.data.resolution_u=2
    return o


def loft(name, levels, material, parent=None, n=32, pointed=0):
    # levels: y, x-radius, z-radius, x-offset, z-offset
    levels=sorted(levels,key=lambda level:level[0])
    vs=[]
    for y,rx,rz,cx,cz in levels:
        for i in range(n):
            a=i*TAU/n
            ridge=pointed*max(0,-math.sin(a))**8
            vs.append((cx+rx*math.cos(a),y,cz+rz*math.sin(a)-ridge))
    fs=[]
    for j in range(len(levels)-1):
        for i in range(n):
            a=j*n+i;b=j*n+(i+1)%n
            fs.append((a,a+n,b+n,b))
    fs.append(tuple(range(n)))
    fs.append(tuple((len(levels)-1)*n+i for i in range(n-1,-1,-1)))
    o=mesh(name,vs,fs,material,parent)
    return bevel(o,.006,2)


def sun(name,p,r,material,parent=None):
    ring(name+' circumference',p,r,.009,material,parent,'z')
    ring(name+' inner filigree',p,r*.65,.005,material,parent,'z')
    for i in range(12):
        a=i*TAU/12
        ps=[(p[0]+math.cos(a)*r*f,p[1]+math.sin(a)*r*f,p[2]) for f in [1.13,1.36]]
        tube(name+' ray',ps,.007,material,parent,resolution=1)
    tube(name+' sword',[(p[0],p[1]-r*.5,p[2]),(p[0],p[1]+r*.48,p[2])],.009,material,parent)
    tube(name+' hilt',[(p[0]-r*.25,p[1]-r*.15,p[2]),(p[0]+r*.25,p[1]-r*.15,p[2])],.007,material,parent)


def new_asset():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)


def finish(name):
    # Convert and join geometry by articulated pivot and material. This retains
    # hand-authored parts while reducing hundreds of decorations to a few draws.
    bpy.ops.object.select_all(action='DESELECT')
    for o in list(bpy.context.scene.objects):
        if o.type in ('CURVE','FONT','MESH'):
            o.select_set(True)
    if bpy.context.selected_objects:
        bpy.context.view_layer.objects.active=bpy.context.selected_objects[0]
        bpy.ops.object.convert(target='MESH')
    groups={}
    for o in list(bpy.context.scene.objects):
        if o.type=='MESH':
            key=(o.parent.name if o.parent else '',o.data.materials[0].name if o.data.materials else '')
            groups.setdefault(key,[]).append(o)
    for (parent,material),objects in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for o in objects:o.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        if len(objects)>1:bpy.ops.object.join()
        objects[0].name=(parent+'_' if parent else '')+material
        if name=='horse' and parent=='HorseRig' and material=='horse':
            remesh=objects[0].modifiers.new('Unified sculpted anatomy','REMESH')
            remesh.mode='VOXEL';remesh.voxel_size=.019;remesh.use_smooth_shade=True
            bpy.ops.object.modifier_apply(modifier=remesh.name)
            smooth=objects[0].modifiers.new('Smoothed muscle transitions','SMOOTH')
            smooth.factor=.65;smooth.iterations=5
            bpy.ops.object.modifier_apply(modifier=smooth.name)
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.uv.cube_project(cube_size=1.0)
        bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.object.select_all(action='SELECT')
    verts=sum(len(o.data.vertices) for o in bpy.context.scene.objects if o.type=='MESH')
    triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in bpy.context.scene.objects if o.type=='MESH')
    bpy.context.scene['asset_name']=name
    bpy.context.scene['units']='metres; glTF +Y up; forward -Z'
    bpy.context.scene['author']='Aurelia original Blender asset pipeline'
    bpy.context.scene.unit_settings.system='METRIC'
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/(name+'.blend')))
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT/(name+'.glb')),export_format='GLB',export_apply=True,export_yup=True,export_cameras=False,export_lights=False,export_animations=False)
    REPORT.append({'asset':name,'vertices':verts,'triangles':triangles,'meshes':len([o for o in bpy.context.scene.objects if o.type=='MESH'])})
    print('ASSET_COMPLETE',name,verts,triangles,flush=True)


def make_sword():
    new_asset()
    root=empty('Sword')
    # A tapered diamond cross-section blade, with an actual fuller and gilt inlay.
    vs=[]
    for z,w,h in [(-.19,.071,.018),(-.33,.067,.021),(-1.03,.049,.016),(-1.33,0,.002)]:
        vs.extend([(-w,0,z),(0,h,z),(w,0,z),(0,-h,z)])
    fs=[]
    for j in range(3):
        for i in range(4):fs.append((j*4+i,j*4+(i+1)%4,(j+1)*4+(i+1)%4,(j+1)*4+i))
    mesh('Forged diamond blade',vs,fs,'steel_edge',root,False)
    tube('Central fuller',[(0,.022,-.31),(0,.019,-.83),(0,.016,-1.16)],.008,'steel_dark',root)
    tube('Swept quillons',[(-.28,.02,-.12),(-.17,0,-.22),(0,0,-.2),(.17,0,-.22),(.28,.02,-.12)],.033,'gold',root)
    loft('Leather grip',[(-.03,.045,.045,0,0),(.03,.045,.045,0,0)],'leather',root) # central handle below
    box('Grip core',(0,0,-.005),(.063,.061,.29),'leather',root,.02)
    for i in range(9):
        ring('Braided grip',(0,0,-.12+i*.028),.038,.008,'gold_shadow',root,'z')
    ellipsoid('Pommel',(0,0,.18),(.115,.1,.13),'gold',root)
    ellipsoid('Pommel gem',(0,-.043,.18),(.052,.017,.062),'glass',root)
    finish('dawn_sword')


def cape(parent,boss=False):
    root=empty('Cape',(0,1.51,.16),parent)
    vs=[];fs=[]
    def pos(u,v):
        width=.23+v*.19
        x=u*width
        y=-v*1.08
        z=.035+v*.18+math.sin(u*PI*3)*(.018+v*.035)+v*v*.12
        return (x,y,z)
    for j in range(25):
        for i in range(19):vs.append(pos(-1+2*i/18,j/24))
    for j in range(24):
        for i in range(18):
            a=j*19+i;fs.append((a,a+19,a+20,a+1))
    o=mesh('Tailored cloth folds',vs,fs,'wine_cloth' if boss else 'teal_cloth',root)
    solid=o.modifiers.new('Woven cloth thickness','SOLIDIFY');solid.thickness=.006
    for u in [-1,1]:tube('Embroidered border',[pos(u,j/24) for j in range(25)],.009,'gold',root)
    tube('Scalloped hem',[pos(-1+2*i/18,1) for i in range(19)],.009,'gold',root)
    sun('Cape heraldry',(0,-.49,.20),.105,'gold',root)
    return root


def face(parent):
    # Adult proportions: ~7.5 heads tall, jaw, cheeks, sockets, lids and lips.
    loft('Sculpted face',[(-.113,.054,.06,0,-.01),(-.085,.079,.072,0,-.014),(-.025,.096,.084,0,0),(.05,.092,.083,0,.009),(.105,.061,.059,0,.012)],'skin',parent,n=32)
    for s in [-1,1]:
        ellipsoid('Cheekbone',(s*.055,-.023,-.067),(.078,.049,.044),'skin',parent)
        ellipsoid('Ear',(s*.097,0,.003),(.029,.072,.038),'skin',parent)
        ellipsoid('Ear concha',(s*.108,.002,-.005),(.012,.037,.024),'skin_shadow',parent)
        ellipsoid('Eye white',(s*.04,.024,-.076),(.052,.024,.016),'eye_white',parent)
        ellipsoid('Iris',(s*.04,.024,-.085),(.019,.02,.007),'eye',parent)
        ellipsoid('Eye glint',(s*.037,.028,-.089),(.005,.006,.003),'eye_white',parent)
        tube('Upper eyelid',[(s*.015,.024,-.083),(s*.039,.038,-.084),(s*.066,.025,-.076)],.0045,'skin_shadow',parent)
        tube('Eyebrow',[(s*.014,.052,-.077),(s*.041,.058,-.078),(s*.068,.047,-.07)],.006,'hair',parent)
    ellipsoid('Nose bridge',(0,.005,-.087),(.028,.065,.028),'skin',parent)
    ellipsoid('Nose tip',(0,-.022,-.104),(.034,.027,.027),'skin',parent)
    tube('Cupid bow',[(-.033,-.056,-.077),(0,-.054,-.087),(.033,-.056,-.077)],.0055,'lips',parent)
    tube('Lower lip',[(-.028,-.06,-.078),(0,-.066,-.085),(.028,-.06,-.078)],.005,'skin_shadow',parent)
    ellipsoid('Hair cap',(0,.056,.021),(.201,.15,.178),'hair',parent)
    for i in range(26):
        a=i*TAU/26
        x=math.cos(a)*.085;z=math.sin(a)*.069
        tube('Combed hair lock',[(x*.35,.13,z*.35+.015),(x,.10,z+.015),(x*1.13,.025 if z>0 else .06,z*1.2+.015)],.012,'hair_highlight' if i%4==0 else 'hair',parent,radii=[.65,1,.12],resolution=2)


def make_human(name='traveler',civilian=False,boss=False):
    new_asset()
    root=empty('Rig')
    torso=empty('Torso',(0,1.05,0),root)
    cloth='wine_cloth' if boss else 'teal_cloth'
    armor='gold_shadow' if boss else 'steel'
    loft('Fitted torso',[(0,.18,.115,0,0),(.12,.205,.127,0,0),(.29,.265,.145,0,0),(.42,.247,.122,0,.01),(.49,.14,.093,0,.008)],'ivory_cloth' if civilian else 'chainmail',torso,n=32)
    if not civilian:
        loft('Peaked cuirass',[ (.065,.19,.127,0,-.008),(.16,.212,.14,0,-.008),(.31,.263,.149,0,-.006),(.41,.228,.127,0,0)],armor,torso,pointed=.024)
        for s in [-1,1]:
            tube('Chased breastplate edge',[(s*.17,.08,-.06),(s*.226,.27,-.095),(s*.205,.39,-.1),(s*.09,.43,-.094)],.012,'gold',torso)
        sun('Solar crest',(0,.28,-.189),.065,'gold',torso)
        for y in [.045,-.025,-.095]:
            loft('Overlapping fauld',[(y-.055,.206,.144,0,0),(y,.195,.131,0,0)],armor,torso)
        for s in [-1,1]:
            for j in range(3):
                o=ellipsoid('Segmented hip tasset',(s*.16,.9-j*.07,-.1),(.2,.14,.095),armor,root)
                tube('Tasset gold piping',[(s*.16-.079,.895-j*.07,-.14),(s*.16,.873-j*.07,-.156),(s*.16+.079,.895-j*.07,-.14)],.006,'gold',root)
    else:
        for j in range(6):ellipsoid('Tunic pewter button',(0,.07+j*.061,-.134),(.014,.014,.012),'gold',torso,12,8)
        for s in [-1,1]:
            tube('Linen collar',[(s*.02,.40,-.10),(s*.09,.49,-.075),(s*.15,.43,-.075)],.025,'ivory_cloth',torso)
    loft('Wide leather belt',[(-.018,.213,.144,0,0),(.035,.213,.144,0,0)],'leather',torso)
    box('Belt buckle',(0,.01,-.149),(.079,.065,.019),'gold',torso,.01)
    box('Buckle inset',(0,.01,-.161),(.047,.037,.009),'leather',torso,.008)
    for s in [-1,1]:
        ellipsoid('Belt pouch',(s*.23,.97,.03),(.12,.17,.093),'leather_light',root)
        box('Pouch flap',(s*.23,1.019,-.017),(.116,.075,.023),'leather',root,.015)
    # Pleated tunic, split for the legs.
    for s in [-1,1]:
        vs=[];fs=[]
        for j in range(9):
            v=j/8
            for i in range(10):
                u=i/9
                vs.append((s*(.015+u*(.19+v*.02)),1.02-v*.39,-.105-v*.035+math.sin(u*PI*4)*.013))
        for j in range(8):
            for i in range(9):
                a=j*10+i;fs.append((a,a+1,a+11,a+10))
        mesh('Divided tabard',vs,fs,cloth if not civilian else 'teal_cloth',root)
    head=empty('Head',(0,1.74,0),root)
    loft('Neck',[(-.255,.068,.064,0,0),(-.06,.057,.056,0,0)],'skin' if civilian else 'chainmail',head,n=20)
    if not civilian:
        loft('High fitted gorget',[(-.215,.096,.086,0,0),(-.15,.075,.072,0,0)],armor,head,n=28)
    if civilian:
        face(head)
    else:
        loft('Closed armet',[(-.11,.069,.071,0,-.008),(-.064,.099,.088,0,-.005),(.025,.112,.103,0,.008),(.096,.099,.087,0,.014),(.139,.02,.025,0,.022)],armor,head,n=40)
        # An inset dark visor surrounded by articulated brow and cheek plates.
        tube('Visor aperture',[(-.085,.006,-.074),(-.043,.013,-.099),(0,.014,-.108),(.043,.013,-.099),(.085,.006,-.074)],.008,'leather',head)
        tube('Visor brow',[(-.09,.03,-.08),(0,.047,-.112),(.09,.03,-.08)],.012,'gold',head)
        for s in [-1,1]:
            tube('Cheek plate',[(s*.077,-.03,-.078),(s*.053,-.09,-.086),(s*.02,-.109,-.072)],.011,'steel_edge',head)
            for j in range(4):
                tube('Breathing vent',[(s*(.027+j*.012),-.025,-.096+j*.003),(s*(.027+j*.012),-.052,-.092+j*.003)],.0032,'steel_dark',head,resolution=1)
            ellipsoid('Visor hinge',(s*.108,.011,-.002),(.016,.037,.037),'gold',head,16,12)
        tube('Median helmet ridge',[(0,-.079,-.102),(0,.04,-.117),(0,.147,.016),(0,.045,.10)],.009,'gold',head)
        # Swept crest: thin feather vanes, not a single capsule.
        for j in range(14):
            z=-.03+j*.012
            tube('Plumed crest',[(0,.128,z),(0,.25,z+.055),(0,.26-j*.006,z+.15)],.024,cloth,head,radii=[.35,1,.02],resolution=2)
        if boss:
            ring('Solar crown',(0,.15,.13),.29,.014,'gold',head,'z')
            for i in range(9):
                a=i*PI/8
                tube('Crown ray',[(math.cos(a)*.32,.15+math.sin(a)*.32,.13),(math.cos(a)*.43,.15+math.sin(a)*.43,.13)],.014,'gold',head,radii=[1,.02])
    for s in [-1,1]:
        arm=empty('ArmL' if s<0 else 'ArmR',(s*.292,1.5,0),root)
        loft('Upper arm',[(.025,.095,.096,0,0),(-.12,.078,.078,0,0),(-.27,.064,.067,0,0)],'ivory_cloth' if civilian else 'chainmail',arm,n=24)
        elbow=empty('Elbow',(0,-.28,0),arm)
        loft('Forearm',[(.025,.063,.063,0,0),(-.12,.062,.059,0,-.005),(-.27,.043,.046,0,-.01)],'ivory_cloth' if civilian else armor,elbow,n=24)
        if not civilian:
            # Three overlapping shoulder shells with gilt rims and fastening studs.
            for j in range(3):
                o=ellipsoid('Layered pauldron',(s*j*.012,-j*.06+.015,.012),(.244-j*.018,.17,.242-j*.013),armor,arm)
                tube('Pauldron engraved rim',[(-.10,-j*.06-.026,-.065),(0,-j*.06-.06,-.121),(.10,-j*.06-.026,-.065)],.007,'gold',arm)
            ellipsoid('Elbow fan',(s*.037,-.015,0),(.149,.128,.13),'steel_edge',elbow)
            tube('Vambrace ridge',[(0,-.032,-.063),(0,-.21,-.061)],.007,'gold',elbow)
            for y in [-.03,-.23]:ring('Vambrace cuff',(0,y,-.005),.062,.009,'gold',elbow)
        hand=empty('Hand',(0,-.31,-.015),elbow)
        ellipsoid('Palm',(0,0,0),(.088,.106,.056),'skin' if civilian else 'leather',hand)
        for f in range(4):
            tube('Articulated finger',[(-.031+f*.021,-.02,-.012),(-.031+f*.021,-.069,-.025),(-.031+f*.021,-.071,-.055)],.01,'skin' if civilian else 'steel',hand,radii=[1,.9,.65],resolution=2)
        tube('Thumb',[(s*.033,.007,0),(s*.052,-.023,-.028),(s*.042,-.045,-.051)],.015,'skin' if civilian else 'steel',hand)
        leg=empty('LegL' if s<0 else 'LegR',(s*.135,.872,0),root)
        loft('Fitted thigh',[(0,.103,.11,0,0),(-.16,.1,.104,0,0),(-.34,.076,.085,0,0),(-.41,.067,.068,0,0)],'leather' if civilian else 'chainmail',leg,n=28)
        if not civilian:
            loft('Cuisses', [(-.06,.105,.112,0,-.012),(-.18,.104,.108,0,-.012),(-.32,.08,.086,0,-.01)],armor,leg,n=28)
            tube('Thigh etching',[(0,-.08,-.128),(0,-.27,-.101)],.006,'gold',leg)
        knee=empty('Knee',(0,-.42,0),leg)
        ellipsoid('Kneecap',(0,.003,-.038),(.15,.14,.12),'leather_light' if civilian else 'steel_edge',knee)
        loft('Greave',[(0,.065,.068,0,0),(-.10,.076,.075,0,.012),(-.24,.059,.056,0,.002),(-.37,.046,.052,0,0)],'leather_light' if civilian else armor,knee,n=28,pointed=.01)
        if not civilian:
            tube('Greave gilt spine',[(0,-.055,-.078),(0,-.28,-.066)],.006,'gold',knee)
        # Shaped ankle and leather sole with overlapping sabaton plates.
        ellipsoid('Boot',(0,-.385,-.045),(.135,.14,.255),'leather',knee)
        box('Boot welt',(0,-.451,-.043),(.145,.025,.25),'leather',knee,.012)
        for j in range(4):
            ellipsoid('Sabatons' if not civilian else 'Boot stitching',(0,-.377-j*.011,-.002-j*.042),(.138-j*.006,.076,.073),armor if not civilian else 'leather_light',knee)
    if not civilian:cape(root,boss)
    finish(name)


def arch_shape(name,p,width,height,depth,material,parent=None):
    r=width/2
    spring=height-r
    outline=[(-r,0),(r,0),(r,spring)]
    outline.extend([(math.cos(a)*r,spring+math.sin(a)*r) for a in [i*PI/24 for i in range(1,25)]])
    vs=[(p[0]+x,p[1]+y,p[2]+z) for z in [-depth/2,depth/2] for x,y in outline]
    n=len(outline)
    fs=[tuple(range(n-1,-1,-1)),tuple(range(n,n*2))]
    fs.extend([(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)])
    return bevel(mesh(name,vs,fs,material,parent,False),.018,2)


def arch_frame(name,p,width,height,thickness,material,parent=None):
    r=width/2
    spring=height-r
    for s in [-1,1]:
        for i in range(max(1,int(spring/.28))):
            count=max(1,int(spring/.28));h=spring/count
            box(name+' jamb',(p[0]+s*(r+thickness/2),p[1]+(i+.5)*h,p[2]),(thickness,h-.013,.29),material,parent,.025)
    for i in range(15):
        a=(i+.5)*PI/15
        vs=[]
        for z in [-.15,.15]:
            for rr,aa in [(r,i*PI/15+.009),(r,(i+1)*PI/15-.009),(r+thickness,(i+1)*PI/15-.009),(r+thickness,i*PI/15+.009)]:
                vs.append((p[0]+math.cos(aa)*rr,p[1]+spring+math.sin(aa)*rr,p[2]+z))
        bevel(mesh(name+' voussoir',vs,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],material,parent,False),.012,2)


def window(parent,p,width=1.1,height=1.55):
    arch_shape('Recessed window',p,width,height,.08,'timber',parent)
    arch_shape('Lead glass',(p[0],p[1]+.09,p[2]-.045),width-.16,height-.18,.018,'glass',parent)
    arch_frame('Carved window surround',(p[0],p[1],p[2]-.08),width,height,.09,'wood_edge',parent)
    box('Window sill',(p[0],p[1]-.035,p[2]-.12),(width+.37,.14,.38),'cut_stone',parent,.03)
    box('Window mullion',(p[0],p[1]+height*.45,p[2]-.079),(.043,height*.88,.035),'gold_shadow',parent,.008)
    box('Window transom',(p[0],p[1]+height*.54,p[2]-.08),(width-.13,.045,.035),'gold_shadow',parent,.008)
    for s in [-1,1]:
        for j in range(4):
            x=p[0]+s*(width*.5+.2)
            box('Shutter plank',(x,p[1]+.14+j*.22,p[2]-.08),(.28,.205,.055),'slate',parent,.01)
        box('Shutter hinge',(p[0]+s*(width*.5+.2),p[1]+.34,p[2]-.12),(.27,.036,.035),'steel_dark',parent,.005)


def lantern(parent,p,scale=1):
    root=empty('Lantern',p,parent)
    root.scale=(scale,scale,scale)
    tube('Forged bracket',[(0,.25,.03),(.28,.4,.03),(.32,.16,.03)],.021,'steel_dark',root)
    box('Amber glazing',(.32,-.04,0),(.17,.27,.16),'lamp',root,.015)
    for x in [.22,.42]:
        for z in [-.09,.09]:tube('Lantern frame',[(x,-.2,z),(x,.12,z)],.012,'steel_dark',root)
    loft('Lantern cap',[(.12,.14,.13,.32,0),(.24,.035,.03,.32,0)],'steel_dark',root,n=4)
    box('Lantern foot',(.32,-.2,0),(.24,.04,.22),'steel_dark',root,.015)


def make_cottage():
    new_asset()
    root=empty('Cottage')
    w=7;d=6;eave=4.25;peak=6.9
    box('Foundation mortar',(0,.36,0),(w+.3,.72,d+.3),'mortar',root,.035)
    for y in range(3):
        for j in range(10):
            x=-3.2+j*.72+(y%2)*.16
            for z in [-3.08,3.08]:box('Dressed foundation block',(x,.14+y*.24,z),(.69,.22,.25),'cut_stone' if j%3 else 'limestone',root,.027)
    box('Limewashed walls',(0,2.42,0),(w,3.68,d),'plaster',root,.025)
    # Actual triangular gable prism.
    mesh('Gable masonry',[(-3.5,eave,-3),(3.5,eave,-3),(0,peak,-3),(-3.5,eave,3),(3.5,eave,3),(0,peak,3)],[(0,2,1),(3,4,5),(0,1,4,3),(1,2,5,4),(2,0,3,5)],'plaster',root,False)
    for z in [-3.055,3.055]:
        for x in [-3.46,-2.15,0,2.15,3.46]:box('Mortise upright',(x,2.5,z),(.19,3.7,.17),'timber',root,.03)
        for y in [.81,2.73,4.2]:box('Timber sill beam',(0,y,z),(7.15,.19,.19),'timber',root,.03)
        for s in [-1,1]:
            tube('Diagonal brace',[(s*.17,2.78,z),(s*1.87,4.1,z)],.064,'wood_edge',root,resolution=1)
            tube('Gable bargeboard',[(0,6.98,z-.13),(s*3.88,4.17,z-.13)],.12,'timber',root,resolution=1)
            tube('Gable inlay',[(0,6.98,z-.255),(s*3.88,4.17,z-.255)],.018,'gold_shadow',root,resolution=1)
        box('Gable king post',(0,5.45,z),(.16,2.45,.16),'timber',root,.018)
        window(root,(-2.03,1.13,z-.11),1.15,1.47)
        window(root,(2.03,1.13,z-.11),1.15,1.47)
        window(root,(0,4.66,z-.12),1.0,1.47)
    # Side window panels face outwards using independent transform roots.
    for s in [-1,1]:
        side=empty('Side facade',(s*3.56,0,0),root)
        side.rotation_euler.z=-s*PI/2
        for x in [-1.75,1.75]:window(side,(x,1.27,-.03),1.2,1.56)
    # Two hundred individually bowed slate tiles with staggered courses.
    for s in [-1,1]:
        for row in range(11):
            x0=row*.35;x1=(row+1)*.35+.055
            for col in range(15):
                z0=-3.45+col*.47+(row%2)*.07
                vs=[]
                for v in range(3):
                    x=x0+(x1-x0)*v/2
                    y=peak-(x/3.85)*2.65+.045*math.sin(v*PI/2)
                    for u in range(4):
                        z=z0+u*.46/3
                        yy=y+.023*math.sin(u*PI/3)
                        vs.append((s*x,yy,z))
                fs=[]
                for v in range(2):
                    for u in range(3):
                        a=v*4+u;fs.append((a,a+1,a+5,a+4))
                tile=mesh('Overlapping scalloped slate',vs,fs,['slate','slate_light','slate_dark'][(row+col*7)%3],root)
                sol=tile.modifiers.new('Slate thickness','SOLIDIFY');sol.thickness=.028
        for j in range(15):
            ellipsoid('Ridge cap',(0,7,-3.4+j*.47),(.29,.23,.48),'slate_dark',root,16,8)
    for z in [-3.65,3.65]:
        tube('Ridge finial',[(0,6.96,z),(0,7.37,z),(0,7.6,z-.15)],.04,'gold',root,radii=[1.3,.9,.15])
    # Arched oak doorway with radial stone surround, planks, straps and rivets.
    arch_shape('Doorway shadow',(0,.57,-3.08),1.53,2.62,.15,'timber',root)
    arch_frame('Door arch',(0,.57,-3.2),1.53,2.62,.22,'cut_stone',root)
    for i in range(9):
        x=-.67+i*.167
        top=.57+1.855+math.sqrt(max(0,.725**2-x*x))
        box('Oak door plank',(x,(top+.58)/2,-3.19),(.157,top-.58,.068),'oak_planks',root,.007)
    for y in [1.02,2.12]:
        box('Forged door strap',(0,y,-3.24),(1.33,.071,.035),'steel_dark',root,.016)
        for x in [-.54,-.27,.27,.54]:ellipsoid('Iron rivet',(x,y,-3.268),(.025,.025,.014),'steel_edge',root,12,8)
    ring('Door knocker',(.42,1.59,-3.285),.09,.014,'gold',root,'z')
    ellipsoid('Knocker lion boss',(.42,1.71,-3.265),(.10,.12,.028),'gold',root)
    for j in range(3):box('Worn door step',(0,.12+j*.16,-3.9+j*.2),(1.9-j*.08,.17,.53),'cut_stone',root,.055)
    lantern(root,(-1.17,2.41,-3.22),1.3)
    # Flower boxes with individually cut leaves.
    for s in [-1,1]:
        box('Window flower box',(s*2.03,1.01,-3.33),(1.32,.26,.39),'timber',root,.025)
        for j in range(10):
            x=s*2.03-.55+j*.12
            tube('Flower stem',[(x,1.08,-3.33),(x+.04,1.40+math.sin(j)*.07,-3.35)],.009,'leaf_green',root)
            for k in range(5):
                a=k*TAU/5
                ellipsoid('Flower petal',(x+math.cos(a)*.035,1.40+math.sin(j)*.07,-3.35+math.sin(a)*.035),(.055,.027,.055),'leaf_pink' if j%2 else 'leaf_light',root,10,6)
    box('Chimney core',(1.8,6.32,1.5),(.68,2.2,.79),'mortar',root,.035)
    for y in range(8):
        for s in [-1,1]:
            box('Chimney cut stone',(1.8+s*.17,5.45+y*.26,1.08),(.325,.235,.11),'cut_stone',root,.018)
    box('Chimney crown',(1.8,7.49,1.5),(.92,.16,1.02),'limestone',root,.025)
    finish('cottage')


def make_stall():
    new_asset();root=empty('MarketStall')
    for s in [-1,1]:
        tube('Turned stall post',[(s*2.8,0,0),(s*2.8,2.62,0)],.065,'timber',root)
        ellipsoid('Post finial',(s*2.8,2.7,0),(.15,.2,.15),'gold_shadow',root)
    for stripe in range(14):
        vs=[];fs=[]
        for j in range(13):
            v=j/12
            for u in [0,1]:
                x=-2.8+(stripe+u)*.4
                vs.append((x,3.08-v*.46-math.sin(v*PI)*.16,-2.1+v*2.2))
        for j in range(12):a=j*2;fs.append((a,a+1,a+3,a+2))
        mesh('Woven canopy stripe',vs,fs,'teal_cloth' if stripe%2 else 'ivory_cloth',root)
        tube('Canopy seam',[vs[j*2] for j in range(13)],.012,'ivory_cloth',root)
        x=-2.6+stripe*.4
        vs=[(x-.2,2.62,.1),(x+.2,2.62,.1),(x+.18,2.40,.1),(x,2.31,.1),(x-.18,2.4,.1)]
        mesh('Scalloped valance',vs,[(0,1,2,3,4)],'teal_cloth' if stripe%2 else 'ivory_cloth',root)
    box('Market cabinet',(0,.73,-.55),(5.3,1.4,.93),'timber',root,.045)
    for i in range(18):box('Counter plank',(-2.62+i*.31,1.45,-.55),(.30,.075,1.09),'oak_planks',root,.01)
    for x in [-1.8,0,1.8]:
        box('Produce tray',(x,1.55,-.55),(1.38,.13,.75),'wood_edge',root,.02)
        for i in range(15):
            p=(x+random.uniform(-.55,.55),1.69+random.uniform(0,.04),-.55+random.uniform(-.25,.25))
            ellipsoid('Market apple',p,(.15,.15,.15),'leaf_gold' if x<0 else 'wine_cloth' if x>0 else 'leaf_green',root,12,8)
            tube('Apple stem',[p,(p[0]+.01,p[1]+.092,p[2])],.006,'timber',root,resolution=1)
    finish('market_stall')


def make_tower():
    new_asset();root=empty('Tower')
    # Individual stone courses, sixteen-sided with offset joints.
    for row in range(29):
        y=(row+.5)*.45
        for i in range(24):
            a=(i+(row%2)*.5)*TAU/24
            rr=3.0+(.17 if row<2 else 0)
            o=box('Radial limestone ashlar',(math.sin(a)*rr,y,math.cos(a)*rr),(.78,.433,.3),'limestone' if (row+i)%7 else 'cut_stone',root,.024)
            o.rotation_euler.z=a
    loft('Tower core',[(0,2.92,2.92,0,0),(13,2.92,2.92,0,0)],'mortar',root,n=64)
    for y in [.25,.7,4.5,8.55,12.6,13.1]:ring('Moulded stringcourse',(0,y,0),3.1,.09,'cut_stone',root)
    for i in range(8):
        a=i*TAU/8
        side=empty('Arrow slit facade',(math.sin(a)*3.075,0,math.cos(a)*3.075),root)
        side.rotation_euler.z=a+PI
        for y in [3.3,7.2,10.5]:
            arch_shape('Arrow slit',(0,y,-.02),.48,1.43,.065,'steel_dark',side)
            arch_frame('Arrow slit trim',(0,y,-.075),.48,1.43,.09,'cut_stone',side)
        # Small corbels support the projecting battlement crown.
        for dx in [-.7,0,.7]:
            box('Corbel',(dx,12.8,-.08),(.28,.59,.53),'cut_stone',side,.04)
    loft('Battlement cornice',[(13,3.08,3.08,0,0),(13.3,3.43,3.43,0,0),(13.65,3.43,3.43,0,0)],'limestone',root,n=64)
    for i in range(16):
        a=i*TAU/16
        o=box('Crenellation merlon',(math.sin(a)*3.23,14.15,math.cos(a)*3.23),(.77,1.16,.51),'limestone',root,.055)
        o.rotation_euler.z=a
        top=box('Merlon coping',(math.sin(a)*3.23,14.77,math.cos(a)*3.23),(.88,.16,.66),'cut_stone',root,.035);top.rotation_euler.z=a
    # Layered conical slate roof: each course overlaps the last.
    for row in range(17):
        y=13.45+row*.245
        r=3.0*(1-row/18)
        loft('Slate roof course',[(y,r,r,0,0),(y+.32,max(.06,r-.25),max(.06,r-.25),0,0)],'slate' if row%3 else 'slate_light',root,n=32)
    tube('Roof spire',[(0,17.6,0),(0,18.55,0)],.035,'gold',root,radii=[1.5,.15])
    ellipsoid('Spire orb',(0,17.95,0),(.22,.22,.22),'gold',root)
    finish('castle_tower')


def make_gate():
    new_asset();root=empty('Gatewall')
    for side in [-1,1]:
        box('Gate wing core',(side*8.95,4.15,0),(8.1,8.3,1.8),'mortar',root,.02)
        for row in range(17):
            for col in range(8):
                x=side*(5.03+col*1.02+(row%2)*.08)
                for z in [-.94,.94]:box('Gate face ashlar',(x,.24+row*.48,z),(.98,.458,.22),'limestone' if (row+col)%7 else 'cut_stone',root,.025)
        for x in [side*5.1,side*11.9]:
            box('Gate pilaster',(x,3.6,1.04),(.38,7.2,.45),'cut_stone',root,.03)
        banner=empty('Embroidered banner',(side*8.1,6.9,1.14),root)
        vs=[];fs=[]
        for j in range(18):
            v=j/17
            for i in range(9):
                u=-1+i/4
                vs.append((u*.78,-v*3.1-.16*(1-abs(u))*v,math.sin(u*PI*2+v)*.05))
        for j in range(17):
            for i in range(8):a=j*9+i;fs.append((a,a+1,a+10,a+9))
        mesh('Woven royal banner',vs,fs,'teal_cloth',banner)
        sun('Banner sun',(0,-1.25,.1),.3,'gold',banner)
        tube('Banner rod',[(-.98,.1,0),(.98,.1,0)],.036,'gold',banner)
    # Open arch: structural stones leave a true ten-metre-wide passage.
    arch_frame('Grand portal',(0,0,0),9.3,7.9,.64,'cut_stone',root)
    box('Upper gate cornice',(0,8.8,0),(26,1.0,2.03),'limestone',root,.04)
    for x in range(-12,13,2):box('Gate battlement',(x,9.77,0),(1.05,1.14,1.88),'limestone',root,.055)
    for z in [-1.04,1.04]:
        box('Upper moulding',(0,8.5,z),(26,.16,.26),'cut_stone',root,.025)
        sun('Royal insignia',(0,8.91,z+.15),.32,'gold',root)
    finish('castle_gate')


def make_horse():
    new_asset();root=empty('HorseRig')
    # Anatomical masses blended visually through overlapping shaped surfaces.
    ellipsoid('Barrel chest',(0,1.37,.06),(.72,.82,1.49),'horse',root,40,28)
    ellipsoid('Withers',(0,1.65,-.45),(.57,.59,.77),'horse',root,32,20)
    ellipsoid('Hindquarters',(0,1.4,.64),(.76,.81,.68),'horse',root,32,20)
    loft('Tapered curved neck',[(1.31,.29,.30,0,-.53),(1.6,.25,.27,0,-.65),(1.95,.19,.21,0,-.8),(2.21,.142,.165,0,-.95),(2.33,.12,.14,0,-1.02)],'horse',root,n=40)
    ellipsoid('Equine skull',(0,2.25,-1.11),(.30,.41,.51),'horse',root,32,24)
    ellipsoid('Nasal bridge',(0,2.12,-1.35),(.25,.30,.43),'horse',root,32,20)
    ellipsoid('Soft muzzle',(0,1.99,-1.49),(.29,.22,.27),'horse_light',root,32,20)
    for s in [-1,1]:
        ellipsoid('Nostril',(s*.112,2.015,-1.59),(.055,.054,.025),'leather',root)
        ellipsoid('Eye socket',(s*.146,2.3,-1.2),(.034,.065,.07),'horse_light',root)
        ellipsoid('Expressive eye',(s*.163,2.3,-1.208),(.019,.039,.042),'eye',root)
        ellipsoid('Eye highlight',(s*.175,2.31,-1.223),(.006,.012,.01),'eye_white',root)
        # Pointed curved ears, with a recessed inner surface.
        loft('Ear',[(2.39,.063,.045,s*.105,-.96),(2.56,.05,.03,s*.13,-.93),(2.68,.004,.01,s*.135,-.93)],'horse',root,n=20)
        loft('Inner ear',[(2.43,.033,.013,s*.105,-.995),(2.56,.027,.008,s*.13,-.961),(2.63,.003,.002,s*.133,-.956)],'skin_shadow',root,n=12)
        tube('Cheek bridle',[(s*.157,2.43,-1.00),(s*.179,2.3,-1.21),(s*.137,2.07,-1.42)],.019,'leather',root)
        ring('Brass bit ring',(s*.158,2.035,-1.47),.046,.009,'gold',root,'z')
        tube('Leather reins',[(s*.158,2.035,-1.47),(s*.33,1.72,-.72),(s*.31,1.81,.06)],.012,'leather',root)
    tube('White blaze',[(0,2.42,-1.22),(0,2.25,-1.34),(0,2.12,-1.5)],.044,'horse_light',root,radii=[.7,1,.4])
    tube('Noseband',[(-.127,2.13,-1.45),(0,2.15,-1.535),(.127,2.13,-1.45)],.023,'leather',root)
    for side in [-1,1]:
        for z in [-.52,.58]:
            leg=empty('Leg'+str(side)+str(z),(side*.265,1.22,z),root)
            loft('Muscular upper leg',[(0,.105,.13,0,0),(-.25,.078,.10,0,.035 if z>0 else -.01),(-.53,.045,.056,0,.06 if z>0 else 0)],'horse',leg,n=24)
            ellipsoid('Knee joint',(0,-.57,.055 if z>0 else 0),(.10,.15,.13),'horse',leg)
            loft('Cannon and fetlock',[(-.61,.036,.045,0,.05 if z>0 else 0),(-1.02,.041,.047,0,-.02),(-1.10,.057,.061,0,-.025)],'horse_light',leg,n=20)
            loft('Hoof',[(-1.22,.082,.10,0,-.05),(-1.10,.067,.076,0,-.03)],'hoof',leg,n=20)
    # Draped saddle blanket with a stitched border, contoured around the barrel.
    vs=[];fs=[]
    for j in range(13):
        z=-.24+j*.065
        for i in range(17):
            a=-PI*.48+i*PI*.96/16
            vs.append((math.sin(a)*.397,1.44+math.cos(a)*.46,z))
    for j in range(12):
        for i in range(16):a=j*17+i;fs.append((a,a+1,a+18,a+17))
    mesh('Tailored saddlecloth',vs,fs,'teal_cloth',root)
    for idx in [0,12]:tube('Saddlecloth piping',[vs[idx*17+i] for i in range(17)],.012,'gold',root)
    ellipsoid('Leather saddle seat',(0,1.91,.12),(.55,.14,.62),'leather_light',root)
    for z in [-.21,.46]:tube('Raised saddle roll',[(-.25,1.91,z),(0,2,z),(.25,1.91,z)],.035,'leather',root)
    for s in [-1,1]:
        tube('Stirrup leather',[(s*.25,1.92,.05),(s*.42,1.4,.08)],.024,'leather',root)
        ring('Stirrup',(s*.43,1.31,.08),.1,.014,'steel',root,'z')
        ellipsoid('Saddlebag',(s*.43,1.57,.58),(.23,.34,.39),'leather_light',root)
    for i in range(26):
        y=1.69+i*.026;z=-.56-i*.018
        tube('Individual mane lock',[(0,y+.17,z),(.035*math.sin(i),y+.08,z+.07),(.10,y-.07,z+.12)],.022,'mane',root,radii=[.8,1,.05])
    for i in range(20):
        a=i*TAU/20
        tube('Flowing tail',[(math.cos(a)*.04,1.62,.92),(math.cos(a)*.09,1.04,1.18),(math.cos(a)*.12,.44,1.29)],.023,'mane',root,radii=[.55,1,.03])
    finish('horse')


def make_tree(name,blossom=False):
    new_asset();root=empty('Tree')
    trunk=[(0,0,0),(.05,1.1,.035),(-.11,2.3,.08),(.12,3.4,.01),(0,4.6,.1)]
    tube('Organic fluted trunk',trunk,.24,'bark',root,radii=[1.55,1.0,.72,.43,.05],resolution=3)
    for i in range(7):
        a=i*TAU/7
        tube('Exposed root',[(0,.6,0),(math.cos(a)*.38,.13,math.sin(a)*.38),(math.cos(a)*.83,.015,math.sin(a)*.83)],.10,'bark',root,radii=[1,.75,.04])
    leaves={k:([],[]) for k in ['leaf_pink','leaf_light','leaf_gold'] if blossom} if blossom else {k:([],[]) for k in ['leaf_gold','leaf_light','leaf_green']}
    for branch in range(22):
        a=branch*2.39996
        h=2.2+(branch%6)*.35
        r=1.1+(branch%4)*.32
        end=Vector((math.cos(a)*r,h+1.0,math.sin(a)*r))
        tube('Tapering bough',[(0,h-.35,0),tuple(end*.6+Vector((0,h*.4,0))),tuple(end)],.085,'bark',root,radii=[1,.62,.08],resolution=2)
        for twig in range(5):
            a2=a+twig*1.3
            tip=end+Vector((math.cos(a2)*.7,.3+math.sin(twig)*.3,math.sin(a2)*.7))
            tube('Fine twig',[tuple(end*.87+Vector((0,.3,0))),tuple(tip)],.025,'bark',root,radii=[1,.03],resolution=1)
            for leaf in range(24):
                p=tip+Vector((random.uniform(-.65,.65),random.uniform(-.35,.55),random.uniform(-.65,.65)))
                angle=random.random()*TAU
                length=random.uniform(.15,.28)
                width=length*.44
                d=Vector((math.cos(angle),random.uniform(-.3,.6),math.sin(angle))).normalized()
                side=d.cross(Vector((0,1,0))).normalized()
                material=list(leaves)[(branch+twig+leaf)%3]
                vs,fs=leaves[material]
                n=len(vs)
                vs.extend([tuple(p-d*length*.65),tuple(p+side*width),tuple(p+Vector((0,.045,0))),tuple(p-side*width),tuple(p+d*length)])
                fs.extend([(n,n+1,n+2),(n+1,n+4,n+2),(n+4,n+3,n+2),(n+3,n,n+2)])
    for key,(vs,fs) in leaves.items():
        o=mesh('Individually folded leaves',vs,fs,key,root)
        # glTF double-sided material so the canopy is visible from below.
        M[key].use_backface_culling=False
    finish(name)


def make_rock():
    new_asset();root=empty('Rock')
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3,radius=1)
    o=bpy.context.object;o.name='Weathered stone'
    for v in o.data.vertices:
        n=noise_vector(v.co*2.3)
        v.co*=1+n.x*.16
        v.co.z*=.7
    assign(o,'rock',root)
    bevel(o,.04,2)
    finish('weathered_rock')


def make_mountain():
    new_asset();root=empty('Mountain')
    vs=[];fs=[]
    n=64;levels=13
    for j in range(levels):
        t=j/(levels-1)
        for i in range(n):
            a=i*TAU/n
            radius=(1-t)**.78*(1+math.sin(a*7)*.1+math.sin(a*13)*.04)
            h=t+math.sin(a*9+t*8)*.06*math.sin(t*PI)
            vs.append((math.cos(a)*radius+t*.14,h,math.sin(a)*radius+t*.12))
    for j in range(levels-1):
        for i in range(n):a=j*n+i;b=j*n+(i+1)%n;fs.append((a,b,b+n,a+n))
    o=mesh('Ridged mountain terrain',vs,fs,'rock',root)
    o.data.materials.append(M['rock_light']);o.data.materials.append(M['snow'])
    for p in o.data.polygons:
        h=sum(o.data.vertices[i].co.z for i in p.vertices)/len(p.vertices)
        p.material_index=2 if h>.76 else 1 if h>.45 else 0
    finish('mountain')


def make_pine():
    new_asset();root=empty('Tree')
    tube('Pine trunk',[(0,0,0),(.04,2,0),(-.03,4,0),(0,6.7,0)],.19,'bark',root,radii=[1.3,.7,.32,.02])
    vs=[];fs=[]
    for row in range(11):
        y=1.1+row*.47;r=2.05*(1-row/12)
        for branch in range(7):
            a=branch*TAU/7+row*.8
            tip=Vector((math.cos(a)*r,y-.18,math.sin(a)*r))
            tube('Pine bough',[(0,y+.15,0),tuple(tip*.6+Vector((0,y*.4,0))),tuple(tip)],.045,'bark',root,radii=[1,.65,.03],resolution=1)
            for needle in range(40):
                t=random.uniform(.16,1)
                p=Vector((tip.x*t,y-.18*t,tip.z*t))
                b=a+random.choice([-1,1])*.65
                length=(1-t*.6)*.55
                d=Vector((math.cos(b)*length,.15,math.sin(b)*length))
                side=Vector((-math.sin(b),0,math.cos(b)))*.10
                n=len(vs)
                vs.extend([tuple(p),tuple(p+d*.5+side),tuple(p+d),tuple(p+d*.5-side)])
                fs.extend([(n,n+1,n+2),(n,n+2,n+3)])
    mesh('Layered evergreen sprays',vs,fs,'leaf_green',root)
    finish('pine_tree')


def main():
    SOURCE.mkdir(parents=True,exist_ok=True);OUTPUT.mkdir(parents=True,exist_ok=True)
    materials()
    make_sword()
    make_human()
    make_human('villager',civilian=True)
    make_human('sunwarden',boss=True)
    make_cottage()
    make_stall()
    make_tower()
    make_gate()
    make_horse()
    make_tree('golden_oak')
    make_tree('blossom_tree',True)
    make_pine()
    make_rock()
    make_mountain()
    (OUTPUT/'asset_manifest.json').write_text(json.dumps(REPORT,indent=2))
    print('ALL ASSETS BUILT',flush=True)


if __name__=='__main__':main()
