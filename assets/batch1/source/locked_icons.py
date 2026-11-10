"""Render neutral locked-state icons from the original authored polygon layers."""
from illustrate import ROOT, CAT, asset, render
from PIL import Image

def neutral(layers):
    result=[]
    for points,color in layers:
        rgb=bytes.fromhex(color[1:])
        value=round(.299*rgb[0]+.587*rgb[1]+.114*rgb[2])
        result.append((points,'#'+bytes([value]*3).hex()))
    return result

for category in [c['id'] for c in CAT['categories']]:
    sheets=[Image.new('RGBA',(1024,1024)) for _ in range(2)]
    for n in range(25):
        pic=render(neutral(asset(n,category)),(256,256))
        sheets[n//16].paste(pic,((n%4)*256,((n%16)//4)*256))
    for i,sheet in enumerate(sheets):
        sheet.save(ROOT/'delivery'/f'{category}-{i+1}-locked.png')
render(neutral(asset(0,'chest')),(512,512)).save(ROOT/'delivery/chest-locked.png')
