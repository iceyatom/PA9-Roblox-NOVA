"""Run with Blender --background --factory-startup --python blender_scene.py."""
import math
import sys
from pathlib import Path
import bpy

sys.path.insert(0,str(Path(__file__).parent))
from illustrate import CAT, ROOT, asset

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene
scene.name='NOVA • Items Batch 1'
scene.render.engine='BLENDER_WORKBENCH'
scene.display.shading.light='FLAT'
scene.display.shading.color_type='MATERIAL'
scene.display.shading.show_shadows=False
scene.display.shading.show_specular_highlight=False
scene.render.film_transparent=True
scene.render.resolution_x=scene.render.resolution_y=512
scene.render.resolution_percentage=100
scene.view_settings.view_transform='Standard'
materials={}
for n,group in enumerate(CAT['sets']):
    collection=bpy.data.collections.new(group['set_id'])
    scene.collection.children.link(collection)
    for j,key in enumerate(['skins','bullets','tracers','backgrounds','sounds','card','strip','body']+(['chest'] if n==0 else [])):
        vertices=[]; faces=[]; slots=[]
        mesh=bpy.data.meshes.new(key)
        for depth,(polygon,color) in enumerate(asset(n,key)):
            if color not in materials:
                mat=bpy.data.materials.new('Cel '+color)
                rgb=[int(color[i:i+2],16)/255 for i in (1,3,5)]
                mat.diffuse_color=tuple(((v+.055)/1.055)**2.4 if v>.04045 else v/12.92 for v in rgb)+(1,)
                materials[color]=mat
            if color not in slots:
                slots.append(color); mesh.materials.append(materials[color])
            faces.append(tuple(range(len(vertices),len(vertices)+len(polygon)))[::-1])
            vertices.extend([(x/100-.5,.5-y/100,depth*.00025) for x,y in polygon])
        mesh.from_pydata(vertices,[],faces);mesh.update()
        for face,(_,color) in zip(mesh.polygons,asset(n,key)):face.material_index=slots.index(color)
        obj=bpy.data.objects.new(group['name']+' / '+key,mesh)
        collection.objects.link(obj); obj.location=(j*1.2,-n*1.2,0)
camera=bpy.data.cameras.new('Icon orthographic • 512');camera.type='ORTHO';camera.ortho_scale=1
obj=bpy.data.objects.new('Camera • Mint Circuit Shell',camera)
scene.collection.objects.link(obj);obj.location=(0,0,5);scene.camera=obj
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'source/NOVA Batch 1.blend'),compress=True)
