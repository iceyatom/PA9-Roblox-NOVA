"""NOVA layered orthographic cel artwork. Geometry also feeds the editable Blender source."""
import argparse
import json
import math
from pathlib import Path
from card_scenes import compose



ROOT = Path(__file__).resolve().parents[1]
CAT = json.loads((ROOT/'source/catalog.json').read_text())
INK = '#111321'
LIGHT = '#f7fbff'
# Original insignia paths, drawn in a 20-unit square, in catalog order.
MARKS = [
    '1,4 12,4 12,9 19,9 19,15 9,15 9,10 1,10',
    '2,2 9,2 18,10 9,18 2,18 11,10',
    '2,2 13,2 13,6 18,6 18,17 7,17 7,13 2,13',
    '5,18 2,12 7,5 8,10 14,0 14,7 18,10 16,16 12,19',
    '1,8 8,1 14,3 19,10 12,19 7,15',
    '16,1 8,3 3,7 2,13 5,17 11,19 18,17 11,15 8,11 9,6',
    '1,17 6,8 12,3 18,2 17,8 13,14 6,16 10,10',
    '1,14 5,5 11,3 19,5 16,12 9,17 3,17 12,9',
    '10,2 13,6 18,5 19,10 15,13 14,18 9,16 5,18 4,13 1,10 3,5 8,6',
    '1,5 6,5 6,1 14,1 14,5 18,5 18,13 14,13 14,17 6,17 6,13 1,13',
    '9,1 18,1 12,8 18,8 4,20 7,12 2,12',
    '1,12 5,7 10,4 16,5 19,10 14,8 11,10 12,13 16,14 19,13 16,17 9,18 4,17',
    '2,4 11,1 8,8 14,7 11,12 18,10 14,17 5,19 7,12 1,13',
    '1,10 9,2 17,4 19,10 13,17 5,17 11,12 15,8 10,8 4,13',
    '1,3 9,6 13,2 14,7 19,5 16,12 12,16 4,19 7,13',
    '1,15 8,2 13,2 19,16 12,13 10,8 7,13',
    '1,10 5,10 5,4 9,4 9,1 13,1 13,7 17,7 17,17 1,17',
    '1,6 6,1 12,1 15,4 9,4 6,7 10,11 7,14 1,9',
    '1,5 6,9 10,1 13,9 19,4 16,16 4,16',
    '1,13 3,6 7,8 10,1 15,5 14,10 18,7 17,14 10,19',
    '1,3 14,3 14,6 19,6 19,10 11,10 11,13 17,13 17,17 3,17 3,13 7,13 7,9 1,9',
    '10,0 12,5 17,2 16,7 20,10 16,12 18,17 13,16 10,20 7,15 2,17 4,12 0,10 5,7 3,2 8,5',
    '1,2 7,5 11,10 10,3 15,6 16,1 19,8 15,13 9,19 10,14 5,12',
    '0,6 7,6 10,0 13,6 20,6 15,11 17,17 10,14 3,18 5,11',
    '17,2 9,2 4,6 2,11 4,16 9,19 14,18 18,14 19,10 16,12 13,15 9,15 6,12 7,8 11,6 16,6',
]

def blend(a,b,k):
    a,b=bytes.fromhex(a[1:]),bytes.fromhex(b[1:])
    return '#'+bytes(round(x*(1-k)+y*k) for x,y in zip(a,b)).hex()

def ellipse(x,y,rx,ry,steps=48):
    return [(x+rx*math.cos(i*math.tau/steps),y+ry*math.sin(i*math.tau/steps)) for i in range(steps)]

