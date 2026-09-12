"""Build CC0 character adaptations and bake retargeted full-body motion in Blender.
Sources and licenses: art/vendor/LICENSES.md. Original vendor files stay untouched.
Run Blender --background --python art/build_template_characters.py [-- hero ...]
"""
import bpy, bmesh, math, json, sys
from pathlib import Path
from mathutils import Matrix, Vector, Quaternion
ROOT=Path(__file__).resolve().parents[1]; V=ROOT/'art/vendor'
FPS=30
OLD={'pelvis':'DEF-hips','spine_01':'DEF-spine.001','spine_02':'DEF-spine.002','spine_03':'DEF-spine.003','neck_01':'DEF-neck','Head':'DEF-head','root':'root'}
VRM={'pelvis':'J_Bip_C_Hips','spine_01':'J_Bip_C_Spine','spine_02':'J_Bip_C_Chest','spine_03':'J_Bip_C_UpperChest','neck_01':'J_Bip_C_Neck','Head':'J_Bip_C_Head'}
for s,S in [('l','L'),('r','R')]:
 for new,old,vrm in [('clavicle','shoulder','Shoulder'),('upperarm','upper_arm','UpperArm'),('lowerarm','forearm','LowerArm'),('hand','hand','Hand'),('thigh','thigh','UpperLeg'),('calf','shin','LowerLeg'),('foot','foot','Foot'),('ball','toe','ToeBase')]:
  OLD[new+'_'+s]='DEF-'+old+'.'+S;VRM[new+'_'+s]='J_Bip_'+S+'_'+vrm
 for finger,old in [('index','f_index'),('middle','f_middle'),('ring','f_ring'),('pinky','f_pinky'),('thumb','thumb')]:
  for n in range(1,4):
   key=f'{finger}_{n:02}_{s}';OLD[key]=f'DEF-{old}.{n:02}.{S}';VRM[key]=f'J_Bip_{S}_{"Little" if finger=="pinky" else finger.title()}{n}'
# Each source is sampled in seconds before a new character is created.
CLIPS={
 'work':(1,'Interact'), 'gather':(1,'PickUp_Table'), 'dance':(1,'Dance_Loop'),
 'idle':(1,'Sword_Idle'), 'relax':(1,'Idle_Loop'), 'talk':(1,'Idle_Talking_Loop'),
 'walk':(1,'Walk_Loop'),'run':(1,'Jog_Fwd_Loop'),'sprint':(1,'Sprint_Loop'),
 'roll':(1,'Roll'),'heavy':(1,'Sword_Attack'),'cast':(1,'Spell_Simple_Shoot'),
 'sit':(1,'Sitting_Idle_Loop'),'hurt':(1,'Hit_Chest'),'death':(1,'Death01'),
 'slash_a':(2,'Sword_Regular_A'),'recover_a':(2,'Sword_Regular_A_Rec'),
 'slash_b':(2,'Sword_Regular_B'),'recover_b':(2,'Sword_Regular_B_Rec'),
 'slash_c':(2,'Sword_Regular_C'), 'block':(2,'Sword_Block'),
}
def import_model(path):
 before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(path));objects=set(bpy.data.objects)-before
 return next(o for o in objects if o.type=='ARMATURE'),objects

def sample_sources():
 samples={}
 for library,path in [(1,next((V/'animations').rglob('*.glb'))),(2,next((V/'animations2').rglob('UAL2_Standard.glb')))]:
  bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.scene.render.fps=FPS
  arm,objects=import_model(path);arm.animation_data_create()
  for tr in arm.animation_data.nla_tracks:tr.mute=True
  for name,(lib,source) in CLIPS.items():
   if lib!=library:continue
   action=next(a for a in bpy.data.actions if a.name==source or a.name.endswith('|'+source))
   arm.animation_data.action=action
   if action.slots:arm.animation_data.action_slot=action.slots[0]
   start,end=action.frame_range;duration=(end-start)/FPS;frames=[]
   for f in range(round(duration*FPS)+1):
    bpy.context.scene.frame_set(int(start+f),subframe=(start+f)%1)
    pose={}
    for key in OLD:
     bn=OLD[key] if library==1 else key
     if bn not in arm.data.bones:continue
     bone=arm.data.bones[bn];p=arm.pose.bones[bn]
     pose[key]=(p.matrix.to_quaternion() @ bone.matrix_local.to_quaternion().inverted(), p.matrix.translation-bone.head_local)
    frames.append(pose)
   samples[name]={'duration':duration,'frames':frames,'hip_height':arm.data.bones[OLD['pelvis'] if library==1 else 'pelvis'].head_local.z}
   print('SAMPLED',name,duration,flush=True)
 return samples

