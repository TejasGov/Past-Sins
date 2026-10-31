/**
 * WebAudio engine for the web port. Everything is synthesised at runtime
 * (no sound files ship), so the engine is a small modular graph:
 *
 *   one-shots / loops ─┬─► sfx ──────┐
 *                      ├─► ambience ─┴─► world (low-pass: underwater) ─┐
 *                      │      └─► room / hall convolvers ───────────────┤
 *                      ├─► music ──► music hall ───────────────────────┼─► mix ─► comp ─► mute ─► pause ─► master ─► out
 *                      └─► voice ──► (tape chain per clip) ────────────┘
 *
 * The AudioContext is created on the first trusted pointer/key gesture (the
 * start click), so the browser never logs an autoplay warning.
 */

export type BusName = "music" | "sfx" | "ambience" | "voice";

export interface Mix {
  master: number;
  music: number;
  sfx: number;
  ambience: number;
  voice: number;
}

export interface Vec3 {
  x: number;
  y: number;
  z: number;
}

/** Options for positional one-shots. */
export interface Spatial {
  position?: Vec3;
  /** Muffled by a wall between the sound and the camera. */
  occluded?: boolean;
  refDistance?: number;
  maxDistance?: number;
  /** Send to the active room / hall reverb (multiplied by the space's amount). */
  reverb?: number;
}

export class AudioEngine {
  ctx: AudioContext | null = null;
  master!: GainNode;
  private pauseGain!: GainNode;
  private muteGain!: GainNode;
  private comp!: DynamicsCompressorNode;
  private mix!: GainNode;
  readonly bus = {} as Record<BusName, GainNode>;
  /** Shared low-pass every world sound passes through (underwater muffling). */
  world!: BiquadFilterNode;
  /** Gain on the world chain after the filter (underwater pressure dip). */
  worldLevel!: GainNode;
  roomSend!: GainNode;
  hallSend!: GainNode;
  private roomVerb!: ConvolverNode;
  private hallVerb!: ConvolverNode;
  musicVerbSend!: GainNode;
  readonly meters = {} as Record<BusName | "master", AnalyserNode>;
  noise!: { white: AudioBuffer; pink: AudioBuffer; brown: AudioBuffer };
  private ready: (() => void)[] = [];
  private armed = false;
  muted = false;
  paused = false;
  private suspendTimer = 0;
  /** One-shot voices currently sounding (debug / leak check). */
  active = 0;
  played = 0;

  constructor(public mixLevels: Mix) {}

  /** Calls `fn` once the context exists (immediately if it already does). */
  onReady(fn: () => void): void {
    if (this.ctx) fn();
    else this.ready.push(fn);
  }

  /** Creates the context on the first trusted gesture (the start click). */
  armUnlock(): void {
    if (this.armed) return;
    this.armed = true;
    const opts = { capture: true } as const;
    const handler = (e: Event): void => {
      if (!e.isTrusted) return;
      window.removeEventListener("pointerdown", handler, opts);
      window.removeEventListener("keydown", handler, opts);
      window.removeEventListener("touchend", handler, opts);
      this.unlock();
    };
    window.addEventListener("pointerdown", handler, opts);
    window.addEventListener("keydown", handler, opts);
    window.addEventListener("touchend", handler, opts);
  }

  /** Builds the graph (idempotent) and resumes the context. Must run inside a user gesture. */
  unlock(): void {
    if (!this.ctx) {
      this.ctx = new AudioContext({ latencyHint: "interactive" });
      this.build(this.ctx);
      const fns = this.ready;
      this.ready = [];
      for (const fn of fns) fn();
    }
    if (this.ctx.state === "suspended" && !this.paused) void this.ctx.resume().catch(() => undefined);
  }

  get now(): number {
    return this.ctx?.currentTime ?? 0;
  }

  get running(): boolean {
    return this.ctx?.state === "running";
  }