def asset(n,category,phase=0):
    group=CAT['sets'][n]
    main,accent=group['palette'].split(' / ')
    shadow=blend(main,INK,.62)
    shine=blend(main,LIGHT,.63)
    layers=[]
    def poly(points,color):
        layers.append((points,color))
    def plate(points,color,edge=.1):
        poly(points,INK)
        x=sum(a for a,b in points)/len(points)
        y=sum(b for a,b in points)/len(points)
        poly([(a+(x-a)*edge,b+(y-b)*edge) for a,b in points],color)
    def oval(x,y,rx,ry,c):
        poly(ellipse(x,y,rx,ry),c)
    def mark(x,y,scale,c=accent):
        coords=[tuple(map(int,p.split(','))) for p in MARKS[n].split()]
        def path(dx,dy,s):
            return [(x+(a-10)*s+dx,y+(b-10)*s+dy) for a,b in coords]
        poly(path(0,1.4,scale*1.16),INK)
        poly(path(0,0,scale),c)
        if n==17:
            poly([(2*x-a,2*y-b) for a,b in path(-4,0,scale*.85)],shine)
    if category=='body':
        # Square combat hull follows the exact existing body bounds.
        poly([(0,0),(100,0),(100,100),(0,100)],shadow)
        designs=[
            [(3,4),(70,4),(51,23),(29,23),(16,38),(3,38)],
            [(3,4),(43,4),(69,32),(52,45),(29,23),(3,23)],
            [(3,4),(39,4),(39,19),(55,19),(55,34),(23,34),(23,26),(3,26)],
            [(3,4),(57,4),(47,17),(34,21),(32,35),(19,28),(3,44)],
            [(3,4),(55,4),(30,36),(3,47)],
        ]
        motif=designs[n%5]
        poly(motif,main)
        poly([(100-x,100-y) for x,y in motif],blend(accent,main,.24))
        poly([(4,54),(14,42),(25,44),(13,61),(13,82),(4,92)],main)
        poly([(82,8),(96,5),(96,34),(86,48),(78,47),(87,32)],accent)
        poly([(7,7),(36,7),(29,11),(8,13)],shine)
        if n==24:
            oval(52,53,25,25,accent);oval(52,53,20,20,INK)
            poly([(37,47),(46,34),(59,33),(49,39)],LIGHT)
        else:
            mark(52,52,2.0,blend(accent,shine,.44))
        poly([(15,88),(31,75),(49,78),(40,87),(25,92)],blend(main,INK,.27))
    elif category=='skins':
        plate([(13,23),(29,14),(43,19),(58,19),(71,14),(87,22),(83,44),(74,48),(71,76),(53,86),(30,77),(25,48),(17,44)],shadow)
        plate([(15,25),(30,18),(42,24),(36,36),(20,39)],main)
        plate([(60,24),(72,18),(84,25),(79,39),(64,35)],main)
        plate([(31,37),(42,29),(58,29),(70,38),(66,68),(51,77),(35,68)],main)
        poly([(34,40),(44,32),(56,32),(51,36),(40,41)],shine)
        poly([(34,60),(50,66),(68,57),(65,69),(51,76),(36,69)],shadow)
        mark(51,49,1.12,blend(accent,LIGHT,.19))
        poly([(19,26),(29,21),(32,22),(22,29)],LIGHT)
    elif category=='bullets':
        oval(50,50,36,36,INK);oval(50,50,32.8,32.8,shadow)
        oval(48,47,29,29,main)
        poly([(24,41),(30,28),(44,22),(59,23),(49,27),(34,34)],shine)
        poly([(57,69),(70,57),(74,43),(76,55),(68,68)],accent)
        mark(50,49,1.55,blend(accent,LIGHT,.19))
        oval(34,30,4.8,2.8,LIGHT)
    elif category in ('tracers','strip'):
        tier=CAT['rarities'][group['rarity']]['layers']
        for strand in range(tier):
            pts=[]
            for j in range(33):
                t=j/32
                wobble=math.sin(t*(3+n%5)+phase*math.tau+strand*2.1)
                if n in (9,20): wobble=round(wobble*2)/2
                y=50+((strand-(tier-1)/2)*4+wobble*(2+n%4))*math.sin(t*math.pi)
                if category=='tracers': y+=25-49*t
                pts.append((12+t*74,y))
            color=main if strand%2==0 else accent
            for thickness,c in ((5.5,INK),(3.6,color),(1,shine)):
                poly([(x,y-thickness*(j/32)**.75) for j,(x,y) in enumerate(pts)]+[(x,y+thickness*(j/32)**.75) for j,(x,y) in reversed(list(enumerate(pts)))],c)
        if category=='tracers':
            mark(72,35,.97,shine)
            poly([(27,56),(31,51),(34,51),(30,57)],accent)
        if n==24:
            for start in (0,math.pi):
                arc=[start+phase*math.tau+i*.12 for i in range(21)]
                cy=44 if category=='tracers' else 50
                poly([(64+9*math.cos(t),cy+8*math.sin(t)) for t in arc]+[(64+6*math.cos(t),cy+5*math.sin(t)) for t in reversed(arc)],shine)
    elif category in ('backgrounds','card'):
        if category=='backgrounds':
            plate([(12,23),(84,18),(89,24),(86,74),(17,81),(11,75)],blend(accent,shine,.34))
            scene=compose(n,main,accent,shadow,shine,blend)
            for points,color in scene:
                # Scene may bleed off the widescreen crop. Keep thumb art inside the bezel.
                poly([(18+.63*max(0,min(100,x)),29+.43*max(0,min(100,y))-.05*max(0,min(100,x))) for x,y in points],color)
            poly([(18,28),(42,26),(35,28),(19,30)],shine)
        else:
            layers.extend(compose(n,main,accent,shadow,shine,blend))
    elif category=='sounds':
        plate([(13,39),(29,38),(48,22),(56,24),(55,78),(49,81),(29,63),(15,62)],main)
        poly([(17,43),(29,42),(29,57),(18,58)],shine)
        poly([(34,59),(49,70),(50,31),(53,29),(52,76)],shadow)
        for j,h in enumerate((8,16,23,13)):
            x=60+j*7; h+=3*math.sin(n+j)
            plate([(x,50-h),(x+4,48-h),(x+4,50+h),(x,52+h)],accent,.18)
        mark(41,50,.79,shine)
    else:
        plate([(12,36),(22,21),(72,19),(85,29),(88,67),(75,78),(24,82),(12,73)],'#494363')
        plate([(16,36),(25,25),(69,23),(81,31),(76,45),(20,49)],'#786a9a')
        poly([(19,36),(27,27),(61,25),(54,29),(28,32)],'#dbd7ee')
        plate([(18,51),(75,47),(74,73),(23,77)],'#38314e')
        plate([(39,44),(53,42),(58,49),(55,61),(44,63),(38,56)],'#59e0aa')
        poly([(45,49),(51,48),(48,55),(54,51),(49,58),(44,58)],LIGHT)
        for i in range(5): oval(26+i*9,68-i*.6,1.9,1.9,['#59e0aa','#527eff','#b56dff','#ffc857','#ee626e'][i])
    return layers