def bind_rigid(obj,arm,bone):
 world=obj.matrix_world.copy();obj.parent=arm;obj.matrix_world=world
 for mod in list(obj.modifiers):
  if mod.type=='ARMATURE':obj.modifiers.remove(mod)
 obj.vertex_groups.clear();obj.vertex_groups.new(name=bone).add(list(range(len(obj.data.vertices))),1,'REPLACE')
 mod=obj.modifiers.new('Character skin','ARMATURE');mod.object=arm

def hybrid(outfit,boss=False):
 arm,objects=import_model(next((V/'outfits').rglob(outfit+'.gltf')))
 for o in list(objects):
  if o.type=='MESH' and ('Hood' in o.name or o.name=='Icosphere'):bpy.data.objects.remove(o,do_unlink=True)
 # VRoid facial layers and hair, fitted to the humanoid body's head joint.
 head_arm,head_objs=import_model(V/'vroid_male/HairSample_Male.glb')
 old_head=head_arm.data.bones['J_Bip_C_Head'].head_local.copy();new_head=arm.data.bones['Head'].head_local.copy()
 flip=Matrix.Rotation(math.pi,4,'Z');factor=1.04
 for obj in list(head_objs):
  if obj.type!='MESH':continue
  if 'Body' in obj.name:
   bpy.data.objects.remove(obj,do_unlink=True)
   continue
  transform=Matrix.Translation(new_head) @ Matrix.Scale(factor,4) @ flip @ Matrix.Translation(-old_head)
  obj.data.transform(transform,shape_keys=True);bind_rigid(obj,arm,'Head')
 for obj in list(bpy.data.objects):
  if obj.type=='EMPTY' and obj in head_objs:bpy.data.objects.remove(obj,do_unlink=True)
 bpy.data.objects.remove(head_arm,do_unlink=True)
 for mat in bpy.data.materials:
  if not mat.use_nodes:continue
  bs=next((n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
  if bs and 'Regular_Male' in mat.name:
   for link in list(bs.inputs['Base Color'].links):mat.node_tree.links.remove(link)
   bs.inputs['Base Color'].default_value=(.78,.56,.43,1)
  if boss and 'Ranger' in mat.name:
   for node in mat.node_tree.nodes:
    if node.type=='TEX_IMAGE' and node.image and 'BaseColor' in node.image.name:
     node.image=bpy.data.images.load(str(next((V/'outfits').rglob('T_Ranger_3_BaseColor.png'))),check_existing=True)
  if boss and ('HAIR' in mat.name.upper()):
   for node in mat.node_tree.nodes:
    if node.type=='TEX_IMAGE' and node.image and node.image.colorspace_settings.name!='Non-Color':
     image=node.image
     if not image.name.startswith('WardenSilver'):
      import numpy as np
      image=image.copy();image.name='WardenSilver_'+image.name
      pixels=np.array(image.pixels[:],dtype=np.float32).reshape(-1,4)
      light=np.clip(pixels[:,:3].max(axis=1)*1.4+.24,0,1)
      pixels[:,:3]=light[:,None]*np.array([.79,.86,1.0])
      image.pixels.foreach_set(pixels.ravel());image.pack();node.image=image
 # A clean fitted neck replaces the modern hoodie completely.
 bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=16,location=(0,.018,1.54));neck=bpy.context.object;neck.name='Fitted neck';neck.scale=(.055,.055,.13);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 neck.data.materials.append(material('Character neck',(.78,.56,.43)))
 for p in neck.data.polygons:p.use_smooth=True
 bind_rigid(neck,arm,'neck_01')
 if boss:ornaments(arm)
 return arm,False

def material(name,col,metal=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*col,1);m.use_nodes=True;b=m.node_tree.nodes.get('Principled BSDF');b.inputs['Base Color'].default_value=(*col,1);b.inputs['Metallic'].default_value=metal;b.inputs['Roughness'].default_value=.3;return m

def ornaments(arm):
 gold=material('Warden engraved gold',(.68,.4,.12),.72);ivory=material('Warden porcelain steel',(.72,.79,.83),.58);gem=material('Warden azure enamel',(.05,.46,.6),.42)
 def ellipsoid(name,pos,scale,mat,bone):
  bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=16,location=pos);o=bpy.context.object;o.name=name;o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mat)
  for p in o.data.polygons:p.use_smooth=True
  bind_rigid(o,arm,bone);return o
 def tube(name,coords,radius,mat,bone):
  cu=bpy.data.curves.new(name,'CURVE');cu.dimensions='3D';cu.bevel_depth=radius;cu.bevel_resolution=3;s=cu.splines.new('POLY');s.points.add(len(coords)-1)
  for p,co in zip(s.points,coords):p.co=(*co,1)
  ob=bpy.data.objects.new(name,cu);bpy.context.collection.objects.link(ob);ob.data.materials.append(mat);bpy.context.view_layer.objects.active=ob;ob.select_set(True);bpy.ops.object.convert(target='MESH');bind_rigid(ob,arm,bone);ob.select_set(False)
 # Fitted breastplate, overlapping shoulder lames, bright crest and diadem.
 ellipsoid('Sculpted breastplate',(0,-.09,1.31),(.205,.14,.23),ivory,'spine_03')
 for s,S in [(-1,'r'),(1,'l')]:
  for n in range(3):ellipsoid('Layered pauldron', (s*(.245+n*.035),.038,1.455-n*.035),(.135-n*.017,.133,.069),ivory if n%2 else gold,'upperarm_'+S)
  tube('Breastplate filigree',[(s*.025,-.228,1.19),(s*.115,-.21,1.27),(s*.15,-.192,1.42)],.007,gold,'spine_03')
 ellipsoid('Sunheart',(0,-.239,1.32),(.043,.017,.065),gem,'spine_03')
 h=arm.data.bones['Head'].head_local.z
 tube('Sun diadem',[(.135*math.cos(t),.11*math.sin(t),h+.125) for t in [i*math.tau/64 for i in range(65)]],.013,gold,'Head')
 for i in range(7):
  t=math.pi+i*math.pi/6;x=.129*math.cos(t);y=.112*math.sin(t)
  tube('Diadem point',[(x,y,h+.12),(x*1.05,y*1.05,h+.2+(.035 if i%2 else 0))],.01,gold,'Head')
 # Back halo follows the chest, so it leans with the whole-body attack.
 tube('Radiant halo',[(.37*math.cos(t),.21,1.71+.37*math.sin(t)) for t in [i*math.tau/96 for i in range(97)]],.017,gold,'spine_03')
 for i in range(12):
  t=i*math.tau/12;tube('Sunray',[(.39*math.cos(t),.21,1.71+.39*math.sin(t)),(.46*math.cos(t),.21,1.71+.46*math.sin(t))],.01,gold,'spine_03')

