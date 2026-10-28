import { setPannerPosition, type AudioEngine, type Vec3 } from "./engine";

/** Per-layer peak gains (data: audio.json `ambience`). */
export interface AmbienceLevels {
  roomTone: number;
  hum: number;
  buzz: number;
  hall: number;
  wind: number;
  crickets: number;
  rainOpen: number;
  rainRoof: number;
  underwater: number;
  searchlight: number;
}

/** What the world sounds like right now (all 0..1). */
export interface AmbienceInput {
  indoor: number;
  rain: number;
  /** Inside the Cellhouse A atrium (big reverberant hall). */
  atrium: number;
  night: number;
  /** Fluorescent tubes are on (off after lights-out). */
  tubes: number;
  immersion: number;
  /** Overall ambience ducking (memories, cinematics). */
  level: number;
  /** Searchlight beams running (0 by day or once killed). */
  searchlights: number;
}

interface Loop {
  gain: GainNode;
  value: number;
}

/**
 * Continuous beds, crossfaded by the input each tick: interior room tone,
 * 50 Hz mains hum and fluorescent buzz; exterior wind and night insects; rain
 * on open ground vs drumming on roofs; the underwater pressure bed; the
 * atrium's low hall rumble; one positional motor hum per searchlight tower.
 */
export class Ambience {
  private loops = new Map<string, Loop>();
  private towers: { panner: PannerNode; gain: GainNode; osc: OscillatorNode; value: number }[] = [];
  private windFilter!: BiquadFilterNode;
  private buzzGain!: GainNode;
  private t = 0;
  private flicker = 0;
  readonly targets: Record<string, number> = {};

  constructor(
    private e: AudioEngine,
    private levels: AmbienceLevels,
  ) {
    const ctx = e.ctx!;
    const out = e.bus.ambience;
    const loop = (name: string, src: AudioNode): GainNode => {
      const g = ctx.createGain();
      g.gain.value = 0;
      src.connect(g).connect(out);
      this.loops.set(name, { gain: g, value: 0 });
      return g;
    };
    const lp = (f: number, q = 0.7) => {
      const n = ctx.createBiquadFilter();
      n.type = "lowpass";
      n.frequency.value = f;
      n.Q.value = q;
      return n;
    };
    const bp = (f: number, q: number) => {
      const n = ctx.createBiquadFilter();
      n.type = "bandpass";
      n.frequency.value = f;
      n.Q.value = q;
      return n;
    };

    // Interior: air handling rumble, mains hum, tube buzz.
    loop("roomTone", e.noiseSource("brown").connect(lp(220)));
    const hum = ctx.createGain();
    for (const [f, a] of [[50, 1], [100, 0.55], [150, 0.25], [250, 0.08]]) {
      const o = ctx.createOscillator();
      o.frequency.value = f;
      const g = ctx.createGain();
      g.gain.value = a;
      o.connect(g).connect(hum);
      o.start();
    }
    loop("hum", hum);
    const buzz = ctx.createOscillator();
    buzz.type = "sawtooth";
    buzz.frequency.value = 100;
    buzz.start();
    const buzzHp = ctx.createBiquadFilter();
    buzzHp.type = "highpass";
    buzzHp.frequency.value = 1800;
    this.buzzGain = ctx.createGain();
    buzz.connect(buzzHp).connect(bp(3600, 0.9)).connect(this.buzzGain);
    loop("buzz", this.buzzGain);
    loop("hall", e.noiseSource("pink").connect(lp(110, 0.9)));

    // Exterior: wind (gusting band) and crickets at night.
    this.windFilter = bp(500, 0.6);
    loop("wind", e.noiseSource("pink").connect(this.windFilter));
    const chirp = ctx.createOscillator();
    chirp.frequency.value = 4300;
    const am = ctx.createGain();
    am.gain.value = 0;
    const trill = ctx.createOscillator();
    trill.type = "square";
    trill.frequency.value = 28;
    const trillDepth = ctx.createGain();
    trillDepth.gain.value = 0.5;
    trill.connect(trillDepth).connect(am.gain);
    const phrase = ctx.createOscillator();
    phrase.frequency.value = 0.9;
    const phraseDepth = ctx.createGain();
    phraseDepth.gain.value = 0.5;
    phrase.connect(phraseDepth).connect(am.gain);
    chirp.connect(am);
    for (const o of [chirp, trill, phrase]) o.start();
    loop("crickets", am);

    // Rain: hiss on open ground, low drumming on roofs.
    const rainHp = ctx.createBiquadFilter();
    rainHp.type = "highpass";
    rainHp.frequency.value = 700;
    loop("rainOpen", e.noiseSource("white").connect(rainHp).connect(lp(9000)));
    const roof = ctx.createGain();
    e.noiseSource("brown").connect(lp(380)).connect(roof);
    const roofHi = ctx.createGain();
    roofHi.gain.value = 0.25;
    e.noiseSource("pink").connect(bp(1200, 0.7)).connect(roofHi).connect(roof);
    loop("rainRoof", roof);

    // Underwater pressure bed (all low end, so the underwater low-pass leaves it whole).
    const uw = ctx.createGain();
    e.noiseSource("brown").connect(lp(260, 1.2)).connect(uw);
    const swayOsc = ctx.createOscillator();
    swayOsc.frequency.value = 0.18;
    const swayDepth = ctx.createGain();
    swayDepth.gain.value = 0.3;
    swayOsc.connect(swayDepth).connect(uw.gain);
    swayOsc.start();
    loop("underwater", uw);
  }

