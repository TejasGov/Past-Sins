import type { AudioEngine } from "./engine";

/**
 * Voice clips for dialogue lines (`audio` id on a dialogue event). A clip is
 * a small file in public/audio/ when one exists, otherwise an optional
 * formant-synth fallback (a rough child's voice for "Again." and the
 * counting), otherwise silence.
 */
export interface VoiceDef {
  /** Path under public/, e.g. "audio/voice/again.ogg". Only list files that exist. */
  file?: string;
  gain?: number;
  /** Played through the cassette/speaker chain (band-limited, wow, hiss). */
  tape?: boolean;
  /** Room/hall reverb send. */
  reverb?: number;
  synth?: SynthVoice;
}

export interface SynthVoice {
  /** Space-separated phonemes, each optionally `:seconds`, e.g. "@:0.09 g E:0.22 I:0.06 n:0.2". */
  phonemes: string;
  /** Fundamental in Hz (a ten-year-old ≈ 260–300). */
  pitch?: number;
  /** Pitch at the end relative to the start (falling statement ≈ 0.8). */
  fall?: number;
  /** 0 = voiced … 1 = whispered. */
  breathy?: number;
  /** Duration multiplier. */
  rate?: number;
}

type Ph = { f: [number, number, number]; voice: number; noise?: { type: BiquadFilterType; freq: number; amp: number }; dur: number; stop?: boolean };

/** Child-ish formant targets (Peterson & Barney children, rounded). */
const PH: Record<string, Ph> = {
  i: { f: [370, 3200, 3730], voice: 1, dur: 0.16 },
  I: { f: [530, 2730, 3600], voice: 1, dur: 0.12 },
  e: { f: [600, 2500, 3500], voice: 1, dur: 0.16 },
  E: { f: [690, 2610, 3570], voice: 1, dur: 0.16 },
  ae: { f: [1010, 2320, 3320], voice: 1, dur: 0.16 },
  V: { f: [850, 1590, 3360], voice: 1, dur: 0.16 },
  a: { f: [1030, 1370, 3170], voice: 1, dur: 0.18 },
  O: { f: [680, 1060, 3180], voice: 1, dur: 0.18 },
  U: { f: [560, 1410, 3310], voice: 1, dur: 0.12 },
  u: { f: [430, 1170, 3260], voice: 1, dur: 0.18 },
  "@": { f: [650, 1700, 3100], voice: 0.9, dur: 0.1 },
  n: { f: [300, 1800, 2900], voice: 0.35, dur: 0.1 },
  m: { f: [300, 1300, 2600], voice: 0.35, dur: 0.1 },
  w: { f: [350, 800, 2600], voice: 0.55, dur: 0.08 },
  l: { f: [400, 1300, 3000], voice: 0.5, dur: 0.08 },
  v: { f: [400, 1600, 2800], voice: 0.35, noise: { type: "bandpass", freq: 4000, amp: 0.15 }, dur: 0.07 },
  s: { f: [500, 1800, 3000], voice: 0, noise: { type: "highpass", freq: 5500, amp: 0.55 }, dur: 0.12 },
  h: { f: [700, 1800, 3200], voice: 0, noise: { type: "bandpass", freq: 1800, amp: 0.3 }, dur: 0.06 },
  t: { f: [500, 1900, 3200], voice: 0, noise: { type: "highpass", freq: 3800, amp: 0.7 }, dur: 0.07, stop: true },
  k: { f: [500, 1900, 3200], voice: 0, noise: { type: "bandpass", freq: 2200, amp: 0.55 }, dur: 0.07, stop: true },
  d: { f: [400, 1900, 3000], voice: 0.3, noise: { type: "bandpass", freq: 3500, amp: 0.35 }, dur: 0.06, stop: true },
  g: { f: [400, 2000, 2900], voice: 0.3, noise: { type: "bandpass", freq: 1900, amp: 0.4 }, dur: 0.06, stop: true },
  _: { f: [500, 1500, 2500], voice: 0, dur: 0.15 },
};