def bake(arm,vrm,samples,names):
 arm.animation_data_create();arm.animation_data.action=None
 for tr in list(arm.animation_data.nla_tracks):arm.animation_data.nla_tracks.remove(tr)
 mapping={key:VRM[key] for key in VRM if VRM[key] in arm.data.bones} if vrm else {key:key for key in OLD if key in arm.data.bones}
 inverse={b:k for k,b in mapping.items()};rest={b.name:b.matrix_local.to_quaternion() for b in arm.data.bones}
 restlocal={b.name:((rest[b.parent.name].inverted() @ rest[b.name]) if b.parent else rest[b.name]) for b in arm.data.bones}
 flip=Quaternion((0,0,1),math.pi) if vrm else Quaternion()
 for name in names:
  data=samples[name];action=bpy.data.actions.new(name);arm.animation_data.action=action
  for bone in arm.pose.bones:bone.rotation_mode='QUATERNION';bone.location=(0,0,0);bone.rotation_quaternion=Quaternion();bone.scale=(1,1,1)
  factor=arm.data.bones[mapping['pelvis']].head_local.z/data['hip_height']
  for f,pose in enumerate(data['frames']):
   frame=f+1;desired={}
   for bone in arm.data.bones:
    bn=bone.name;p=arm.pose.bones[bn];parent=desired[bone.parent.name] if bone.parent else Quaternion();base=parent @ restlocal[bn]
    if bn in inverse and inverse[bn] in pose:
     delta,loc=pose[inverse[bn]];desired[bn]=flip @ delta @ flip.inverted() @ rest[bn];p.rotation_quaternion=base.inverted() @ desired[bn]
     p.keyframe_insert('rotation_quaternion',frame=frame,group=bn)
     if inverse[bn]=='pelvis':
      # Body translation belongs to CharacterBody3D; retain the authored crouch/roll height.
      p.location=base.inverted() @ Vector((0,0,loc.z*factor));p.keyframe_insert('location',frame=frame,group=bn)
    else:desired[bn]=base
  action.use_fake_user=True
  track=arm.animation_data.nla_tracks.new();track.name=name;strip=track.strips.new(name,1,action);strip.name=name;track.mute=True
  print('BAKED',arm.name,name,flush=True)
 arm.animation_data.action=None
 # NLA export includes muted tracks; unmute for predictable exporter discovery.
 for tr in arm.animation_data.nla_tracks:tr.mute=False
 for b in arm.pose.bones:b.rotation_quaternion=Quaternion();b.location=(0,0,0)
 return mapping

