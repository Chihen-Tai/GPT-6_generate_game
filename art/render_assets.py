"""Render the actual Blender source assets for art review (not concept images)."""
import bpy
import math
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'screenshots'


def point(obj,target):
    obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()


def light(name,location,power,size,color,target):
    data=bpy.data.lights.new(name,'AREA')
    data.energy=power
    data.shape='DISK'
    data.size=size
    data.color=color
    obj=bpy.data.objects.new(name,data)
    bpy.context.collection.objects.link(obj)
    obj.location=location
    point(obj,target)


def render(asset,location,target,ortho,power=1):
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art'/'blender'/(asset+'.blend')))
    scene=bpy.context.scene
    scene.render.engine='CYCLES'
    scene.cycles.samples=32
    scene.cycles.use_denoising=True
    scene.render.resolution_x=1200
    scene.render.resolution_y=1200
    scene.render.resolution_percentage=100
    scene.world.color=(.22,.25,.24)
    scene.world.use_nodes=True
    scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.2,.25,.23,1)
    scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.35
    bpy.ops.mesh.primitive_plane_add(size=200)
    floor=bpy.context.object
    material=bpy.data.materials.new('Studio sage backdrop')
    material.diffuse_color=(.10,.145,.13,1)
    floor.data.materials.append(material)
    floor.location.z=-.025
    bpy.ops.object.camera_add(location=location)
    camera=bpy.context.object
    camera.data.type='ORTHO'
    camera.data.ortho_scale=ortho
    point(camera,target)
    scene.camera=camera
    light('Warm key',(4*power,5*power,7*power),750*power*power,5*power,(1,.86,.66),target)
    light('Cool fill',(-3*power,2*power,4*power),420*power*power,4*power,(.63,.82,1),target)
    light('Rim light',(2*power,-4*power,6*power),950*power*power,3*power,(1,.85,.57),target)
    scene.view_settings.view_transform='AgX'
    scene.render.image_settings.file_format='PNG'
    scene.render.filepath=str(OUT/('blender-'+asset+'.png'))
    bpy.ops.render.render(write_still=True)
    print('RENDER_COMPLETE',asset,flush=True)


render('traveler',(.8,5,2.1),(0,0,1.05),2.45)
render('sunwarden',(.8,5,2.1),(0,0,1.05),2.5)
render('cottage',(11,15,10),(0,0,3.1),11,3)
render('horse',(4,6,3.2),(0,0,1.3),3.3,1.5)