export class VoicePlayer {
  private buffers = new Map<string, AudioBuffer | null>();
  private wave: PeriodicWave | null = null;
  /** Last clips played (debug). */
  readonly log: { id: string; via: "file" | "synth" | "silent"; at: number }[] = [];

  constructor(
    private e: AudioEngine,
    private defs: Record<string, VoiceDef>,
  ) {}

  has(id: string): boolean {
    return !!this.defs[id];
  }

  async play(id: string): Promise<"file" | "synth" | "silent"> {
    const def = this.defs[id];
    let via: "file" | "synth" | "silent" = "silent";
    if (def && this.e.ctx) {
      const buf = def.file ? await this.load(def.file) : null;
      if (buf) {
        this.playBuffer(buf, def);
        via = "file";
      } else if (def.synth) {
        this.speak(def.synth, def);
        via = "synth";
      }
    }
    this.log.push({ id, via, at: +this.e.now.toFixed(2) });
    if (this.log.length > 20) this.log.shift();
    return via;
  }

  private async load(file: string): Promise<AudioBuffer | null> {
    if (this.buffers.has(file)) return this.buffers.get(file)!;
    let buf: AudioBuffer | null = null;
    try {
      const res = await fetch(`${import.meta.env.BASE_URL}${file}`);
      if (res.ok && !(res.headers.get("content-type") ?? "").includes("text/html")) buf = await this.e.ctx!.decodeAudioData(await res.arrayBuffer());
    } catch {
      buf = null;
    }
    this.buffers.set(file, buf);
    return buf;
  }

  /** Destination for a clip: the voice bus, optionally through a cassette/speaker chain. */
  private chain(def: VoiceDef, t: number, length: number): AudioNode {
    const e = this.e;
    const ctx = e.ctx!;
    const out = e.out("voice", { reverb: def.reverb ?? 0 });
    const g = ctx.createGain();
    g.gain.value = def.gain ?? 1;
    if (!def.tape) {
      g.connect(out);
      return g;
    }
    const hp = ctx.createBiquadFilter();
    hp.type = "highpass";
    hp.frequency.value = 320;
    const lp = ctx.createBiquadFilter();
    lp.type = "lowpass";
    lp.frequency.value = 3400;
    const sat = ctx.createWaveShaper();
    const c = new Float32Array(256);
    for (let i = 0; i < 256; i++) {
      const x = (i / 255) * 2 - 1;
      c[i] = Math.tanh(1.8 * x) / Math.tanh(1.8);
    }
    sat.curve = c;
    g.connect(hp).connect(lp).connect(sat).connect(out);
    // Tape hiss under the clip.
    const hiss = e.noiseSource("white");
    const hg = ctx.createGain();
    hg.gain.setValueAtTime(0, t);
    hg.gain.linearRampToValueAtTime(0.012, t + 0.1);
    hg.gain.setValueAtTime(0.012, t + length);
    hg.gain.linearRampToValueAtTime(0, t + length + 0.4);
    const hlp = ctx.createBiquadFilter();
    hlp.type = "bandpass";
    hlp.frequency.value = 5000;
    hiss.connect(hlp).connect(hg).connect(out);
    hiss.stop(t + length + 0.5);
    e.track(hiss);
    return g;
  }

  private playBuffer(buf: AudioBuffer, def: VoiceDef): void {
    const ctx = this.e.ctx!;
    const t = ctx.currentTime + 0.02;
    const src = ctx.createBufferSource();
    src.buffer = buf;
    if (def.tape) {
      // Wow: slow pitch drift.
      const wow = ctx.createOscillator();
      wow.frequency.value = 0.7;
      const depth = ctx.createGain();
      depth.gain.value = 12;
      wow.connect(depth).connect(src.detune);
      wow.start(t);
      wow.stop(t + buf.duration);
      this.e.track(wow);
    }
    src.connect(this.chain(def, t, buf.duration));
    src.start(t);
    this.e.track(src);
  }

