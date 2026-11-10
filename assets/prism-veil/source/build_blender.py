"""Prism Veil: editable orthographic 2D geometry and looping Blender animation.

Run inside Blender. Existing scenes are preserved. Native meshes, materials,
curves and keyframes are the source artwork; no generated bitmaps are used.
"""
import bpy, math, random
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
ROOT.mkdir(parents=True,exist_ok=True)
(ROOT/'exports').mkdir(exist_ok=True)
P={'ink':'201b43','deep':'464775','violet':'9b33ff','pink':'f36bea','cyan':'5ee9ed',
   'mint':'67f6c0','white':'f4f4ff','pearl':'c9d8fb','shade':'959bce','gold':'f7d292','dark':'0b1022'}
M={}
def material(key):
    if key in M:return M[key]
    value=P.get(key,key); rgb=[int(value[i:i+2],16)/255 for i in (0,2,4)]
    mat=bpy.data.materials.new('PV / '+key); mat.diffuse_color=(*rgb,1); mat.use_nodes=True
    nodes=mat.node_tree.nodes; nodes.clear(); out=nodes.new('ShaderNodeOutputMaterial'); em=nodes.new('ShaderNodeEmission')
    em.inputs['Color'].default_value=(*[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb],1)
    em.inputs['Strength'].default_value=1; mat.node_tree.links.new(em.outputs[0],out.inputs[0]); M[key]=mat
    return mat
def collection(name):return bpy.data.collections.new('PV / '+name)
def poly(col,name,points,color,z=0,parent=None):
    mesh=bpy.data.meshes.new('PV / '+name); mesh.from_pydata([(x,y,z) for x,y in points],[],[tuple(range(len(points)))])
    mesh.materials.append(material(color)); mesh.update()
    obj=bpy.data.objects.new('PV / '+name,mesh); col.objects.link(obj)
    if parent:obj.parent=parent
    return obj
def rect(col,name,x,y,w,h,color,z=0,parent=None):
    return poly(col,name,[(x-w/2,y-h/2),(x+w/2,y-h/2),(x+w/2,y+h/2),(x-w/2,y+h/2)],color,z,parent)
def disc(col,name,x,y,r,color,z=0,n=80,parent=None):
    return poly(col,name,[(x+r*math.cos(i*math.tau/n),y+r*math.sin(i*math.tau/n)) for i in range(n)],color,z,parent)
def line(col,name,points,color,width=.016,z=.1,parent=None):
    curve=bpy.data.curves.new('PV / '+name,'CURVE'); curve.dimensions='3D'; curve.bevel_depth=width; curve.bevel_resolution=2; curve.resolution_u=1
    spline=curve.splines.new('POLY'); spline.points.add(len(points)-1)
    for p,(x,y) in zip(spline.points,points):p.co=(x,y,z,1)
    obj=bpy.data.objects.new('PV / '+name,curve); col.objects.link(obj); curve.materials.append(material(color))
    if parent:obj.parent=parent
    return obj
def empty(col,name):
    obj=bpy.data.objects.new('PV / '+name,None);col.objects.link(obj);return obj
def animate(obj,fn):
    for frame in range(1,50,3):
        t=(frame-1)/48*math.tau
        loc,rot,scale=fn(t)
        obj.location=loc; obj.rotation_euler=(0,0,rot);obj.scale=(scale,scale,1)
        obj.keyframe_insert(data_path='location',frame=frame);obj.keyframe_insert(data_path='rotation_euler',frame=frame);obj.keyframe_insert(data_path='scale',frame=frame)
def crystal(col,name,x,y,size,color,z=.2,turn=0):
    root=empty(col,name)
    pts=[(0,size),(.6*size,0),(0,-size),(-.6*size,0)]
    poly(col,name+' outline',[(a*1.1,b*1.1) for a,b in pts],color,z,root)
    poly(col,name+' glass',pts,'white',z+.001,root)
    poly(col,name+' facet',[(0,size),(.6*size,0),(0,-size),(0,0)],'pearl',z+.002,root)
    root.location=(x,y,0);root.rotation_euler.z=turn;return root
def scene(name,col,width,height):
    s=bpy.data.scenes.new('PV / '+name);s.collection.children.link(col)
    s.render.engine='CYCLES';s.cycles.samples=1;s.cycles.use_denoising=False
    s.render.film_transparent=True;s.render.resolution_x=width;s.render.resolution_y=height;s.render.resolution_percentage=100
    s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA'
    s.view_settings.view_transform='Standard';s.view_settings.look='None';s.render.fps=24;s.frame_start=1;s.frame_end=48
    cam=bpy.data.cameras.new('PV / '+name+' camera');cam.type='ORTHO';cam.ortho_scale=2.08 if name=='Skin' else 2.6 if name=='Bullet' else 10.5 if name=='Tracer' else 10 if name=='Background' else 17
    obj=bpy.data.objects.new(cam.name,cam);s.collection.objects.link(obj);obj.location=(0,0,15);s.camera=obj
    return s

