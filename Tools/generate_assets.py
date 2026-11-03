#!/usr/bin/env python3
"""Rebuild original seamless PBR textures and small mechanical sound effects.
Optional authoring tool; the game needs only Godot. Requires numpy + Pillow.
Third-party model / engine / skid / impact assets are downloaded separately.
"""
from pathlib import Path
import math, wave, struct, json, base64, urllib.request
import numpy as np
from PIL import Image, ImageFilter
ROOT = Path(__file__).resolve().parents[1]
TEX = ROOT / 'Assets/Textures'
AUD = ROOT / 'Assets/Audio'
TEX.mkdir(parents=True, exist_ok=True); AUD.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(458)

def save(name, a): Image.fromarray(np.uint8(np.clip(a,0,255))).save(TEX/name, optimize=True)
def normal(name, height, strength):
    dx=(np.roll(height,-1,1)-np.roll(height,1,1))*strength
    dy=(np.roll(height,-1,0)-np.roll(height,1,0))*strength
    n=np.dstack((-dx,-dy,np.ones_like(height)))
    n/=np.linalg.norm(n,axis=2)[:,:,None]
    save(name,(n*.5+.5)*255)
def noise(n, scale=1):
    a=rng.random((n,n))*255
    im=Image.fromarray(a.astype('uint8')).resize((n//scale,n//scale)).resize((n,n),Image.Resampling.BICUBIC)
    return np.asarray(im,dtype=float)/255

# Asphalt: multi-frequency aggregate, not a flat gray plane.
n=1024; yy,xx=np.mgrid[:n,:n]
h=noise(n,2)*.48+noise(n,8)*.32+noise(n,32)*.20
speck=rng.random((n,n)); h[speck>.985]+=.25
base=43+h*43
save('asphalt_albedo.png',np.dstack((base*.96,base*.99,base*1.02)))
normal('asphalt_normal.png',h,2.0)
save('asphalt_roughness.png',np.repeat((205+h*42)[:,:,None],3,axis=2))
# Leather / Alcantara: fine cellular grain with restrained roughness.
n=512; h=noise(n,1)*.7+noise(n,4)*.3
save('leather_albedo.png',np.repeat((24+h*13)[:,:,None],3,axis=2))
normal('leather_normal.png',h,.8)
# Carbon 2x2 twill, subtle rather than mirror-like.
n=512; yy,xx=np.mgrid[:n,:n]; cell=16; direction=((xx//cell+yy//cell)//2)%2
fiber=np.where(direction, np.sin(xx*math.tau/4),np.sin(yy*math.tau/4))
h=.5+fiber*.16+noise(n,1)*.08
base=18+h*21
save('carbon_albedo.png',np.dstack((base*.91,base*.97,base)))
normal('carbon_normal.png',h,.42)
# Directionally brushed titanium for the articulated pilot.
n=512; h=noise(n,1)*.12+np.repeat(noise(n,1).mean(0)[None,:],n,axis=0)*.35
save('titanium_albedo.png',np.dstack((116+h*45,123+h*45,129+h*45)))
normal('titanium_normal.png',h,.32)
# A small neutral trackside banner, authored as vector-like geometry.
im=Image.new('RGB',(1024,256),(22,27,30)); pix=im.load()
for x in range(0,1024,32):
    for y in range(256): pix[x,y]=(236,91,45)
im.save(TEX/'banner.png')

def wav(name, duration, fn, rate=22050):
    data=bytearray()
    for i in range(int(duration*rate)):
        t=i/rate; v=max(-1,min(1,fn(t)))
        data+=struct.pack('<h',int(v*26000))
    with wave.open(str(AUD/name),'wb') as w:
        w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate);w.writeframes(data)
# Seamless dual-tone horn; amplitude is controlled by the held input.
wav('horn.wav',1.0,lambda t:.34*(math.sin(math.tau*420*t)+.7*math.sin(math.tau*520*t)))
wav('shift.wav',.16,lambda t:(rng.random()*2-1)*math.exp(-t*42)*.55+math.sin(math.tau*165*t)*math.exp(-t*30)*.35)
wav('latch.wav',.12,lambda t:math.sin(math.tau*230*t)*math.exp(-t*40)*.5+(rng.random()*2-1)*math.exp(-t*65)*.25)
# Loop-compatible wind / distant surroundings bed. Edge-crossfaded noise.
rate=22050; duration=4; count=rate*duration
white=rng.normal(0,1,count); kernel=np.ones(15)/15; brown=np.convolve(white,kernel,'same')
edge=int(.08*rate); brown[-edge:]=brown[-edge:]*np.linspace(1,0,edge)+brown[:edge]*np.linspace(0,1,edge)
brown/=max(np.max(np.abs(brown)),.001)
with wave.open(str(AUD/'wind.wav'),'wb') as w:
    w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate);w.writeframes(b''.join(struct.pack('<h',int(v*17000)) for v in brown))
print('Original PBR textures and mechanical audio generated.')