  private build(ctx: AudioContext): void {
    this.noise = { white: noiseBuffer(ctx, "white"), pink: noiseBuffer(ctx, "pink"), brown: noiseBuffer(ctx, "brown") };
    this.master = ctx.createGain();
    this.pauseGain = ctx.createGain();
    this.muteGain = ctx.createGain();
    this.muteGain.gain.value = this.muted ? 0 : 1;
    this.comp = ctx.createDynamicsCompressor();
    this.comp.threshold.value = -14;
    this.comp.knee.value = 12;
    this.comp.ratio.value = 4;
    this.comp.attack.value = 0.006;
    this.comp.release.value = 0.25;
    this.mix = ctx.createGain();
    this.mix.connect(this.comp).connect(this.muteGain).connect(this.pauseGain).connect(this.master).connect(ctx.destination);

    this.world = ctx.createBiquadFilter();
    this.world.type = "lowpass";
    this.world.frequency.value = 20000;
    this.world.Q.value = 0.5;
    this.worldLevel = ctx.createGain();
    this.world.connect(this.worldLevel).connect(this.mix);

    for (const name of ["music", "sfx", "ambience", "voice"] as BusName[]) {
      const g = ctx.createGain();
      this.bus[name] = g;
      const meter = ctx.createAnalyser();
      meter.fftSize = 1024;
      g.connect(meter);
      this.meters[name] = meter;
    }
    this.meters.master = ctx.createAnalyser();
    this.meters.master.fftSize = 1024;
    this.master.connect(this.meters.master);
    this.bus.sfx.connect(this.world);
    this.bus.ambience.connect(this.world);
    this.bus.voice.connect(this.mix);

    this.roomVerb = ctx.createConvolver();
    this.roomVerb.buffer = impulse(ctx, 0.7, 3.2, 0.5);
    this.hallVerb = ctx.createConvolver();
    this.hallVerb.buffer = impulse(ctx, 3.6, 2.2, 0.08);
    this.roomSend = ctx.createGain();
    this.hallSend = ctx.createGain();
    this.roomSend.gain.value = 0.15;
    this.hallSend.gain.value = 0;
    this.roomSend.connect(this.roomVerb).connect(this.world);
    this.hallSend.connect(this.hallVerb).connect(this.world);
    // Sends are fed per sound (Spatial.reverb) and by the sfx bus itself.
    const busSend = ctx.createGain();
    busSend.gain.value = 0.35;
    this.bus.sfx.connect(busSend);
    busSend.connect(this.roomSend);
    busSend.connect(this.hallSend);

    const musicVerb = ctx.createConvolver();
    musicVerb.buffer = impulse(ctx, 4.2, 2.6, 0.12);
    this.musicVerbSend = ctx.createGain();
    this.musicVerbSend.gain.value = 0.45;
    this.bus.music.connect(this.mix);
    this.bus.music.connect(this.musicVerbSend).connect(musicVerb).connect(this.mix);
    this.applyMix();
  }

  applyMix(): void {
    if (!this.ctx) return;
    const m = this.mixLevels;
    const t = this.ctx.currentTime;
    this.master.gain.setTargetAtTime(m.master, t, 0.05);
    for (const name of ["music", "sfx", "ambience", "voice"] as BusName[]) this.bus[name].gain.setTargetAtTime(m[name], t, 0.05);
  }

  setMuted(on: boolean): void {
    this.muted = on;
    if (this.ctx) this.muteGain.gain.setTargetAtTime(on ? 0 : 1, this.ctx.currentTime, 0.04);
  }

  /** Fades out and suspends the context while the game is paused. */
  setPaused(on: boolean): void {
    if (on === this.paused) return;
    this.paused = on;
    const ctx = this.ctx;
    if (!ctx) return;
    clearTimeout(this.suspendTimer);
    if (on) {
      this.pauseGain.gain.setTargetAtTime(0, ctx.currentTime, 0.05);
      this.suspendTimer = window.setTimeout(() => {
        if (this.paused) void ctx.suspend().catch(() => undefined);
      }, 300);
    } else {
      void ctx.resume().catch(() => undefined);
      this.pauseGain.gain.setTargetAtTime(1, ctx.currentTime, 0.08);
    }
  }

  /** Camera → AudioListener (position and orientation). */
  setListener(pos: Vec3, forward: Vec3, up: Vec3): void {
    const ctx = this.ctx;
    if (!ctx) return;
    const l = ctx.listener;
    if (l.positionX) {
      l.positionX.value = pos.x;
      l.positionY.value = pos.y;
      l.positionZ.value = pos.z;
      l.forwardX.value = forward.x;
      l.forwardY.value = forward.y;
      l.forwardZ.value = forward.z;
      l.upX.value = up.x;
      l.upY.value = up.y;
      l.upZ.value = up.z;
    } else {
      l.setPosition(pos.x, pos.y, pos.z);
      l.setOrientation(forward.x, forward.y, forward.z, up.x, up.y, up.z);
    }
  }

