import type { AudioEngine, BusName, Spatial } from "./engine";

/**
 * Synthesised one-shots. Each takes the engine, a start time (context
 * seconds) and a few parameters, schedules its nodes and lets them stop on
 * their own; nothing here holds state between calls.
 */

export type Surface = "concrete" | "metal" | "tile" | "gravel" | "wet" | "water";

const rnd = (a: number, b: number) => a + Math.random() * (b - a);
export const midiHz = (m: number) => 440 * Math.pow(2, (m - 69) / 12);

/** Percussive envelope on a gain param: linear attack, exponential decay. */
function perc(g: AudioParam, t: number, peak: number, attack: number, decay: number): number {
  g.setValueAtTime(0.0001, t);
  g.linearRampToValueAtTime(Math.max(0.0002, peak), t + attack);
  g.exponentialRampToValueAtTime(0.0001, t + attack + decay);
  return t + attack + decay + 0.05;
}

function gain(e: AudioEngine, v = 0): GainNode {
  const g = e.ctx!.createGain();
  g.gain.value = v;
  return g;
}

function filter(e: AudioEngine, type: BiquadFilterType, freq: number, q = 0.7): BiquadFilterNode {
  const f = e.ctx!.createBiquadFilter();
  f.type = type;
  f.frequency.value = freq;
  f.Q.value = q;
  return f;
}

/** A one-shot noise burst through a filter. */
function noiseHit(e: AudioEngine, out: AudioNode, t: number, o: { kind?: "white" | "pink" | "brown"; type?: BiquadFilterType; freq: number; q?: number; peak: number; attack?: number; decay: number; sweepTo?: number }): void {
  const ctx = e.ctx!;
  const src = ctx.createBufferSource();
  src.buffer = e.noise[o.kind ?? "white"];
  const f = filter(e, o.type ?? "bandpass", o.freq, o.q ?? 1);
  if (o.sweepTo) f.frequency.exponentialRampToValueAtTime(o.sweepTo, t + (o.attack ?? 0.002) + o.decay);
  const g = gain(e);
  const end = perc(g.gain, t, o.peak, o.attack ?? 0.002, o.decay);
  src.connect(f).connect(g).connect(out);
  src.start(t, Math.random() * 3);
  src.stop(end);
  e.track(src);
}

/** A one-shot oscillator with optional pitch glide. */
function tone(e: AudioEngine, out: AudioNode, t: number, o: { type?: OscillatorType; freq: number; to?: number; glide?: number; peak: number; attack?: number; decay: number; detune?: number }): OscillatorNode {
  const ctx = e.ctx!;
  const osc = ctx.createOscillator();
  osc.type = o.type ?? "sine";
  osc.frequency.setValueAtTime(o.freq, t);
  if (o.to) osc.frequency.exponentialRampToValueAtTime(o.to, t + (o.glide ?? o.decay));
  if (o.detune) osc.detune.value = o.detune;
  const g = gain(e);
  const end = perc(g.gain, t, o.peak, o.attack ?? 0.003, o.decay);
  osc.connect(g).connect(out);
  osc.start(t);
  osc.stop(end);
  e.track(osc);
  return osc;
}

/** Inharmonic metal ring (bars/gates/gallery grating). */
function metal(e: AudioEngine, out: AudioNode, t: number, base: number, peak: number, decay: number): void {
  for (const [ratio, amp] of [[1, 1], [2.76, 0.6], [5.4, 0.35], [8.93, 0.18]] as const) {
    tone(e, out, t, { freq: base * ratio * rnd(0.98, 1.02), peak: peak * amp, attack: 0.001, decay: decay / Math.sqrt(ratio), type: "sine" });
  }
}

// ── Player & world ───────────────────────────────────────────────────────────

