"""Original anime character revision for Aurelia, authored and exported in Blender.

This replaces the runtime character assets, retaining the existing joint contract.
Faces, eyes, hair clumps and layered costumes are geometry, not concept renders.
"""
import sys
import math
import json
from pathlib import Path
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
import build_assets as a
import bpy
import bmesh

a.materials()
for args in [
    ('anime_skin','f2ceb7',0,.83),('anime_skin_detail','f2ceb7',0,.83),('anime_blush','ecc0ad',0,.9),
    ('anime_lip','b67774',0,.9),('anime_ink','293247',0,.9),
    ('anime_white','fff5e4',0,.8),('anime_iris','47bec5',0,.5),
    ('anime_iris_dark','227284',0,.75),('anime_eye_gold','e1ae4f',0,.65),
    ('anime_silver_hair','d4e3e4',0,.72),('anime_hair_shadow','9ebbbf',0,.78),
    ('anime_hair_light','edf5ed',0,.68),('anime_teal_hair','4c9fae',0,.73),
    ('anime_brown_hair','785541',0,.78),('anime_brown_light','b4865b',0,.8),
    ('anime_dark_hair','485270',0,.8),('anime_navy','28364d',0,.88),
    ('anime_ivory','efe5d1',0,.86),('anime_gold','d2aa62',.35,.43),
    ('anime_silver','b9cfd7',.35,.45),('anime_boots','374352',0,.83),
    ('anime_lining','538b96',0,.9),('anime_red','8c465a',0,.85),
    ('anime_gem','75dfd6',.2,.25)
]:a.mat(*args)
# An untextured colour slot that the existing NPC palette can customize.
a.mat('teal_cloth','306873',0,.88)


def hair_lock(name,points,width,thickness,material,parent):
    points=[Vector(p) for p in points]
    samples=[]
    for i in range(17):
        u=i/16*(len(points)-1)
        k=min(int(u),len(points)-2);t=u-k
        p0=points[max(0,k-1)];p1=points[k];p2=points[k+1];p3=points[min(len(points)-1,k+2)]
        samples.append(.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t))
    vs=[];fs=[];n=8
    for i,p in enumerate(samples):
        t=i/(len(samples)-1)
        tangent=(samples[min(i+1,len(samples)-1)]-samples[max(0,i-1)]).normalized()
        side=tangent.cross(Vector((0,0,-1)))
        if side.length<.05:side=Vector((1,0,0))
        side.normalize();normal=side.cross(tangent).normalized()
        profile=max(.014,math.sin(math.pi*(.12+t*.88))**.4*(1-t)**.25)
        for j in range(n):
            angle=j*math.tau/n
            vs.append(tuple(p+side*math.cos(angle)*width*profile+normal*math.sin(angle)*thickness*profile))
    for i in range(len(samples)-1):
        for j in range(n):
            k=i*n+j;l=i*n+(j+1)%n;fs.append((k,l,l+n,k+n))
    fs.append(tuple(range(n-1,-1,-1)))
    fs.append(tuple((len(samples)-1)*n+j for j in range(n)))
    ob=a.mesh(name,vs,fs,material,parent)
    bm=bmesh.new();bm.from_mesh(ob.data)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(ob.data);bm.free()
    return ob


def eye_surface(x,y,depth=.0):
    return (x,y,-math.sqrt(max(.001,1-(x/.119)**2))*.092-.005-depth)


