#!/usr/bin/env python3
"""Generate original procedural WAV sounds (no Valve assets)."""
import math, os, struct, wave
import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(1337)

def t(d): return np.linspace(0, d, int(SR*d), endpoint=False)
def env(d, decay=8): return np.exp(-np.linspace(0, decay, int(SR*d)))
def save(name, x):
    x = np.clip(x, -1, 1)
    pcm = (x*32767).astype('<i2')
    with wave.open(os.path.join(OUT, name+'.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(f"{name:20} {len(x)/SR:.2f}s")

def noise(d): return rng.standard_normal(int(SR*d))

def gun(d, body_hz, bright, tail):
    x = t(d)
    n = noise(d)*env(d, 40)[:len(x)]
    # simple lowpass by cumulative average
    k = max(1, int(SR/bright))
    n = np.convolve(n, np.ones(k)/k, mode='same')
    body = np.sin(2*np.pi*body_hz*x)*env(d, 18)[:len(x)]
    click = noise(0.008)*env(0.008, 500)
    out = np.zeros(len(x)); out[:len(click)] = click*0.7
    m = min(len(out), len(n)); out[:m] += n*0.5; out[:m] += body*0.4
    if tail>0:
        tr = noise(tail)*env(tail, 6)
        m = min(len(out), len(tr)); out[:m] += tr*0.12
    return out

save('fire_rifle', gun(0.22, 110, 6000, 0.15))
save('fire_smg', gun(0.13, 150, 7000, 0.08))
save('fire_pistol', gun(0.15, 180, 6500, 0.10))
save('fire_sniper', gun(0.45, 70, 4000, 0.35))
save('fire_shotgun', gun(0.35, 90, 3500, 0.22))
save('fire_silenced', gun(0.10, 220, 2500, 0.03)*0.5)

def mech(d, clicks):
    x = np.zeros(int(SR*d))
    for frac, amp in clicks:
        i = int(frac*len(x)); n=min(int(SR*0.012), len(x)-i)
        x[i:i+n] = rng.standard_normal(n)*env(n/SR, 400)[:n]*amp
    return x

save('reload_mag_out', mech(0.35, [(0.05,0.7),(0.20,0.5)]))
save('reload_mag_in', mech(0.4, [(0.1,0.8),(0.3,0.6)]))
save('reload_bolt', mech(0.3, [(0.1,1.0),(0.25,0.5)]))
save('inspect', mech(1.2, [(0.05,0.4),(0.3,0.5),(0.55,0.6),(0.8,0.4),(1.0,0.5)]))
save('deploy', mech(0.6, [(0.05,0.5),(0.25,0.7),(0.45,0.5)]))
save('melee_swing', noise(0.4)*env(0.4, 12)*0.5)
save('switch', mech(0.3, [(0.1,0.6),(0.2,0.4)]))
save('hit', mech(0.08, [(0.0,0.8)]))
save('headshot', np.sin(2*np.pi*1800*t(0.12))*env(0.12, 30))
save('damage', np.sin(2*np.pi*90*t(0.25))*env(0.25, 10)*0.5)
save('ui_click', np.sin(2*np.pi*900*t(0.05))*env(0.05, 60)*0.4)

def foot(d, hz, bright):
    x = noise(d)*env(d, 25)
    k=max(1,int(SR/bright)); x=np.convolve(x,np.ones(k)/k,mode='same')
    return x + np.sin(2*np.pi*hz*t(d))*env(d,20)*0.3

save('step_concrete', foot(0.12, 120, 2500))
save('step_metal', foot(0.18, 400, 6000))
save('step_wood', foot(0.14, 200, 3500))
save('explosion', np.sin(2*np.pi*55*t(0.6))*env(0.6,5)*0.7 + noise(0.6)*env(0.6,7)*0.5)
save('flash', noise(0.5)*env(0.5, 18)*0.6 + np.sin(2*np.pi*2400*t(0.5))*env(0.5,15)*0.2)
save('smoke', noise(1.0)*env(1.0, 3)*0.35)
save('fire_burn', noise(2.0)*env(2.0, 0.7)*0.3)
save('beep', np.sin(2*np.pi*880*t(0.08))*env(0.08, 20)*0.6)
save('plant', mech(1.0, [(0.1,0.4),(0.5,0.5),(0.9,0.7)]))
save('defuse', mech(1.2, [(0.1,0.3),(0.4,0.4),(0.7,0.3),(1.0,0.6)]))
print("done")