# SQUARE SKIN: static outer silhouette with sliding four-way glass panels INSIDE it.
skin=collection('Skin • sliding glass quadrants')
rect(skin,'square violet outline',0,0,2,2,'violet')
rect(skin,'square mint rim',0,0,1.94,1.94,'mint',.002)
rect(skin,'square pearl chassis',0,0,1.88,1.88,'pearl',.004)
rect(skin,'dark recessed core',0,0,1.58,1.58,'deep',.006)
for i in range(4):
    root=empty(skin,'sliding quadrant '+str(i+1))
    pts=[(-.76,.76),(-.09,.76),(-.09,.29),(-.29,.09),(-.76,.09)]
    theta=i*math.pi/2
    pts=[(x*math.cos(theta)-y*math.sin(theta),x*math.sin(theta)+y*math.cos(theta)) for x,y in pts]
    poly(skin,'quadrant neon seam '+str(i),pts,'pink' if i%2==0 else 'cyan',.02,root)
    inner=[(x*.94,y*.94) for x,y in pts];poly(skin,'quadrant glass '+str(i),inner,'white',.024,root)
    poly(skin,'quadrant iridescent facet '+str(i),[inner[0],inner[1],inner[2]],'shade' if i%2 else 'pearl',.026,root)
    animate(root,lambda t,i=i:((.045*math.sin(t+i*math.pi/2),.045*math.cos(t+i*math.pi/2),0),0,1))
for i in range(4):
    a=i*math.pi/2
    pts=[(.90,.53),(.90,.90),(.53,.90)]
    pts=[(x*math.cos(a)-y*math.sin(a),x*math.sin(a)+y*math.cos(a)) for x,y in pts]
    line(skin,'gold corner '+str(i),pts,'gold',.025,.08)
core=empty(skin,'rotating prism reactor')
for i,c in enumerate(['cyan','pink','violet','white']):
    a=i*math.pi/2;poly(skin,'core facet '+str(i),[(0,0),(.28*math.cos(a),.28*math.sin(a)),(.28*math.cos(a+math.pi/2),.28*math.sin(a+math.pi/2))],c,.1,core)
animate(core,lambda t:((0,0,0),t,1+.08*math.sin(t*2)))
for i in range(4):
    q=crystal(skin,'orbital internal shard '+str(i),0,0,.06,'cyan' if i%2 else 'pink',.12)
    animate(q,lambda t,i=i:((.46*math.cos(t+i*math.pi/2),.46*math.sin(t+i*math.pi/2),0),t,1))
scene('Skin',skin,512,512)

# BULLET: intentionally simple, round pearl texture with thin spectral rings.
bullet=collection('Bullet • circular pearl')
for j,(r,c) in enumerate([(1,'violet'),(.94,'pink'),(.86,'cyan'),(.77,'white'),(.62,'pearl'),(.49,'white')]):
    disc(bullet,'pearl circle '+str(j),0,0,r,c,j*.003)
disc(bullet,'upper gloss',-.18,.23,.19,'white',.04)
line(bullet,'gold ring accent',[(.7*math.cos(a),.7*math.sin(a)) for a in [i*.04+.1 for i in range(24)]],'gold',.035,.05)
pearl=empty(bullet,'pearl rotation')
for obj in list(bullet.objects):
    if obj!=pearl:obj.parent=pearl
animate(pearl,lambda t:((0,0,0),t,1))
scene('Bullet',bullet,512,512)

# BACKGROUND: expansive pale iridescent glass, with slow separate drifting facets.
bg=collection('Background • prismatic sky')
rect(bg,'lilac sky',0,0,10,5,'b5bde8',0)
poly(bg,'cyan atmosphere',[(-5,-2.5),(-5,2.5),(1,2.5),(4,-2.5)],'b9e5f1',.001)
poly(bg,'pink atmosphere',[(-5,-2.5),(-1,2.5),(5,2.5),(5,-2.5)],'e7d2f1',.002)
poly(bg,'pearl horizon',[(-5,-1.3),(0,.4),(5,-.7),(5,-2.5),(-5,-2.5)],'e8f3fd',.003)
for i in range(3):
    pts=[(-5+j*.16, .5*math.sin(j*.10+i)+.2*i-.6) for j in range(64)]
    line(bg,'spectral flowing arc '+str(i),pts,['white','cyan','pink'][i],.012,.02)
rng=random.Random(390)
for i in range(18):
    x,y=rng.uniform(-4.7,4.7),rng.uniform(-2.1,2.1);size=rng.uniform(.12,.49);turn=rng.uniform(-.6,.6)
    obj=crystal(bg,'floating sky crystal '+str(i),x,y,size,['cyan','pink','mint'][i%3],.04,turn)
    animate(obj,lambda t,x=x,y=y,i=i,turn=turn:((x+.12*math.sin(t+i),y+.10*math.cos(t+i),0),turn+.12*math.sin(t+i),1))
