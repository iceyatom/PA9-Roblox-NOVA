"""Landscapes and architecture for the 25 player cards. Coordinates span 100 x 100."""
from math import sin, cos, pi

def compose(n,main,accent,dark,shine,blend):
    ink='#101323'
    base=blend(main,ink,.87)
    back=blend(main,base,.64)
    mid=blend(main,base,.42)
    glint=blend(accent,shine,.36)
    shapes=[]
    def poly(points,color): shapes.append((points,color))
    def rect(x,y,w,h,color): poly([(x,y),(x+w,y),(x+w,y+h),(x,y+h)],color)
    def ellipse(x,y,rx,ry,color):
        poly([(x+rx*cos(i*pi/32),y+ry*sin(i*pi/32)) for i in range(64)],color)
    def arc(x,y,rx,ry,width,start,end,color):
        t=[(start+(end-start)*i/56)*pi/180 for i in range(57)]
        poly([(x+rx*cos(a),y+ry*sin(a)) for a in t]+
             [(x+(rx-width)*cos(a),y+(ry-width*1.4)*sin(a)) for a in reversed(t)],color)
    def line(points,width,color):
        for (x,y),(a,b) in zip(points,points[1:]):
            length=((a-x)**2+(b-y)**2)**.5
            if not length:continue
            dx,dy=-(b-y)/length*width/2,(a-x)/length*width/2
            poly([(x+dx,y+dy),(a+dx,b+dy),(a-dx,b-dy),(x-dx,y-dy)],color)
    def shard(x,y,size,color):
        pts=[(x,y-size),(x+size*.45,y-size*.4),(x+size*.36,y+size*.45),(x-size*.15,y+size),(x-size*.45,y+size*.35)]
        poly(pts,color);poly([pts[0],pts[1],pts[3]],blend(color,shine,.34))
    def star(x,y,size,color):
        poly([(x,y-size),(x+size*.16,y-size*.19),(x+size*.62,y),(x+size*.16,y+size*.19),(x,y+size),(x-size*.16,y+size*.19),(x-size*.62,y),(x-size*.16,y-size*.19)],color)
    def leaf(x,y,s,sign,color):
        pts=[(0,0),(.1,-.58),(.48,-1),(.6,-.48),(.47,-.1),(.21,.06)]
        poly([(x+sign*a*s,y+b*s) for a,b in pts],color)
        line([(x,y),(x+sign*s*.44,y-s*.83)],1,blend(color,shine,.34))
    def ridge(points,color):poly(points+[(105,106),(-5,106)],color)
    rect(0,0,100,100,base)
    if n in (0,1,2,10,17):
        if n==0:
            for x in range(0,101,12):rect(x,0,.45,100,back)
            for y in range(0,101,18):rect(0,y,100,.55,back)
            for offset in (0,5,10):
                line([(0,80+offset),(14,80+offset),(29,58+offset),(36,58+offset)],1.3,mid)
            ellipse(17,76,5,9,main);ellipse(17,76,2.5,4.5,dark)
        elif n==1:
            for i in range(4):arc(-3,49,15+i*9,27+i*14,1.5,270,460,mid if i%2 else main)
            line([(75,85),(85,66),(101,66)],2,mid)
        elif n==2:
            for i in range(4):
                line([(0,18+i*8),(12+i*2,18+i*8),(23+i*2,35+i*8),(23+i*2,78+i*4)],2,mid)
                ellipse(23+i*2,80+i*4,1.8,3,main)
            rect(78,12,15,24,back);rect(80,15,10,17,dark)
        elif n==10:
            for i,col in enumerate([accent,main,shine]):
                line([(-4,83+i*7),(20,66+i*7),(41,69+i*5),(76,20+i*5),(103,15+i*4)],2 if i!=2 else .8,blend(col,base,.33))
        else:
            for x,y,col in [(4,70,main),(18,85,accent),(76,15,accent),(90,29,main)]:
                line([(x-12,y),(x,y-20),(x+13,y),(x,y+20),(x-12,y)],3,blend(col,base,.32))
    elif n in (3,12,22):
        ridge([(-5,62),(9,54),(23,67),(36,71),(54,86),(74,70),(88,51),(105,45)],back)
        if n==12:
            path=[(-5,90),(18,74),(27,79),(44,63),(48,64),(69,38),(76,41),(99,18)]
            line(path,7,mid);line(path,2.5,main);line(path[5:],1,shine)
        elif n==3:
            for x,y,s in [(6,58,24),(15,74,20),(86,82,24),(96,55,30)]:
                poly([(x-s*.3,y+s*.3),(x-s*.21,y),(x,y-s),(x+s*.07,y-s*.32),(x+s*.22,y-s*.48),(x+s*.25,y+s*.2)],mid)
                star(x+2,y-s-7,2.5,main)
        else:
            for sign,cx in [(1,-4),(-1,104)]:
                for j in range(4):
                    poly([(cx,18+j*11),(cx+sign*(38-j*4),42+j*8),(cx+sign*(20-j*2),64+j*6),(cx,54+j*8)],mid if j%2 else main)
            arc(77,48,13,26,1.6,0,360,accent)
    elif n in (4,19):
        for x,y,s,col in [(5,53,56,back),(15,76,28,mid),(90,59,41,mid),(99,76,58,back),(82,89,19,accent)]:
            if n==19:
                rect(x-1,y,2,100-y,dark)
            shard(x,y,s,col)
        ridge([(-5,78),(13,86),(26,82),(44,93),(70,89),(86,80),(105,69)],back)
    elif n in (5,6,13,21,23,24):
        for x,y,s in [(12,22,2.5),(30,15,1.4),(64,22,1.8),(89,74,2.7),(75,87,1.4),(34,68,1.3)]:star(x,y,s,glint)
        if n==5:
            ellipse(57,153,80,82,mid);arc(57,153,80,82,1.8,180,360,shine)
        elif n==6:
            arc(46,43,53,30,1.1,13,192,main)
            poly([(80,24),(94,8),(87,25),(83,31)],mid); ellipse(81,30,2.6,4.8,shine)
        elif n==13:
            ellipse(93,14,20,38,back);arc(89,15,28,15,2,0,300,accent)
            line([(0,84),(14,84),(25,70),(34,70)],1.3,main)
        elif n==21:
            for i in range(9):
                t=i*.37
                poly([(8+16*cos(t),70-32*sin(t)),(8+30*cos(t-.038),70-60*sin(t-.038)),(8+20*cos(t+.08),70-40*sin(t+.08))],mid)
            ellipse(8,70,15,30,main);ellipse(8,73,12,25,mid)
            arc(83,32,28,54,2,-70,94,accent)
        elif n==23:
            arc(79,44,19,36,2.4,140,420,mid)
            poly([(0,58),(30,58),(24,71),(17,74),(17,83),(24,91),(4,91),(9,80),(8,72)],main)
            star(23,48,7,glint)
        else:
            ellipse(82,38,14.5,29,mid);ellipse(83,37,12.4,24.8,ink)
            arc(81,38,20,16,1.6,8,180,accent);arc(81,38,20,16,.8,207,326,main)
            arc(8,115,28,55,1.2,191,349,back)
    elif n in (7,8,14):
        if n==7:
            for start,y,col in [(-6,77,mid),(72,84,mid),(-12,88,back)]:
                poly([(start,y),(start+18,y-9),(start+36,y-2),(start+26,y+11),(start,y+15)],col)
                line([(start,y),(start+18,y-9),(start+36,y-2)],1.4,main)
        else:
            for x,y,s,sign in [(2,49,33,1),(14,92,31,-1),(99,67,36,-1),(89,28,27,1)]:
                if n==14:leaf(x,y,s,sign,mid)
                else:
                    for j in range(5):
                        a=j*2*pi/5
                        ellipse(x+cos(a)*s*.20,y+sin(a)*s*.38,s*.16,s*.3,main if j%2 else mid)
                    ellipse(x,y,s*.10,s*.19,accent)
    elif n==11:
        for x,y,s in [(-2,75,1),(75,86,.8),(89,69,.7)]:
            pts=[(0,18),(5,0),(14,-17),(24,-20),(31,-13),(26,-13),(22,-7),(23,1),(32,4),(38,0),(32,12),(18,20)]
            poly([(x+a*s,y+b*s) for a,b in pts],mid)
            line([(x+11*s,y-10*s),(x+22*s,y-20*s),(x+29*s,y-15*s)],1.5,main)
    elif n==18:
        for x,y,s in [(4,15,24),(89,26,19),(99,16,23)]:
            ellipse(x,y,s*.75,s,back);ellipse(x-6,y+11,s*.54,s*.71,mid)
        poly([(87,28),(94,27),(88,43),(94,41),(81,60),(85,45),(81,45)],accent)
        arc(22,0,35,55,1.3,40,137,main)
    else:
        if n==16:
            for i in range(18):
                height=(14+23*(.5+.5*sin(i*2.2)))*(1 if i<5 or i>12 else .32)
                rect(i*5.8,100-height,3.7,height,mid if i%2 else main)
                rect(i*5.8,96-height,3.7,1.6,glint)
        elif n==15:
            for x,sign in [(0,1),(100,-1)]:
                for j in range(3):
                    poly([(x,7+j*12),(x+sign*(29-j*4),41+j*5),(x+sign*(17-j*2),74+j*8),(x,88+j*4)],back if j==0 else mid if j==1 else accent)
        else:
            for j in range(5):
                for k in range(4):
                    if (j+k)%2==0:
                        for x,y in [(j*5,8+k*9),(79+j*5,57+k*9)]:
                            rect(x+k*(.8 if n==20 else 0),y,5.5,9.5,mid if k%2 else main)
            if n==20:
                for x,y in [(3,14),(76,67),(83,90)]:rect(x,y,17,2,accent)
    return shapes