/** One footstep. `intensity` is the player's 0.06 crouch … 0.3 walk … 0.85 sprint. */
export function footstep(e: AudioEngine, surface: Surface, intensity: number, s: Spatial, level = 1): void {
  const t = e.now + 0.005;
  const out = e.out("sfx", s);
  const k = Math.sqrt(Math.min(1, intensity)) * level;
  const pitch = rnd(0.9, 1.1);
  const heel = 0.022 + (1 - k) * 0.02;
  switch (surface) {
    case "metal":
      noiseHit(e, out, t, { freq: 2600 * pitch, q: 1.2, peak: 0.5 * k, decay: 0.05 });
      metal(e, out, t, 310 * pitch, 0.09 * k, 0.35);
      tone(e, out, t, { freq: 95, to: 60, peak: 0.25 * k, decay: 0.09 });
      break;
    case "tile":
      noiseHit(e, out, t, { freq: 3400 * pitch, q: 1.6, peak: 0.45 * k, decay: 0.035 });
      noiseHit(e, out, t + heel, { freq: 2200 * pitch, q: 1.2, peak: 0.25 * k, decay: 0.04 });
      break;
    case "gravel":
      for (let i = 0; i < 6; i++) noiseHit(e, out, t + rnd(0, 0.09), { freq: rnd(2500, 6000), q: 2, peak: rnd(0.12, 0.3) * k, decay: rnd(0.01, 0.03) });
      tone(e, out, t, { freq: 80, to: 55, peak: 0.18 * k, decay: 0.08 });
      break;
    case "wet":
      noiseHit(e, out, t, { kind: "pink", type: "lowpass", freq: 1800 * pitch, peak: 0.45 * k, decay: 0.12, sweepTo: 600 });
      noiseHit(e, out, t + 0.02, { freq: 4200, q: 3, peak: 0.12 * k, decay: 0.06 });
      tone(e, out, t + 0.03, { freq: rnd(700, 1100), to: rnd(1400, 2200), glide: 0.03, peak: 0.04 * k, decay: 0.04 });
      break;
    case "water":
      noiseHit(e, out, t, { kind: "pink", type: "lowpass", freq: 900 * pitch, peak: 0.5 * k, attack: 0.04, decay: 0.3, sweepTo: 300 });
      break;
    default:
      noiseHit(e, out, t, { freq: 1700 * pitch, q: 1, peak: 0.5 * k, decay: 0.045 });
      noiseHit(e, out, t + heel, { freq: 1100 * pitch, q: 0.9, peak: 0.3 * k, decay: 0.05 });
      tone(e, out, t, { freq: 110 * pitch, to: 60, peak: 0.3 * k, decay: 0.07 });
  }
}

export function landing(e: AudioEngine, surface: Surface, strength: number): void {
  const t = e.now + 0.005;
  const out = e.out("sfx", { reverb: 0.3 });
  const k = Math.min(1, strength);
  tone(e, out, t, { freq: 90, to: 38, peak: 0.7 * k, decay: 0.22 });
  noiseHit(e, out, t, { kind: "pink", type: "lowpass", freq: 1400, peak: 0.6 * k, decay: 0.12 });
  footstep(e, surface, 0.6 + 0.4 * k, {}, 0.8);
}