for i in range(22):
    x,y=rng.uniform(-5,5),rng.uniform(-2.5,2.5)
    line(bg,'starlight h '+str(i),[(x-.035,y),(x+.035,y)],'white',.008,.08)
    line(bg,'starlight v '+str(i),[(x,y-.06),(x,y+.06)],'white',.008,.08)
scene('Background',bg,1024,512)

# TRACER: geometry ripples and moving sparks, no rendered trail frames at runtime.
tracer=collection('Tracer • live flowing ribbons')
for ribbon in range(3):
    for segment in range(22):
        root=empty(tracer,'ribbon segment %d %d'%(ribbon,segment))
        color=['pink','cyan','mint'][ribbon]
        for j,(w,c) in enumerate([(.074,'deep'),(.044,color),(.011,'white')]):
            rect(tracer,'ribbon %d segment %d layer %d'%(ribbon,segment,j),0,0,.43,w,c,.02+j*.004,root)
        def move(t,r=ribbon,k=segment):
            x=-4.5+k*.41;fade=(k/21)**.7
            y=math.sin(k*.31-t*2+r*2.1)*(.12+.25*fade)+(r-1)*.16
            slope=math.cos(k*.31-t*2+r*2.1)*.30
            return ((x,y,0),slope,1)
        animate(root,move)
for i in range(14):
    q=crystal(tracer,'travelling shard '+str(i),0,0,.06+(i%3)*.025,['cyan','pink','mint'][i%3],.12)
    animate(q,lambda t,i=i:((4.2-((t/math.tau*8+i*.61)%8.5),math.sin(t*2+i)*(.25+(i%4)*.12),0),t*2+i,1))
for i in range(22):
    q=disc(tracer,'flowing sparkle '+str(i),0,0,.017+(i%3)*.006,'white',.14,n=12)
    animate(q,lambda t,i=i:((4.3-((t/math.tau*8+i*.37)%8.7),math.sin(t*3+i)*(.3+(i%5)*.13),0),0,.7+.3*math.sin(t*3+i)))
disc(tracer,'bullet endpoint halo',4.65,0,.25,'cyan',.18)
disc(tracer,'bullet endpoint pearl',4.65,0,.18,'white',.19)
scene('Tracer',tracer,1024,256)

# ANIMATED PRESENTATION: linked instances of the actual component collections.
presentation=collection('Presentation')
rect(presentation,'dark review canvas',0,0,17,9.5625,'dark',-1)
def instance(col,name,x,y,scale):
    obj=bpy.data.objects.new('PV / '+name,None);obj.instance_type='COLLECTION';obj.instance_collection=col
    presentation.objects.link(obj);obj.location=(x,y,0);obj.scale=(scale,scale,scale);return obj
instance(skin,'skin preview',-5.8,1.35,1.22)
instance(bullet,'bullet preview',-2.65,1.35,.68)
instance(tracer,'tracer preview',2.65,1.35,.60)
instance(bg,'background preview',0,-2.45,.68)
def text(name,value,x,y,size,color):
    curve=bpy.data.curves.new('PV / '+name,'FONT');curve.body=value;curve.size=size;curve.space_character=1.1
    obj=bpy.data.objects.new(curve.name,curve);presentation.objects.link(obj);obj.location=(x,y,.3);curve.materials.append(material(color))
text('Title','PRISM VEIL',-7.2,3.7,.55,'white')
text('Subtitle','IRIDESCENT GLASS  /  CYAN + ORCHID  /  GOLD FILIGREE',-7.2,3.2,.17,'pearl')
text('Skin caption','ANIMATED SQUARE BODY',-7.0,-.28,.18,'cyan')
text('Bullet caption','PEARL PULSE',-3.45,-.28,.18,'pink')
text('Tracer caption','FLOWING PRISM WAKE',.15,-.28,.18,'mint')
text('Background caption','PRISMATIC SKY  /  DRIFTING CRYSTALS',-3.4,-4.42,.17,'pearl')
hero=scene('Pack Preview',presentation,1600,900)
bpy.context.window.scene=hero
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':area.spaces.active.region_3d.view_perspective='CAMERA'
hero.frame_set(1)
if (ROOT/'reference.png').is_file():
    reference=bpy.data.images.load(str(ROOT/'reference.png'),check_existing=True);reference.pack();reference.name='PV / supplied reference (packed)'
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'Prism Veil.blend'),compress=True,copy=True)
result={'blend':str(ROOT/'Prism Veil.blend'),'scenes':[s.name for s in bpy.data.scenes if s.name.startswith('PV /')], 'objects':sum(len(c.objects) for c in [skin,bullet,bg,tracer,presentation])}