def render(layers,size):
    from PIL import Image, ImageDraw
    w,h=size
    canvas=Image.new('RGBA',(w*2,h*2))
    draw=ImageDraw.Draw(canvas)
    for points,color in layers:
        draw.polygon([(x*w*.02,y*h*.02) for x,y in points],fill=color)
    return canvas.resize(size,Image.Resampling.LANCZOS)

def main(anchors):
    from PIL import Image
    export=ROOT/'exports'
    out=ROOT/'delivery'
    export.mkdir(exist_ok=True); out.mkdir(exist_ok=True)
    groups=[0,17,24] if anchors else range(25)
    cats=[c['id'] for c in CAT['categories']]
    atlases={}
    review=Image.new('RGB',(5*100,len(groups)*88),'#111520')
    for row,n in enumerate(groups):
        group=CAT['sets'][n]
        for k,cat in enumerate(cats+['card']):
            pic=render(asset(n,cat),(1024,512) if cat=='card' else (512,512))
            name=group['set_id']+'_card' if cat=='card' else group['item_ids'][k]
            pic.save(export/(name+'.png'))
            w,h=(512,256) if cat=='card' else (256,256)
            cols=1024//w; count=cols*(1024//h); idx=n%count
            label=f'{cat}-{n//count+1}'
            sheet=atlases.setdefault(label,Image.new('RGBA',(1024,1024)))
            sheet.paste(pic.resize((w,h),Image.Resampling.LANCZOS),((idx%cols)*w,(idx//cols)*h))
            if k<5:
                thumb=pic.resize((80,80),Image.Resampling.LANCZOS)
                review.paste(thumb,(k*100+10,row*88+4),thumb)
        if not anchors:
            body=render(asset(n,'body'),(256,256))
            body.save(export/(group['item_ids'][0]+'_body.png'))
            atlas=atlases.setdefault('body-1',Image.new('RGBA',(1024,1024)))
            atlas.paste(body.resize((128,128),Image.Resampling.LANCZOS),((n%8)*128,(n//8)*128))
            frames=CAT['rarities'][group['rarity']]['frames']
            sheet=Image.new('RGBA',(4*128,4*128))
            for i in range(frames):
                pic=render(asset(n,'strip',i/frames),(128,128))
                sheet.paste(pic,((i%4)*128,(i//4)*128))
            sheet.save(export/(group['item_ids'][2]+'_sheet.png'))
            label=f'wakes-{n//4+1}'
            atlas=atlases.setdefault(label,Image.new('RGBA',(1024,1024)))
            atlas.paste(sheet,((n%2)*512,((n%4)//2)*512))
    if not anchors:
        for label,sheet in atlases.items():sheet.save(out/(label+'.png'))
        chest=render(asset(0,'chest'),(512,512)); chest.save(out/'chest.png')
    review.save(ROOT/('anchors.png' if anchors else 'collection.png'))

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--anchors',action='store_true')
    main(parser.parse_args().anchors)