/** Hinged doors creak and thud; sliding gates roll and clank. */
export function door(e: AudioEngine, kind: string, opening: boolean, s: Spatial): void {
  const t = e.now + 0.01;
  const out = e.out("sfx", { ...s, reverb: (s.reverb ?? 0) + 0.4 });
  if (kind === "gate" || kind === "shutter") {
    // Latch, rolling, end clank.
    metal(e, out, t, 520, 0.12, 0.25);
    const ctx = e.ctx!;
    const src = e.noiseSource("pink");
    const bp = filter(e, "bandpass", kind === "shutter" ? 900 : 1300, 1.4);
    const g = gain(e);
    const flutter = ctx.createOscillator();
    flutter.frequency.value = kind === "shutter" ? 34 : 19;
    const fg = gain(e, 0.12);
    flutter.connect(fg).connect(g.gain);
    g.gain.setValueAtTime(0, t);
    g.gain.linearRampToValueAtTime(0.22, t + 0.08);
    g.gain.setValueAtTime(0.22, t + 0.6);
    g.gain.linearRampToValueAtTime(0, t + 0.78);
    src.connect(bp).connect(g).connect(out);
    flutter.start(t);
    flutter.stop(t + 0.8);
    src.stop(t + 0.82);
    e.track(src);
    e.track(flutter);
    tone(e, out, t + 0.02, { type: "sawtooth", freq: 62, peak: 0.05, attack: 0.08, decay: 0.7 });
    const end = t + 0.76;
    metal(e, out, end, opening ? 240 : 190, opening ? 0.22 : 0.35, 0.9);
    tone(e, out, end, { freq: 75, to: 45, peak: opening ? 0.3 : 0.5, decay: 0.25 });
  } else if (kind === "glass") {
    noiseHit(e, out, t, { kind: "pink", freq: 2400, q: 0.6, peak: 0.15, attack: 0.2, decay: 0.5 });
    tone(e, out, t + 0.7, { freq: 1900, peak: 0.04, decay: 0.4 });
  } else {
    // Latch click, creak, and (closing) the leaf meeting the frame.
    noiseHit(e, out, t, { freq: 4200, q: 2, peak: 0.35, decay: 0.02 });
    noiseHit(e, out, t + 0.03, { freq: 2600, q: 3, peak: 0.2, decay: 0.03 });
    const ctx = e.ctx!;
    const creak = ctx.createOscillator();
    creak.type = "sawtooth";
    const base = rnd(260, 380);
    creak.frequency.setValueAtTime(base, t + 0.06);
    for (let i = 1; i <= 6; i++) creak.frequency.linearRampToValueAtTime(base * rnd(0.85, 1.25), t + 0.06 + i * 0.08);
    const bp = filter(e, "bandpass", 1400, 6);
    const g = gain(e);
    g.gain.setValueAtTime(0, t + 0.06);
    g.gain.linearRampToValueAtTime(0.05, t + 0.15);
    g.gain.linearRampToValueAtTime(0, t + 0.6);
    creak.connect(bp).connect(g).connect(out);
    creak.start(t + 0.06);
    creak.stop(t + 0.65);
    e.track(creak);
    if (!opening) {
      tone(e, out, t + 0.62, { freq: 85, to: 48, peak: 0.55, decay: 0.2 });
      noiseHit(e, out, t + 0.62, { kind: "pink", type: "lowpass", freq: 900, peak: 0.45, decay: 0.12 });
      noiseHit(e, out, t + 0.64, { freq: 3800, q: 2, peak: 0.2, decay: 0.03 });
    }
  }
}

export function pistol(e: AudioEngine, suppressed: boolean): void {
  const t = e.now + 0.002;
  const out = e.out("sfx", { reverb: suppressed ? 0.3 : 1.2 });
  if (suppressed) {
    noiseHit(e, out, t, { kind: "pink", type: "lowpass", freq: 1500, peak: 0.7, decay: 0.08 });
    tone(e, out, t, { freq: 140, to: 60, peak: 0.5, decay: 0.08 });
    noiseHit(e, out, t + 0.04, { freq: 3500, q: 3, peak: 0.25, decay: 0.03 });
  } else {
    noiseHit(e, out, t, { type: "highpass", freq: 900, peak: 1.0, attack: 0.001, decay: 0.09 });
    noiseHit(e, out, t, { kind: "pink", type: "lowpass", freq: 2500, peak: 0.9, decay: 0.25, sweepTo: 300 });
    tone(e, out, t, { freq: 160, to: 42, peak: 0.9, decay: 0.3 });
  }
  // Brass on the floor.
  for (let i = 0; i < 3; i++) metal(e, out, t + 0.45 + i * rnd(0.08, 0.14), rnd(2800, 3600), 0.03 / (i + 1), 0.12);
}

export function splash(e: AudioEngine, size: number, s: Spatial = {}): void {
  const t = e.now + 0.005;
  const out = e.out("sfx", s);
  noiseHit(e, out, t, { kind: "pink", type: "lowpass", freq: 3000, peak: 0.6 * size, attack: 0.01, decay: 0.5, sweepTo: 400 });
  noiseHit(e, out, t + 0.05, { freq: 5200, q: 1.5, peak: 0.2 * size, decay: 0.25 });
  bubbles(e, 0.6 * size, t + 0.1, "sfx");
}

