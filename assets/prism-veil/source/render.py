"""Blender background render runner. Pass 'preview' or 'assets' after --."""
import bpy,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
mode=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'preview'
out=ROOT/'exports';out.mkdir(exist_ok=True)
def render(name,path,w=None,h=None,frame=1):
    scene=bpy.data.scenes['PV / '+name];bpy.context.window.scene=scene;scene.frame_set(frame)
    if w:scene.render.resolution_x=w;scene.render.resolution_y=h
    scene.render.filepath=str(path);bpy.ops.render.render(write_still=True,scene=scene.name)
if mode=='preview':render('Pack Preview',out/'pack-preview.png')
elif mode=='assets':
    render('Skin',out/'skin.png');render('Bullet',out/'bullet.png',256,256)
    render('Background',out/'background.png');render('Tracer',out/'tracer.png',512,128)
    for i in range(16):render('Skin',out/f'skin-{i:02d}.png',256,256,1+i*3)
elif mode=='motion':
    for i in range(48):render('Pack Preview',out/f'preview-{i:02d}.png',1280,720,1+i)