  /** Formant synthesis: glottal pulse + breath noise through three moving formants. */
  speak(sv: SynthVoice, def: VoiceDef = {}): number {
    const e = this.e;
    const ctx = e.ctx!;
    const rate = sv.rate ?? 1;
    const seq = sv.phonemes
      .trim()
      .split(/\s+/)
      .map((tok) => {
        const [k, d] = tok.split(":");
        const p = PH[k] ?? PH._;
        return { ...p, dur: (d ? parseFloat(d) : p.dur) * rate };
      });
    const total = seq.reduce((s, p) => s + p.dur, 0);
    const t0 = ctx.currentTime + 0.03;
    const out = this.chain(def, t0, total);
    const f0 = sv.pitch ?? 280;
    const breathy = sv.breathy ?? 0.2;

    if (!this.wave) {
      const n = 40;
      const re = new Float32Array(n);
      const im = new Float32Array(n);
      for (let k = 1; k < n; k++) im[k] = 1 / Math.pow(k, 1.4);
      this.wave = ctx.createPeriodicWave(re, im);
    }
    const glottis = ctx.createOscillator();
    glottis.setPeriodicWave(this.wave);
    glottis.frequency.setValueAtTime(f0 * 1.06, t0);
    glottis.frequency.linearRampToValueAtTime(f0 * 1.1, t0 + total * 0.3);
    glottis.frequency.linearRampToValueAtTime(f0 * (sv.fall ?? 0.8), t0 + total);
    const vib = ctx.createOscillator();
    vib.frequency.value = 5.2;
    const vibDepth = ctx.createGain();
    vibDepth.gain.value = f0 * 0.012;
    vib.connect(vibDepth).connect(glottis.frequency);
    const voicing = ctx.createGain();
    voicing.gain.value = 0;
    glottis.connect(voicing);
    const breath = e.noiseSource("white");
    const aspiration = ctx.createGain();
    aspiration.gain.value = 0;
    breath.connect(aspiration);

    const tract = ctx.createGain();
    tract.gain.value = 0.9;
    const formants = [0, 1, 2].map((i) => {
      const f = ctx.createBiquadFilter();
      f.type = "bandpass";
      const g = ctx.createGain();
      g.gain.value = [1, 0.6, 0.3][i] * 5.5;
      voicing.connect(f);
      aspiration.connect(f);
      f.connect(g).connect(tract);
      return f;
    });
    tract.connect(out);
    const fric = ctx.createBiquadFilter();
    const fricGain = ctx.createGain();
    fricGain.gain.value = 0;
    breath.connect(fric).connect(fricGain).connect(out);

    let t = t0;
    const first = seq[0];
    formants.forEach((f, i) => {
      f.frequency.setValueAtTime(first.f[i], t0);
      f.Q.value = first.f[i] / [90, 140, 200][i];
    });
    for (const p of seq) {
      const glide = Math.min(0.05, p.dur * 0.35);
      formants.forEach((f, i) => f.frequency.linearRampToValueAtTime(p.f[i], t + glide));
      const voiced = p.voice * (1 - breathy);
      const start = p.stop ? t + p.dur * 0.6 : t;
      if (p.stop) {
        voicing.gain.linearRampToValueAtTime(0, t + 0.015);
        aspiration.gain.linearRampToValueAtTime(0, t + 0.015);
      }
      voicing.gain.linearRampToValueAtTime(voiced * 0.5, start + glide);
      aspiration.gain.linearRampToValueAtTime((p.voice > 0 ? breathy : 0) * 0.45, start + glide);
      if (p.noise) {
        fric.type = p.noise.type;
        fric.frequency.setValueAtTime(p.noise.freq, start);
        fricGain.gain.setValueAtTime(0, start);
        fricGain.gain.linearRampToValueAtTime(p.noise.amp * 0.25, start + (p.stop ? 0.004 : 0.03));
        fricGain.gain.linearRampToValueAtTime(0, t + p.dur);
      }
      t += p.dur;
    }
    voicing.gain.linearRampToValueAtTime(0, t + 0.06);
    aspiration.gain.linearRampToValueAtTime(0, t + 0.08);
    const end = t + 0.15;
    for (const o of [glottis, vib]) {
      o.start(t0);
      o.stop(end);
      e.track(o);
    }
    breath.stop(end);
    e.track(breath);
    return total;
  }
}