export function bubbles(e: AudioEngine, amount: number, t = e.now, bus: BusName = "sfx"): void {
  const out = e.out(bus);
  const n = Math.round(4 + amount * 14);
  for (let i = 0; i < n; i++) {
    const f = rnd(350, 1300);
    tone(e, out, t + rnd(0, 0.5 + amount * 0.6), { freq: f, to: f * rnd(1.8, 2.6), glide: rnd(0.02, 0.05), peak: rnd(0.02, 0.07) * Math.min(1, amount + 0.3), decay: rnd(0.03, 0.07) });
  }
}

export function drip(e: AudioEngine, s: Spatial, level = 1): void {
  const t = e.now + 0.005;
  const out = e.out("sfx", s);
  const f = rnd(1400, 2600);
  tone(e, out, t, { freq: f, to: f * 1.9, glide: 0.025, peak: 0.08 * level, decay: 0.06 });
}

/** A short raindrop tick near the listener (open ground). */
export function raindrop(e: AudioEngine, s: Spatial, level: number): void {
  const t = e.now + rnd(0, 0.05);
  noiseHit(e, e.out("ambience", s, "equalpower"), t, { freq: rnd(3000, 7000), q: 2.5, peak: 0.12 * level, decay: rnd(0.01, 0.025) });
}

export function clank(e: AudioEngine, s: Spatial, level = 1): void {
  const t = e.now + 0.01;
  const out = e.out("sfx", { ...s, reverb: 1.5 });
  metal(e, out, t, rnd(180, 420), 0.25 * level, 1.2);
  tone(e, out, t, { freq: 70, to: 40, peak: 0.2 * level, decay: 0.3 });
}

export function thunder(e: AudioEngine, level: number): void {
  const t = e.now + 0.05;
  const out = e.out("ambience", { reverb: 0.4 });
  noiseHit(e, out, t, { kind: "brown", type: "lowpass", freq: 260, peak: 0.9 * level, attack: 0.3, decay: rnd(3, 5), sweepTo: 80 });
  noiseHit(e, out, t + rnd(0.2, 0.6), { kind: "pink", type: "lowpass", freq: 700, peak: 0.25 * level, attack: 0.05, decay: 1.4, sweepTo: 150 });
}

/** Breath / gasp: breathy noise through a sweeping vocal-tract band. */
export function gasp(e: AudioEngine, strength = 1, t = e.now + 0.01): void {
  const out = e.out("sfx");
  const k = Math.min(1.2, strength);
  noiseHit(e, out, t, { kind: "white", freq: 900, q: 1.8, peak: 0.45 * k, attack: 0.12, decay: 0.32, sweepTo: 2200 });
  noiseHit(e, out, t + 0.02, { kind: "pink", freq: 2800, q: 2.5, peak: 0.15 * k, attack: 0.1, decay: 0.3 });
  // Vocal catch.
  tone(e, out, t + 0.03, { type: "triangle", freq: 180, to: 260, glide: 0.25, peak: 0.04 * k, attack: 0.06, decay: 0.25 });
}

export function breath(e: AudioEngine, heavy: boolean, t = e.now + 0.01): void {
  const out = e.out("sfx");
  const k = heavy ? 0.9 : 0.5;
  noiseHit(e, out, t, { freq: 1100, q: 1.2, peak: 0.25 * k, attack: 0.5, decay: 0.4, sweepTo: 1600 });
  noiseHit(e, out, t + 1.0, { freq: 700, q: 1.1, peak: 0.22 * k, attack: 0.15, decay: 0.9, sweepTo: 400 });
}

/** Out of air underwater: a choked exhale and a burst of bubbles. */
export function choke(e: AudioEngine, t = e.now + 0.01): void {
  const out = e.out("sfx");
  tone(e, out, t, { type: "sawtooth", freq: 120, to: 80, peak: 0.08, attack: 0.05, decay: 0.6 });
  noiseHit(e, out, t, { kind: "pink", type: "lowpass", freq: 600, peak: 0.5, attack: 0.05, decay: 0.8 });
  bubbles(e, 1.2, t);
}