def anime_face(head,kind):
    a.loft('Anime face silhouette',[
        (-.147,.015,.026,0,-.025),(-.12,.051,.049,0,-.018),(-.078,.088,.067,0,-.008),
        (-.023,.106,.086,0,0),(.047,.114,.092,0,0),(.112,.104,.09,0,.004),(.158,.056,.055,0,.004),(.174,.006,.008,0,.004)
    ],'anime_skin',head,n=48)
    iris='anime_eye_gold' if kind in ('boss','enemy') else 'anime_iris'
    for s in [-1,1]:
        cx=s*.047
        outline=[(-.038,-.004),(-.029,.022),(-.006,.03),(.022,.023),(.039,.004),(.027,-.019),(0,-.023),(-.027,-.017)]
        vertices=[eye_surface(cx+u,.022+v,.001) for u,v in outline]
        vertices.append(eye_surface(cx,.024,.001))
        a.mesh('Almond eye white',vertices,[(8,i,(i+1)%8) for i in range(8)],'anime_white',head)
        p=eye_surface(cx,.023,.009)
        a.ellipsoid('Large anime iris',p,(.038,.047,.009),iris,head,24,16)
        a.ellipsoid('Iris upper shading',(p[0],p[1]+.012,p[2]-.004),(.031,.019,.004),'anime_iris_dark' if kind not in ('boss','enemy') else 'anime_ink',head,20,12)
        a.ellipsoid('Vertical pupil',(p[0],p[1]+.003,p[2]-.007),(.016,.032,.004),'anime_ink',head,20,12)
        a.ellipsoid('Main eye sparkle',(p[0]-.007,p[1]+.013,p[2]-.011),(.012,.013,.004),'anime_white',head,16,10)
        a.ellipsoid('Lower eye sparkle',(p[0]+.008,p[1]-.011,p[2]-.01),(.005,.006,.003),'anime_white',head,12,8)
        upper=[eye_surface(cx+u,.022+v,.008) for u,v in outline[:5]]
        a.tube('Graphic upper eyelash',upper,.0036,'anime_ink',head,radii=[.3,.85,1,1.1,.4],resolution=1)
        outer=eye_surface(cx+s*.038,.026,.009)
        a.mesh('Tapered lash wing',[outer,eye_surface(cx+s*.052,.039,.005),eye_surface(cx+s*.034,.035,.009)],[(0,1,2)],'anime_ink',head)
        a.tube('Fine lower lash',[eye_surface(cx+u,.022+v,.006) for u,v in outline[4:]],.0016,'anime_ink',head,resolution=1)
        a.tube('Expressive eyebrow',[eye_surface(cx-.029,.078,.006),eye_surface(cx,.083,.007),eye_surface(cx+.031,.073,.004)],.0038,'anime_ink',head,radii=[.3,1,.1],resolution=1)
        a.ellipsoid('Small ear',(s*.113,-.006,.002),(.028,.072,.033),'anime_skin',head)
        a.ellipsoid('Ear interior',(s*.124,-.005,-.009),(.010,.040,.018),'anime_blush',head)
        a.ellipsoid('Soft cheek tint',eye_surface(s*.07,-.036,.003),(.025,.011,.002),'anime_blush',head,16,8)
    a.ellipsoid('Delicate nose',(0,-.028,-.09),(.012,.022,.012),'anime_skin_detail',head,20,12)
    a.tube('Small smiling mouth',[(-.023,-.086,-.067),(0,-.09,-.074),(.023,-.086,-.067)],.0022,'anime_lip',head,resolution=1)
    a.ellipsoid('Lower lip light',(0,-.095,-.069),(.021,.005,.003),'anime_skin',head,16,8)
    # One asymmetrical crystal earring is part of the original character design.
    a.tube('Earring chain',[(.117,-.035,0),(.124,-.095,0)],.003,'anime_gold',head,resolution=1)
    a.loft('Earring crystal',[(-.151,.001,.001,.124,0),(-.127,.011,.009,.124,0),(-.107,.004,.004,.124,0)],'anime_gem',head,n=6)