  /** One positional motor hum per searchlight tower. */
  addTower(pos: Vec3): void {
    const e = this.e;
    const ctx = e.ctx!;
    const osc = ctx.createOscillator();
    osc.type = "sawtooth";
    osc.frequency.value = 58 + Math.random() * 4;
    const whir = ctx.createOscillator();
    whir.type = "square";
    whir.frequency.value = osc.frequency.value * 3.02;
    const wg = ctx.createGain();
    wg.gain.value = 0.25;
    const lp = ctx.createBiquadFilter();
    lp.type = "lowpass";
    lp.frequency.value = 700;
    const g = ctx.createGain();
    g.gain.value = 0;
    osc.connect(lp);
    whir.connect(wg).connect(lp);
    lp.connect(g);
    const panner = ctx.createPanner();
    panner.panningModel = "equalpower";
    panner.distanceModel = "inverse";
    panner.refDistance = 7;
    panner.maxDistance = 120;
    panner.rolloffFactor = 1.3;
    setPannerPosition(panner, pos);
    g.connect(panner).connect(e.bus.ambience);
    osc.start();
    whir.start();
    this.towers.push({ panner, gain: g, osc, value: 0 });
  }

  get towerCount(): number {
    return this.towers.length;
  }

  update(dt: number, s: AmbienceInput): void {
    const L = this.levels;
    const out = 1 - s.indoor;
    const lvl = s.level * (1 - 0.85 * s.immersion);
    this.t += dt;
    // Gusts: slow sum of sines on the wind band and level.
    const gust = 0.7 + 0.2 * Math.sin(this.t * 0.31) + 0.1 * Math.sin(this.t * 0.087 + 1.3);
    const windiness = 0.6 + 0.4 * s.rain + 0.2 * s.night;
    // Tubes flicker now and then.
    this.flicker -= dt;
    let buzz = s.tubes;
    if (this.flicker < 0) {
      this.flicker = 3 + Math.random() * 9;
      if (this.e.ctx && s.indoor > 0.5 && s.tubes > 0.5) {
        const g = this.buzzGain.gain;
        const t = this.e.now;
        g.setValueAtTime(1, t);
        for (let i = 0; i < 4; i++) g.setValueAtTime(i % 2 ? 1 : 2.4, t + i * 0.05 + Math.random() * 0.04);
        g.setValueAtTime(1, t + 0.3);
      }
    }
    const set: Record<string, number> = {
      roomTone: L.roomTone * s.indoor * (0.7 + 0.5 * s.atrium) * lvl,
      hum: L.hum * s.indoor * (0.4 + 0.6 * s.tubes) * lvl,
      buzz: L.buzz * s.indoor * buzz * (1 - 0.5 * s.atrium) * lvl,
      hall: L.hall * s.atrium * s.indoor * lvl,
      wind: L.wind * out * windiness * gust * lvl + L.wind * 0.12 * s.indoor * s.rain * lvl,
      crickets: L.crickets * out * s.night * (1 - s.rain) * lvl,
      rainOpen: L.rainOpen * s.rain * out * lvl,
      rainRoof: L.rainRoof * s.rain * s.indoor * lvl,
      underwater: L.underwater * s.immersion * s.level,
    };
    const ctx = this.e.ctx!;
    const now = ctx.currentTime;
    for (const [name, v] of Object.entries(set)) {
      this.targets[name] = v;
      const l = this.loops.get(name)!;
      if (Math.abs(l.value - v) > 0.0005) {
        l.value = v;
        l.gain.gain.setTargetAtTime(v, now, 0.25);
      }
    }
    this.windFilter.frequency.setTargetAtTime(300 + 700 * gust * windiness, now, 0.5);
    const tower = L.searchlight * s.searchlights * lvl;
    this.targets.searchlight = tower;
    for (const tw of this.towers) {
      if (Math.abs(tw.value - tower) > 0.0005) {
        tw.value = tower;
        tw.gain.gain.setTargetAtTime(tower, now, 0.4);
      }
      // The motor labours a little as the head sweeps.
      tw.osc.detune.setTargetAtTime(Math.sin(this.t * 0.42 + tw.osc.frequency.value) * 40, now, 0.3);
    }
  }
}