// ── Tension ─────────────────────────────────────────────────────────────────

export function heartbeat(e: AudioEngine, t: number, level: number, interval: number): void {
  const out = e.out("music");
  tone(e, out, t, { freq: 62, to: 38, glide: 0.12, peak: 0.9 * level, attack: 0.008, decay: 0.16 });
  noiseHit(e, out, t, { kind: "brown", type: "lowpass", freq: 140, peak: 0.5 * level, decay: 0.1 });
  const dub = t + Math.min(0.3, interval * 0.32);
  tone(e, out, dub, { freq: 54, to: 36, glide: 0.1, peak: 0.55 * level, attack: 0.008, decay: 0.14 });
}

/** One rise-fall of the facility klaxon (the PA is everywhere: not positional). */
export function klaxon(e: AudioEngine, t: number, level: number, period: number): void {
  const ctx = e.ctx!;
  const out = e.out("sfx", { reverb: 1.4 });
  const a = ctx.createOscillator();
  const b = ctx.createOscillator();
  a.type = "square";
  b.type = "sawtooth";
  const half = period * 0.5;
  for (const o of [a, b]) {
    o.frequency.setValueAtTime(470, t);
    o.frequency.linearRampToValueAtTime(690, t + half);
    o.frequency.linearRampToValueAtTime(470, t + period * 0.95);
  }
  b.detune.value = 9;
  const shaper = ctx.createWaveShaper();
  shaper.curve = drive(2.5);
  const lp = filter(e, "lowpass", 2600, 1);
  const g = gain(e);
  g.gain.setValueAtTime(0, t);
  g.gain.linearRampToValueAtTime(0.16 * level, t + 0.05);
  g.gain.setValueAtTime(0.16 * level, t + period * 0.85);
  g.gain.linearRampToValueAtTime(0, t + period * 0.97);
  a.connect(shaper);
  b.connect(shaper);
  shaper.connect(lp).connect(g).connect(out);
  for (const o of [a, b]) {
    o.start(t);
    o.stop(t + period);
    e.track(o);
  }
}

function drive(k: number): Float32Array<ArrayBuffer> {
  const n = 512;
  const c = new Float32Array(n);
  for (let i = 0; i < n; i++) {
    const x = (i / (n - 1)) * 2 - 1;
    c[i] = Math.tanh(k * x) / Math.tanh(k);
  }
  return c;
}

// ── Music / stingers ─────────────────────────────────────────────────────────

export type Timbre = "bell" | "glass" | "pad" | "piano" | "music_box";

/** A pitched note on the music bus. */
export function note(e: AudioEngine, midi: number, t: number, level: number, timbre: Timbre = "bell", length = 2.4, bus: BusName = "music"): void {
  const ctx = e.ctx!;
  const out = e.out(bus);
  const f = midiHz(midi);
  if (timbre === "pad") {
    for (const det of [-7, 7]) {
      const o = ctx.createOscillator();
      o.type = "sawtooth";
      o.frequency.value = f;
      o.detune.value = det;
      const lp = filter(e, "lowpass", f * 3, 0.6);
      const g = gain(e);
      g.gain.setValueAtTime(0, t);
      g.gain.linearRampToValueAtTime(0.06 * level, t + length * 0.35);
      g.gain.linearRampToValueAtTime(0, t + length);
      o.connect(lp).connect(g).connect(out);
      o.start(t);
      o.stop(t + length + 0.05);
      e.track(o);
    }
    return;
  }
  // FM bell / glass / music box / soft piano.
  const ratio = timbre === "glass" ? 4.07 : timbre === "music_box" ? 7.1 : timbre === "piano" ? 1 : 3.5;
  const index = timbre === "piano" ? 1.2 : timbre === "glass" ? 0.8 : 2.2;
  const car = ctx.createOscillator();
  const mod = ctx.createOscillator();
  car.frequency.value = f;
  mod.frequency.value = f * ratio;
  const mg = gain(e);
  mg.gain.setValueAtTime(f * index, t);
  mg.gain.exponentialRampToValueAtTime(f * 0.05 + 0.01, t + length * 0.6);
  mod.connect(mg).connect(car.frequency);
  const g = gain(e);
  const decay = timbre === "music_box" ? length * 0.5 : length;
  const end = perc(g.gain, t, 0.22 * level, 0.004, decay);
  car.connect(g).connect(out);
  // A quiet sub-octave body so it isn't all ping.
  const body = tone(e, out, t, { type: "triangle", freq: f / 2, peak: 0.05 * level, attack: 0.02, decay: decay * 0.7 });
  void body;
  for (const o of [car, mod]) {
    o.start(t);
    o.stop(end);
    e.track(o);
  }
}

