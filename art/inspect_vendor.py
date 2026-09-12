import bpy,sys,json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
for i,(folder,file) in enumerate([('vroid_male','HairSample_Male.glb'),('vroid_vivi','AvatarSample_E.glb'),('vroid_blonde','AvatarSample_G.glb')]):
 before=set(bpy.data.objects)
 bpy.ops.import_scene.gltf(filepath=str(ROOT/'art/vendor'/folder/file))
 objects=set(bpy.data.objects)-before
 arm=next(o for o in objects if o.type=='ARMATURE')
 print('MODEL',folder,'ARM',arm.name,'matrix',list(arm.matrix_world),'BONES',len(arm.data.bones),flush=True)
 for key in ['J_Bip_C_Hips','J_Bip_C_Head','J_Bip_L_Foot','J_Bip_L_ToeBase','J_Bip_L_UpperArm']:
  b=arm.data.bones[key];print(key,tuple(b.head_local),tuple(b.tail_local),flush=True)
 for o in objects:
  if o.parent is None:o.location.x+=(i-1)*2.5
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=12;scene.cycles.use_denoising=True
scene.render.resolution_x=1500;scene.render.resolution_y=650;scene.render.resolution_percentage=100
scene.world.color=(.5,.5,.5);scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.35,.42,.43,1);scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.8
bpy.ops.object.camera_add(location=(0,-8,1.7));cam=bpy.context.object;cam.data.type='ORTHO';cam.data.ortho_scale=8;cam.rotation_euler=(Vector((0,0,1.0))-cam.location).to_track_quat('-Z','Y').to_euler();scene.camera=cam
scene.view_settings.view_transform='Standard';scene.render.filepath=str(ROOT/'screenshots/vendor-candidates.png');bpy.ops.render.render(write_still=True)
# Inspect source clip and rig conventions separately.
for path in [next((ROOT/'art/vendor/animations').rglob('*.glb')),next((ROOT/'art/vendor/animations2').rglob('UAL2_Standard.glb'))]:
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.ops.import_scene.gltf(filepath=str(path))
 arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
 print('ANIMATION_RIG',path.name,arm.name, 'MATRIX',list(arm.matrix_world),flush=True)
 print('ACTIONS',[(a.name,tuple(a.frame_range)) for a in bpy.data.actions],flush=True)
 print('BONES',[(b.name,tuple(round(v,3) for v in b.head_local),tuple(round(v,3) for v in b.tail_local)) for b in arm.data.bones if any(k in b.name.lower() for k in ['hips','pelvis','thigh','upperarm','upper_arm','foot','toe','root'])],flush=True)
