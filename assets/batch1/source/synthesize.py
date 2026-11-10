"""Original oscillator and filtered-noise patch bank. No samples or external audio."""
import json
import wave
from pathlib import Path

import numpy as np
from scipy.signal import butter, sosfilt

OUT = Path(__file__).resolve().parents[1]
RATE = 44100
# Fundamental, pitch glide, FM ratio, modulation index, noise mix, decay, gesture
PATCHES = [
    (740,-140,2,.22,.04,.026,'tick'),(560,210,1.5,.6,.02,.032,'pair'),
    (315,-100,3.1,1.6,.14,.027,'click'),(190,-85,2.2,.5,.42,.038,'crackle'),
    (1210,-75,2.75,.8,.03,.038,'glass'),(430,-210,1,.15,.04,.052,'hollow'),
    (520,430,1.5,.28,.02,.038,'rise'),(245,-115,2.55,1.8,.19,.027,'wood'),
    (660,-45,1.99,1.3,.04,.061,'pluck'),(710,-12,1,.01,0,.043,'square'),
    (870,-650,2.3,2.7,.09,.048,'zap'),(790,-470,1.08,.7,.04,.047,'drop'),
    (175,-65,3.41,2.8,.55,.046,'crackle'),(830,-55,1.5,.12,.01,.067,'hollow'),
    (285,-74,3.8,2.1,.18,.035,'wood'),(615,140,1.5,.4,.015,.055,'pair'),
    (142,-59,2.04,.9,.10,.051,'knock'),(675,240,1.47,1.85,.03,.058,'phase'),
    (305,-195,3.5,1.5,.65,.042,'clap'),(1070,-60,2.72,.62,.04,.062,'glass'),
    (548,-180,1.06,1.4,.08,.06,'stutter'),(720,-30,1.25,.38,.015,.074,'chime'),
    (390,-200,2.1,.72,.53,.043,'sweep'),(630,-42,3.57,1.35,.03,.064,'metal'),
    (320,-165,2.41,1.1,.07,.072,'eclipse'),
]

def write(path, samples):
    with wave.open(str(path), 'wb') as wav:
        wav.setparams((1, 2, RATE, 0, 'NONE', ''))
        wav.writeframes((samples * 32767).astype('<i2').tobytes())

def synth(index, patch):
    f, glide, ratio, depth, noise_mix, decay, gesture = patch
    t = np.arange(round(min(.35, decay*5)*RATE))/RATE
    angle = 2*np.pi*np.cumsum(f + glide*(1-np.exp(-t/.028)))/RATE
    tone = np.sin(angle + depth*np.exp(-t/.045)*np.sin(angle*ratio))
    noise = np.random.default_rng(index).normal(0, 1, len(t))
    noise = sosfilt(butter(2, [700, 4800], btype='bandpass', fs=RATE, output='sos'), noise)
    if gesture in ('pair','stutter','clap'):
        tone += np.where(t>.046, np.sin(angle*1.49)*np.exp(-np.maximum(t-.046,0)/.026),0)
        tone *= np.where((t>.029)&(t<.044), .06, 1)
    elif gesture == 'square':
        tone = .8*np.sin(angle)+.25*np.sin(3*angle)+.13*np.sin(5*angle)
    elif gesture in ('glass','metal','chime','eclipse'):
        tone += .43*np.sin(angle*(2.67 if gesture=='glass' else 1.52)) + .24*np.sin(angle*4.17)*np.exp(-t/.024)
    elif gesture in ('phase','drop','pluck'):
        tone += .39*np.sin(1.018*angle + 1.4*np.sin(2*np.pi*t*24))
    elif gesture in ('crackle','sweep','wood','knock'):
        noise *= .4+.6*np.sin(t*(330 if gesture=='crackle' else 129))**2
        tone += .24*np.sin(angle*.52)
    signal = ((1-noise_mix)*tone+noise_mix*noise)*np.exp(-t/decay)
    signal *= np.minimum(1,t/.0018)*np.minimum(1,(t[-1]-t)/.007)
    rms = np.sqrt(np.mean(signal**2))
    return signal * min(.72/max(abs(signal)), .132/rms)

if __name__ == '__main__':
    catalog=json.loads((OUT/'source'/'catalog.json').read_text())
    masters=OUT/'masters'
    masters.mkdir(exist_ok=True)
    delivery=OUT/'delivery'
    delivery.mkdir(exist_ok=True)
    bank=np.zeros(RATE*len(PATCHES))
    for i,(group,patch) in enumerate(zip(catalog['sets'],PATCHES,strict=True)):
        accent=synth(i,patch)
        write(masters/(group['item_ids'][4]+'.wav'),accent)
        bank[i*RATE:i*RATE+len(accent)]=accent
    write(delivery/'shot-accents.wav',bank)