export function boom(e: AudioEngine, t: number, level: number): void {
  const out = e.out("music");
  tone(e, out, t, { freq: 58, to: 26, glide: 1.6, peak: 1.0 * level, attack: 0.01, decay: 2.2 });
  noiseHit(e, out, t, { kind: "brown", type: "lowpass", freq: 300, peak: 0.6 * level, attack: 0.005, decay: 1.2, sweepTo: 60 });
}

/** Rising (reverse-cymbal-like) swell that stops dead at the end. */
export function swell(e: AudioEngine, t: number, seconds: number, level: number): void {
  const ctx = e.ctx!;
  const out = e.out("music");
  const src = e.noiseSource("pink");
  const bp = filter(e, "bandpass", 400, 0.8);
  bp.frequency.setValueAtTime(400, t);
  bp.frequency.exponentialRampToValueAtTime(5000, t + seconds);
  const g = gain(e);
  g.gain.setValueAtTime(0.0001, t);
  g.gain.exponentialRampToValueAtTime(0.35 * level, t + seconds);
  g.gain.linearRampToValueAtTime(0, t + seconds + 0.03);
  src.connect(bp).connect(g).connect(out);
  src.stop(t + seconds + 0.05);
  e.track(src);
  const o = ctx.createOscillator();
  o.type = "sawtooth";
  o.frequency.setValueAtTime(55, t);
  o.frequency.exponentialRampToValueAtTime(110, t + seconds);
  const og = gain(e);
  og.gain.setValueAtTime(0.0001, t);
  og.gain.exponentialRampToValueAtTime(0.08 * level, t + seconds);
  og.gain.linearRampToValueAtTime(0, t + seconds + 0.03);
  const lp = filter(e, "lowpass", 600);
  o.connect(lp).connect(og).connect(out);
  o.start(t);
  o.stop(t + seconds + 0.05);
  e.track(o);
}

/** Tinnitus: a thin high sine that slowly fades. */
export function whine(e: AudioEngine, t: number, seconds: number, level: number, freq = 7200): void {
  tone(e, e.out("music"), t, { freq, to: freq * 0.97, peak: 0.05 * level, attack: 0.05, decay: seconds });
}

/** Everything sagging down in pitch like a tape stopping. */
export function tapeStop(e: AudioEngine, t: number, seconds: number, level: number): void {
  const out = e.out("music");
  const lp = filter(e, "lowpass", 3000, 0.7);
  lp.frequency.setValueAtTime(3000, t);
  lp.frequency.exponentialRampToValueAtTime(120, t + seconds);
  lp.connect(out);
  for (const m of [48, 55, 60, 63]) {
    const o = e.ctx!.createOscillator();
    o.type = "sawtooth";
    o.frequency.setValueAtTime(midiHz(m), t);
    o.frequency.exponentialRampToValueAtTime(midiHz(m) * 0.25, t + seconds);
    const g = gain(e);
    g.gain.setValueAtTime(0.05 * level, t);
    g.gain.linearRampToValueAtTime(0, t + seconds);
    o.connect(g).connect(lp);
    o.start(t);
    o.stop(t + seconds + 0.05);
    e.track(o);
  }
}

export function chord(e: AudioEngine, midis: number[], t: number, seconds: number, level: number, timbre: Timbre = "pad"): void {
  for (const m of midis) note(e, m, t, level, timbre, seconds);
}