  /**
   * Output stage for a one-shot: optional panner + occlusion filter, then the
   * bus, plus reverb sends. Returns the node a voice should connect into.
   */
  out(bus: BusName, s: Spatial = {}, panning: PanningModelType = "HRTF"): AudioNode {
    const ctx = this.ctx!;
    let head: AudioNode = this.bus[bus];
    if (s.occluded) {
      const lp = ctx.createBiquadFilter();
      lp.type = "lowpass";
      lp.frequency.value = 650;
      const g = ctx.createGain();
      g.gain.value = 0.55;
      lp.connect(g).connect(head);
      head = lp;
    }
    if (s.position) {
      const p = ctx.createPanner();
      p.panningModel = panning;
      p.distanceModel = "inverse";
      p.refDistance = s.refDistance ?? 2;
      p.maxDistance = s.maxDistance ?? 80;
      p.rolloffFactor = 1.1;
      setPannerPosition(p, s.position);
      p.connect(head);
      head = p;
    }
    if (s.reverb && bus !== "music") {
      const send = ctx.createGain();
      send.gain.value = s.reverb;
      head.connect(send);
      send.connect(this.roomSend);
      send.connect(this.hallSend);
    }
    return head;
  }

  /** A looping noise source starting at a random offset. */
  noiseSource(kind: "white" | "pink" | "brown"): AudioBufferSourceNode {
    const ctx = this.ctx!;
    const src = ctx.createBufferSource();
    src.buffer = this.noise[kind];
    src.loop = true;
    src.start(ctx.currentTime, Math.random() * src.buffer.duration);
    return src;
  }

  /** Book-keeping for one-shot sources so leaks show up in debugInfo. */
  track(node: AudioScheduledSourceNode): void {
    this.active++;
    this.played++;
    node.onended = () => {
      this.active--;
      node.disconnect();
    };
  }

  /** RMS level per bus in dBFS (signal-flow checks; you can't listen from automation). */
  levels(): Record<string, number> {
    const out: Record<string, number> = {};
    const buf = new Float32Array(1024);
    for (const [name, a] of Object.entries(this.meters)) {
      a.getFloatTimeDomainData(buf);
      let sum = 0;
      for (const v of buf) sum += v * v;
      const rms = Math.sqrt(sum / buf.length);
      out[name] = rms > 0 ? +(20 * Math.log10(rms)).toFixed(1) : -Infinity;
    }
    return out;
  }
}

export function setPannerPosition(p: PannerNode, v: Vec3): void {
  if (p.positionX) {
    p.positionX.value = v.x;
    p.positionY.value = v.y;
    p.positionZ.value = v.z;
  } else p.setPosition(v.x, v.y, v.z);
}

function noiseBuffer(ctx: BaseAudioContext, kind: "white" | "pink" | "brown"): AudioBuffer {
  const len = Math.floor(ctx.sampleRate * 4);
  const buf = ctx.createBuffer(1, len, ctx.sampleRate);
  const d = buf.getChannelData(0);
  let b0 = 0, b1 = 0, b2 = 0, b3 = 0, b4 = 0, b5 = 0, b6 = 0, last = 0;
  for (let i = 0; i < len; i++) {
    const w = Math.random() * 2 - 1;
    if (kind === "white") d[i] = w * 0.5;
    else if (kind === "pink") {
      // Paul Kellet's refined pink filter.
      b0 = 0.99886 * b0 + w * 0.0555179;
      b1 = 0.99332 * b1 + w * 0.0750759;
      b2 = 0.969 * b2 + w * 0.153852;
      b3 = 0.8665 * b3 + w * 0.3104856;
      b4 = 0.55 * b4 + w * 0.5329522;
      b5 = -0.7616 * b5 - w * 0.016898;
      d[i] = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + w * 0.5362) * 0.11;
      b6 = w * 0.115926;
    } else {
      last = (last + 0.02 * w) / 1.02;
      d[i] = last * 3.5;
    }
  }
  // Crossfade the seam so loops don't click.
  const fade = Math.floor(ctx.sampleRate * 0.05);
  for (let i = 0; i < fade; i++) {
    const t = i / fade;
    d[i] = d[i] * t + d[len - fade + i] * (1 - t);
  }
  return buf;
}

/** Synthetic stereo impulse response: decaying noise with a darkening tail. */
function impulse(ctx: BaseAudioContext, seconds: number, decay: number, preDelay: number): AudioBuffer {
  const rate = ctx.sampleRate;
  const len = Math.floor(rate * seconds);
  const buf = ctx.createBuffer(2, len, rate);
  const pre = Math.floor(rate * Math.min(preDelay, 0.2) * 0.25);
  for (let c = 0; c < 2; c++) {
    const d = buf.getChannelData(c);
    let lp = 0;
    for (let i = pre; i < len; i++) {
      const t = (i - pre) / (len - pre);
      const k = 0.15 + 0.8 * (1 - t);
      lp += (Math.random() * 2 - 1 - lp) * k;
      d[i] = lp * Math.pow(1 - t, decay);
    }
  }
  return buf;
}