def anime_hair(head,kind):
    base='anime_brown_hair' if kind=='npc' else 'anime_dark_hair' if kind=='enemy' else 'anime_silver_hair'
    highlight='anime_brown_light' if kind=='npc' else 'anime_hair_shadow' if kind=='enemy' else 'anime_hair_light'
    # Skull-fitted cap remains above the eyes; all visible silhouette tips are meshes.
    a.loft('Hair crown cap',[(.083,.118,.09,0,.021),(.15,.11,.084,0,.014),(.205,.058,.052,0,.012),(.218,.004,.004,0,.012)],base,head,n=40)
    for i in range(16):
        angle=i*math.tau/16
        sx=math.cos(angle);sz=math.sin(angle)
        if sz<-.55:continue
        length=.20 if kind=='boss' else .105
        points=[(sx*.037,.21,sz*.035+.01),(sx*.106,.153,sz*.083+.02),(sx*.145,.038,sz*.093+.025),(sx*.121,-length,sz*.10+.02)]
        hair_lock('Layered side and back hair',points,.044,.022,highlight if i%4==0 else base,head)
    # Swept forehead strands alternate lengths, leaving both irises readable.
    for i in range(7):
        x=-.10+i*.033
        tip_y=.036 if i in [1,5] else .011 if i in [0,6] else .055
        points=[(x*.25+.027,.215,-.027),(x*.65+.019,.158,-.09),(x,.09,-.113),(x-.022,tip_y,-.113)]
        color='anime_teal_hair' if i==5 and kind=='hero' else highlight if i%3==0 else base
        hair_lock('Sculpted pointed fringe',points,.031,.012,color,head)
    for s in [-1,1]:
        hair_lock('Long face framing lock',[(s*.095,.16,-.017),(s*.137,.064,-.025),(s*.134,-.06,-.022),(s*.111,-.20 if kind=='boss' else -.145,-.016)],.034,.018,base,head)
    hair_lock('Crown flyaway',[(.014,.20,.02),(.07,.28,.015),(.118,.27,-.015),(.127,.244,-.035)],.019,.009,highlight,head)
    if kind=='npc':
        a.ring('Ponytail tie',(0,.09,.125),.031,.008,'anime_navy',head)
        for i in range(5):
            x=(i-2)*.017
            hair_lock('Low ponytail',[(x,.09,.13),(x*1.4,-.025,.17),(x,-.15,.18),(x+.024,-.22,.14)],.025,.017,base,head)
    if kind=='boss':
        a.ring('Sunwarden floating crown',(0,.14,.15),.29,.010,'anime_gold',head,'z')
        for i in range(9):
            t=i*math.pi/8
            a.tube('Crown point',[(math.cos(t)*.32,.14+math.sin(t)*.32,.15),(math.cos(t)*.41,.14+math.sin(t)*.41,.15)],.009,'anime_gold',head,radii=[1,.05],resolution=1)


def coat_panel(root,side,back=False,material='anime_ivory'):
    vertices=[];faces=[]
    for j in range(15):
        v=j/14
        for i in range(10):
            u=i/9
            x=side*(.035+u*(.185+v*.085))
            y=1.07-v*(.51 if back else .36)-math.sin(u*math.pi)*.025*v
            z=(.13 if back else -.135)+(.17 if back else -.025)*v+math.sin(u*math.pi*2+v)*.013
            vertices.append((x,y,z))
    for j in range(14):
        for i in range(9):p=j*10+i;faces.append((p,p+1,p+11,p+10))
    o=a.mesh('Split tailored coat tail',vertices,faces,material,root)
    solid=o.modifiers.new('Tailored cloth thickness','SOLIDIFY');solid.thickness=.004
    a.tube('Gold coat edging',[vertices[j*10+9] for j in range(15)],.006,'anime_gold',root,resolution=1)
    a.tube('Gold hem',[vertices[140+i] for i in range(10)],.006,'anime_gold',root,resolution=1)