/** Metallic impact on the music bus (capture seize, smash cut). */
export function hit(e: AudioEngine, t: number, level: number): void {
  const out = e.out("music");
  noiseHit(e, out, t, { type: "highpass", freq: 600, peak: 0.6 * level, decay: 0.35 });
  metal(e, out, t, 140, 0.25 * level, 1.8);
  tone(e, out, t, { freq: 70, to: 30, peak: 0.8 * level, decay: 0.6 });
}

/** Two-tone PA chime (routine beats). */
export function chime(e: AudioEngine, t: number, level: number, notes = [79, 76, 72]): void {
  const out = e.out("sfx", { reverb: 1.6 });
  notes.forEach((m, i) => {
    tone(e, out, t + i * 0.55, { freq: midiHz(m), peak: 0.18 * level, attack: 0.01, decay: 1.4 });
    tone(e, out, t + i * 0.55, { type: "triangle", freq: midiHz(m) * 2, peak: 0.04 * level, attack: 0.01, decay: 0.6 });
  });
}

/** Harsh lock-in / lights-out buzzer. */
export function buzzer(e: AudioEngine, t: number, seconds: number, level: number): void {
  const out = e.out("sfx", { reverb: 1.2 });
  const o = e.ctx!.createOscillator();
  o.type = "square";
  o.frequency.value = 196;
  const lp = filter(e, "lowpass", 1500);
  const g = gain(e);
  g.gain.setValueAtTime(0, t);
  g.gain.linearRampToValueAtTime(0.09 * level, t + 0.02);
  g.gain.setValueAtTime(0.09 * level, t + seconds - 0.05);
  g.gain.linearRampToValueAtTime(0, t + seconds);
  o.connect(lp).connect(g).connect(out);
  o.start(t);
  o.stop(t + seconds + 0.02);
  e.track(o);
}

/** Lift / machinery motor for a while. */
export function motor(e: AudioEngine, t: number, seconds: number, level: number): void {
  const ctx = e.ctx!;
  const out = e.out("sfx", { reverb: 0.4 });
  const o = ctx.createOscillator();
  o.type = "sawtooth";
  o.frequency.setValueAtTime(48, t);
  o.frequency.linearRampToValueAtTime(64, t + 1.2);
  o.frequency.setValueAtTime(64, t + seconds - 1);
  o.frequency.linearRampToValueAtTime(44, t + seconds);
  const lp = filter(e, "lowpass", 420, 1.5);
  const g = gain(e);
  g.gain.setValueAtTime(0, t);
  g.gain.linearRampToValueAtTime(0.18 * level, t + 0.8);
  g.gain.setValueAtTime(0.18 * level, t + seconds - 0.8);
  g.gain.linearRampToValueAtTime(0, t + seconds);
  o.connect(lp).connect(g).connect(out);
  o.start(t);
  o.stop(t + seconds + 0.05);
  e.track(o);
  const src = e.noiseSource("brown");
  const ng = gain(e);
  ng.gain.setValueAtTime(0, t);
  ng.gain.linearRampToValueAtTime(0.2 * level, t + 0.8);
  ng.gain.linearRampToValueAtTime(0, t + seconds);
  const nlp = filter(e, "lowpass", 220);
  src.connect(nlp).connect(ng).connect(out);
  src.stop(t + seconds + 0.05);
  e.track(src);
  metal(e, out, t, 260, 0.12 * level, 0.6);
  metal(e, out, t + seconds - 0.1, 230, 0.18 * level, 0.8);
}

/** Searchlight power-down: a whine falling away. */
export function powerDown(e: AudioEngine, t: number, level: number): void {
  const out = e.out("sfx", { reverb: 0.8 });
  tone(e, out, t, { type: "sawtooth", freq: 240, to: 30, glide: 2.2, peak: 0.12 * level, attack: 0.02, decay: 2.4 });
  noiseHit(e, out, t, { freq: 4000, q: 2, peak: 0.25 * level, decay: 0.08 });
}
