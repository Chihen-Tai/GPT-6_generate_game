"""Export Quaternius authored Blender models and their original animations. No generated meshes."""
import bpy,json
from pathlib import Path
R=Path(__file__).resolve().parents[1]
out=R/'assets/vendor/monsters';out.mkdir(exist_ok=True)
report={}
for p in sorted((R/'art/vendor/expansion/quaternius-monsters').rglob('*.blend')):
 bpy.ops.wm.open_mainfile(filepath=str(p))
 for o in list(bpy.data.objects):
  if o.type in {'CAMERA','LIGHT'}:bpy.data.objects.remove(o,do_unlink=True)
 # Legacy Blender files use diffuse colors, preserve them in Principled materials.
 for m in bpy.data.materials:
  color=tuple(m.diffuse_color)
  m.use_nodes=True
  m.node_tree.nodes.clear()
  surface=m.node_tree.nodes.new('ShaderNodeBsdfPrincipled')
  surface.inputs['Base Color'].default_value=color
  surface.inputs['Roughness'].default_value=.75
  output=m.node_tree.nodes.new('ShaderNodeOutputMaterial')
  m.node_tree.links.new(surface.outputs['BSDF'],output.inputs['Surface'])
 report[p.stem]={'actions':[a.name for a in bpy.data.actions], 'objects':[o.name for o in bpy.data.objects if o.type=='ARMATURE']}
 arm=next(o for o in bpy.data.objects if o.type=='ARMATURE' and 'Eye' not in o.name)
 arm.animation_data_create()
 for track in list(arm.animation_data.nla_tracks):arm.animation_data.nla_tracks.remove(track)
 arm.animation_data.action=None
 for action in list(bpy.data.actions):
  if not action.name.startswith(p.stem+'_'):continue
  track=arm.animation_data.nla_tracks.new();track.name=action.name
  strip=track.strips.new(action.name,0,action)
  if action.slots:strip.action_slot=action.slots[0]
  track.mute=True
 bpy.ops.export_scene.gltf(filepath=str(out/(p.stem+'.glb')),export_format='GLB',export_animations=True,export_animation_mode='NLA_TRACKS',export_nla_strips=True,export_yup=True)
(out/'adaptation.json').write_text(json.dumps(report,indent=2))
print(report)