def export(arm,name,vrm):
 # The game uses -Z forward. Quaternius' source models face Blender -Y.
 root=bpy.data.objects.new('Character',None);bpy.context.collection.objects.link(root)
 for ob in list(bpy.context.scene.objects):
  if ob!=root and ob.parent is None:
   ob.parent=root
 if not vrm:root.rotation_euler.z=math.pi
 arm.name='Humanoid'
 # Keep packed source files editable; images reduced only in these derived copies.
 for im in bpy.data.images:
  if im.size[0]>2048:im.scale(2048,2048)
  if im.size[0]>0:
   try:im.pack()
   except RuntimeError:pass
 bpy.context.scene.frame_set(1)
 bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender'/f'{name}.blend'))
 bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models'/f'{name}.glb'),export_format='GLB',export_animations=True,export_animation_mode='NLA_TRACKS',export_nla_strips_merged_animation_name='unused',export_force_sampling=True,export_frame_range=False,export_materials='EXPORT',export_yup=True,export_cameras=False,export_lights=False)
 print('EXPORTED',name,flush=True)

samples=sample_sources()
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
for name in args or ['hero_rigged','warden_rigged','citizen_rigged','vivi_rigged','victoria_rigged']:
 bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.scene.render.fps=FPS
 if name in ['hero_rigged','warden_rigged','citizen_rigged']:
  arm,vrm=hybrid('Male_Peasant' if name=='citizen_rigged' else 'Male_Ranger',name=='warden_rigged')
 else:
  arm,objects=import_model(V/('vroid_vivi/AvatarSample_E.glb' if name in ['vivi_rigged','hero_female_rigged'] else 'vroid_blonde/AvatarSample_G.glb'));vrm=True
  for obj in list(objects):
   if obj.type=='MESH' and obj.name=='Icosphere':bpy.data.objects.remove(obj,do_unlink=True)
 names=list(samples) if name in ['hero_rigged','hero_female_rigged','warden_rigged'] else ['relax','talk','walk','sit','work','gather','dance']
 bake(arm,vrm,samples,names);export(arm,name,vrm)