def build(name,kind):
    a.new_asset();root=a.empty('Rig')
    boss=kind=='boss';npc=kind=='npc';enemy=kind=='enemy'
    accent='anime_red' if boss else 'anime_navy' if enemy else 'teal_cloth'
    outer='anime_ivory' if not enemy else 'anime_navy'
    metal='anime_gold' if boss else 'anime_silver'
    torso=a.empty('Torso',(0,1.05,0),root)
    a.loft('Fitted anime torso',[(0,.16,.106,0,0),(.10,.18,.115,0,0),(.31,.229,.126,0,0),(.45,.21,.106,0,0),(.49,.092,.066,0,0)],accent,torso,n=36)
    a.loft('High collar',[(.44,.076,.065,0,0),(.52,.070,.060,0,0)],'anime_navy',torso,n=28)
    for side in [-1,1]:
        # Open, asymmetrical ivory jacket lapels, edged in gold.
        vs=[(side*.19,.43,-.143),(side*.098,.5,-.143),(side*.085,.28,-.153),(side*.158,.11,-.143),(side*.195,.17,-.143)]
        o=a.mesh('Sculpted jacket lapel',vs,[(0,1,2,3,4)],outer,torso)
        solid=o.modifiers.new('Lapel thickness','SOLIDIFY');solid.thickness=.01
        a.tube('Lapel gold piping',[vs[1],vs[2],vs[3]],.006,'anime_gold',torso,resolution=1)
        coat_panel(root,side,False,outer)
        coat_panel(root,side,True,accent)
    a.loft('Diagonal waist sash',[(-.034,.179,.117,0,0),(.024,.177,.116,0,0)],accent,torso,n=36)
    a.loft('Waist belt',[(-.003,.185,.122,0,0),(.034,.182,.12,0,0)],'anime_navy',torso,n=36)
    a.box('Ornate belt clasp',(0,.016,-.128),(.067,.056,.018),'anime_gold',torso,.007)
    a.ellipsoid('Belt crystal',(0,.016,-.143),(.032,.035,.016),'anime_gem',torso,16,10)
    a.sun('Dawn brooch',(0,.347,-.146),.045,'anime_gold',torso)
    for j in range(4):
        a.ellipsoid('Jacket fastener',(.05,.10+j*.049,-.126),(.012,.012,.009),'anime_gold',torso,12,8)
    # A side sash, tassels and an original crystal focus add a readable silhouette.
    a.tube('Hanging sash cord',[(.182,1.08,-.012),(.245,.98,-.015),(.238,.78,-.026)],.009,'anime_gold',root,resolution=2)
    a.loft('Suspended crystal focus',[(.67,.002,.002,.238,-.026),(.731,.027,.02,.238,-.026),(.78,.013,.012,.238,-.026)],'anime_gem',root,n=6)
    for i in range(5):a.tube('Silk tassel',[(.235+(i-2)*.006,.70,-.022),(.244+(i-2)*.008,.60,-.019)],.0028,accent,root,resolution=1)
    head=a.empty('Head',(0,1.76,0),root)
    a.loft('Neck',[(-.24,.047,.044,0,0),(-.112,.044,.043,0,0)],'anime_skin',head,n=28)
    anime_face(head,kind);anime_hair(head,kind)
    for side in [-1,1]:
        arm=a.empty('ArmL' if side<0 else 'ArmR',(side*.253,1.50,0),root)
        a.loft('Tailored sleeve',[(.061,.015,.019,0,0),(.043,.056,.06,0,0),(.015,.075,.078,0,0),(-.12,.069,.07,0,0),(-.285,.055,.055,0,0)],outer,arm,n=28)
        if not npc and (side>0 or boss):
            a.ellipsoid('Small fitted shoulder guard',(0,.018,.005),(.19,.12,.2),metal,arm,28,16)
            a.tube('Shoulder gold edge',[(-.078,-.011,-.036),(0,-.035,-.087),(.078,-.011,-.036)],.006,'anime_gold',arm,resolution=1)
        a.ring('Sleeve trim',(0,-.21,0),.061,.007,accent,arm)
        elbow=a.empty('Elbow',(0,-.29,0),arm)
        a.loft('Tapered forearm',[(.014,.052,.053,0,0),(-.12,.047,.048,0,0),(-.26,.034,.038,0,0)],'anime_skin' if npc else 'anime_navy',elbow,n=28)
        if not npc:
            a.loft('Slim wrist guard',[(-.22,.041,.044,0,-.002),(-.10,.055,.052,0,-.005)],outer,elbow,n=24)
            a.tube('Wrist guard inlay',[(0,-.22,-.048),(0,-.12,-.058)],.005,'anime_gold',elbow,resolution=1)
        a.ring('Wrist bracelet',(0,-.245,0),.037,.006,'anime_gold',elbow)
        hand=a.empty('Hand',(0,-.30,-.008),elbow)
        a.ellipsoid('Slim palm',(0,-.01,0),(.067,.088,.042),'anime_skin',hand,24,16)
        if not npc:a.ellipsoid('Fingerless glove',(0,.006,.008),(.073,.058,.043),'anime_navy',hand,24,16)
        for finger in range(4):
            x=-.024+finger*.016
            a.tube('Tapered finger',[(x,-.029,-.006),(x,-.066,-.01),(x,-.072,-.039)],.0075,'anime_skin',hand,radii=[1,.88,.6],resolution=2)
        a.tube('Thumb',[(side*.027,0,0),(side*.042,-.026,-.023),(side*.032,-.045,-.034)],.011,'anime_skin',hand,radii=[1,.9,.6],resolution=2)
        leg=a.empty('LegL' if side<0 else 'LegR',(side*.112,.962,0),root)
        a.loft('Long fitted trouser leg',[(0,.087,.089,0,0),(-.16,.081,.085,0,0),(-.32,.064,.067,0,0),(-.447,.052,.057,0,0)],'anime_navy',leg,n=32)
        a.tube('Trouser side seam',[(side*.087,-.045,.018),(side*.077,-.21,.018),(side*.060,-.40,.014)],.005,accent,leg,resolution=1)
        knee=a.empty('Knee',(0,-.45,0),leg)
        a.loft('Tall fitted boot',[(.026,.060,.064,0,0),(-.10,.063,.065,0,.008),(-.27,.047,.048,0,0),(-.405,.037,.043,0,0)],'anime_boots',knee,n=32)
        a.ring('Boot gold cuff',(0,-.015,0),.064,.007,'anime_gold',knee)
        a.tube('Boot white facing',[(0,-.04,-.065),(0,-.2,-.058),(0,-.36,-.052)],.012,outer,knee,resolution=2)
        for j in range(5):
            y=-.06-j*.038
            a.tube('Boot lace',[(-.019,y,-.066),(.019,y-.025,-.066)],.0024,'anime_gold',knee,resolution=1)
        a.ellipsoid('Shaped boot foot',(0,-.445,-.05),(.115,.119,.222),'anime_boots',knee,28,16)
        a.box('Boot sole',(0,-.499,-.05),(.119,.026,.226),'anime_navy',knee,.012)
        a.tube('Toe piping',[(-.044,-.454,-.13),(0,-.47,-.16),(.044,-.454,-.13)],.004,'anime_gold',knee,resolution=1)
    if not npc:
        cape=a.cape(root,boss)
        # Source cloth is intentionally light, with a split-coat silhouette.
        cape.scale=(.78,.9,.83)
        if enemy:
            for ob in bpy.context.scene.objects:
                if ob.parent==cape and ob.type=='MESH':
                    for i,slot in enumerate(ob.data.materials):
                        if 'teal_cloth' in slot.name:ob.data.materials[i]=a.M['anime_navy']
    a.finish(name)


build('traveler','hero')
build('villager','npc')
build('sunwarden','boss')
build('field_enemy','enemy')
manifest=a.OUTPUT/'asset_manifest.json'
old=json.loads(manifest.read_text())
names={r['asset'] for r in a.REPORT}
manifest.write_text(json.dumps([r for r in old if r['asset'] not in names]+a.REPORT,indent=2))
print('ANIME CHARACTERS COMPLETE',flush=True)
