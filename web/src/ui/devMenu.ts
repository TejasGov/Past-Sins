import GUI from "lil-gui";
import { Vector3 } from "three";
import type { Game } from "../game/game";

const DEV_ACCESS_CODE = "tez";

/**
 * Port of scripts/dev/dev_mode_manager.gd + dev_menu.gd. Play Mode is the
 * default and has no developer UI; Cmd/Ctrl+D opens an authorization prompt,
 * "tez" + Enter enables Dev Mode and opens the lil-gui menu. F8 toggles the
 * menu while Dev Mode is active; "Exit Dev Mode" clears every override.
 */
export class DevMode {
  enabled = false;
  private gui: GUI | null = null;
  private prompt: HTMLElement;
  private input: HTMLInputElement;
  private error: HTMLElement;
  private devGranted = new Set<string>();
  private wasLocked = false;
  private clockSync = 0;
  readonly state = {
    invulnerable: false,
    noclip: false,
    invisible: false,
    cones: false,
    hour: 12,
    cyclePaused: false,
    weather: "NORMAL",
    ao: true,
    bloom: true,
    shadows: true,
    pixelRatio: 1,
    fps: false,
    teleport: "",
  };

  constructor(private game: Game) {
    this.prompt = document.createElement("div");
    this.prompt.className = "dev-prompt";
    this.prompt.innerHTML = `<label>DEVELOPER AUTHORIZATION</label><input type="password" autocomplete="off" spellcheck="false" /><div class="err"></div>`;
    game.hud.root.appendChild(this.prompt);
    this.input = this.prompt.querySelector("input")!;
    this.error = this.prompt.querySelector(".err")!;
    window.addEventListener("keydown", (e) => this.onKey(e), true);
    this.input.addEventListener("keydown", (e) => {
      e.stopPropagation();
      if (e.key === "Enter") this.attempt(this.input.value);
      if (e.key === "Escape") this.closePrompt();
    });
  }

  private onKey(e: KeyboardEvent): void {
    if ((e.metaKey || e.ctrlKey) && e.code === "KeyD") {
      e.preventDefault();
      e.stopPropagation();
      if (!this.enabled) this.openPrompt();
      else this.toggleMenu();
      return;
    }
    if (e.code === "F8" && this.enabled) {
      e.preventDefault();
      this.toggleMenu();
    }
  }

  openPrompt(): void {
    this.wasLocked = this.game.input.locked;
    this.game.input.suppressPause = true;
    this.game.input.releaseLock();
    this.game.input.enabled = false;
    this.prompt.style.display = "block";
    this.error.textContent = "";
    this.input.value = "";
    setTimeout(() => this.input.focus(), 0);
  }

  closePrompt(): void {
    this.prompt.style.display = "none";
    this.input.blur();
    this.game.input.enabled = true;
    this.game.input.suppressPause = false;
    if (this.wasLocked) this.game.input.requestLock();
  }

  attempt(code: string): boolean {
    if (code.trim().toLowerCase() !== DEV_ACCESS_CODE) {
      this.error.textContent = "AUTHORIZATION REJECTED";
      this.input.value = "";
      return false;
    }
    this.prompt.style.display = "none";
    this.input.blur();
    this.setEnabled(true);
    this.openMenu();
    return true;
  }

  setEnabled(value: boolean): void {
    this.enabled = value;
    this.game.hud.devBadge.style.display = value ? "block" : "none";
    if (!value) {
      this.closeMenu();
      this.gui?.destroy();
      this.gui = null;
      window.clearInterval(this.clockSync);
      this.returnToNormal();
    }
  }

  toggleMenu(): void {
    if (this.gui && this.gui.domElement.style.display !== "none") this.closeMenu();
    else this.openMenu();
  }

  openMenu(): void {
    if (!this.gui) this.build();
    this.gui!.domElement.style.display = "";
    this.game.input.suppressPause = true;
    this.game.input.releaseLock();
    this.game.player.setControlEnabled(false);
    this.game.input.enabled = true;
  }

  closeMenu(): void {
    if (!this.gui) return;
    this.gui.domElement.style.display = "none";
    this.game.player.setControlEnabled(true);
    this.game.input.suppressPause = false;
    this.game.input.enabled = true;
  }

  get menuOpen(): boolean {
    return !!this.gui && this.gui.domElement.style.display !== "none";
  }

  private destinations(): Record<string, Vector3> {
    const g = this.game;
    const out: Record<string, Vector3> = {};
    const spawn = g.anchors.get("parth_spawn");
    if (spawn) out["Cellhouse A · Parth's cell (F3)"] = spawn.position.clone();
    out["Cellhouse A · Dayroom (F1)"] = new Vector3(-50, 0.05, 2.5);
    out["Cellhouse A · Tier 2 gallery"] = new Vector3(-50, 4.05, 9);
    out["Central yard"] = new Vector3(0, 0.05, 0);
    out["Pool deck"] = new Vector3(-14, 0.05, 36);
    out["Outside Maintenance (north door)"] = new Vector3(48, 0.05, 32);
    for (const [planId, floor] of g.floors) {
      for (const [roomId, center] of floor.roomCenters) {
        const room = floor.rooms.get(roomId)!;
        if (room.type === "stair" || room.type === "lift" || room.type === "void") continue;
        if (room.type === "cell") continue;
        out[`${floor.plan.name} · ${floor.plan.level} · ${room.label.replace(/\n/g, " ")}`] = center.clone().add(new Vector3(0, 0.05, 0));
        void planId;
      }
    }
    return out;
  }

  private build(): void {
    const g = this.game;
    const s = this.state;
    const gui = new GUI({ title: "BLACKSITE · DEV MODE", width: 340 });
    gui.domElement.style.zIndex = "20";
    this.gui = gui;

    const dest = this.destinations();
    const nav = gui.addFolder("Teleport");
    nav.add(s, "teleport", Object.keys(dest)).name("destination").onChange((name: string) => {
      const p = dest[name];
      if (p) g.player.teleport(p);
    });

    const player = gui.addFolder("Player");
    player.add(s, "invulnerable").name("invulnerable (no detention)").onChange((v: boolean) => (g.guards.invulnerable = v));
    player.add(s, "invisible").name("invisible to guards").onChange((v: boolean) => (g.guards.devInvisible = v));
    player.add(s, "noclip").name("noclip free flight").onChange((v: boolean) => {
      g.player.noclip = v;
      g.player.collider.setEnabled(!v);
    });
    player.add({ reset: () => g.suspicion.reset() }, "reset").name("reset suspicion");
    player.add({ alert: () => (g.suspicion.value = 100) }, "alert").name("force ALERT");
    player.add({ normal: () => this.returnToNormal() }, "normal").name("return player to normal");

    const world = gui.addFolder("Time & Weather");
    s.hour = g.env.timeHours;
    world.add(s, "hour", 0, 23.99, 0.05).name("time of day").listen().onChange((v: number) => g.env.setTimeHours(v));
    world.add(s, "cyclePaused").name("pause clock").onChange((v: boolean) => (g.env.cycleEnabled = !v));
    world.add(s, "weather", ["NORMAL", "RAINY"]).onChange((v: "NORMAL" | "RAINY") => g.env.setWeather(v));
    world.add({ day: () => g.env.debugBeginNewDay(Math.random()) }, "day").name("begin new day (roll weather)");
    world.add(g.env, "dayLengthSeconds", 60, 3600, 10).name("day length (s)");

    const inv = gui.addFolder("Inventory / Access");
    const keys = new Set<string>(["cellblock_key", "service_key", "medical_key", "security_key", "lab_key", "cell_master_key", "maintenance_access_card"]);
    for (const d of g.doorSpecs) if (d.requiredKey) keys.add(d.requiredKey);
    const keyState = { key: "security_key" };
    inv.add(keyState, "key", [...keys].sort()).name("key id");
    inv.add({ give: () => this.giveKey(keyState.key) }, "give").name("give selected key");
    inv.add({ all: () => ["cellblock_key", "service_key", "medical_key", "security_key", "lab_key", "cell_master_key"].forEach((k) => this.giveKey(k)) }, "all").name("give all master keys");
    inv.add({ pistol: () => g.weapons?.give() }, "pistol").name("give pistol (dev only)");
    inv.add({ clear: () => this.clearDevItems() }, "clear").name("clear dev-granted items");
    inv.add({ unlock: () => this.nearestDoor((d) => d.setState(true, false)) }, "unlock").name("open nearest door/gate");
    inv.add({ lock: () => this.nearestDoor((d) => d.reset()) }, "lock").name("restore nearest door/gate");

    const ai = gui.addFolder("AI / Suspicion");
    ai.add(s, "cones").name("show detection cones").onChange((v: boolean) => (g.guards.showCones = v));
    ai.add({ reset: () => g.guards.reset() }, "reset").name("reset guards");
    ai.add({ detain: () => g.detentionReset() }, "detain").name("restart at cell");

    const story = gui.addFolder("Story");
    const st = { act: g.story.state.act, flag: "", cycle: g.story.state.cycle };
    story.add(st, "act", [1, 2, 3]).name("act").onChange((v: number) => g.story.setAct(Number(v)));
    story.add(st, "flag").name("flag (Enter = toggle)").onFinishChange((v: string) => {
      const f = v.trim();
      if (f) g.story.setFlag(f, !g.story.hasFlag(f));
    });
    story.add(st, "cycle", 1, 99, 1).name("cycle").onFinishChange((v: number) => (g.story.state.cycle = v));
    story.add({ capture: () => void g.story.capture("dev") }, "capture").name("capture now (→ wipe)");
    story.add({ wipe: () => void g.story.wipe() }, "wipe").name("wipe (skip capture)");
    story.add({ log: () => console.table(g.story.debugInfo()) }, "log").name("log story state");
    story.add({ clear: () => g.story.resetSave() }, "clear").name("CLEAR SAVE (cycle 41)");

    const gfx = gui.addFolder("Graphics");
    gfx.add(s, "ao").name("N8AO ambient occlusion").onChange((v: boolean) => (g.render.ao.enabled = v));
    gfx.add(s, "bloom").onChange((v: boolean) => (g.render.bloom.intensity = v ? 0.85 : 0));
    gfx.add(s, "shadows").name("sun/searchlight shadows").onChange((v: boolean) => {
      g.render.quality.shadows = v;
    });
    s.pixelRatio = g.render.quality.pixelRatio;
    gfx.add(s, "pixelRatio", 0.5, 2, 0.05).name("render scale").onFinishChange((v: number) => g.render.setPixelRatio(v));
    gfx.add(s, "fps").name("show FPS").onChange((v: boolean) => (g.showFps = v));
    gfx.add(g.lighting, "wetness", 0, 1, 0.01).listen();
    for (const f of [player, world, inv, ai, story, gfx]) f.close();
    nav.open();
    gui.add({ exit: () => this.setEnabled(false) }, "exit").name("EXIT DEV MODE");
    this.clockSync = window.setInterval(() => (s.hour = g.env.timeHours), 500);
  }

  private nearestDoor(fn: (d: Game["doors"][number]) => void): void {
    const p = this.game.player.position;
    let best: Game["doors"][number] | null = null;
    let bestD = 9;
    for (const d of this.game.doors) {
      const dist = d.position.distanceTo(p);
      if (dist < bestD) {
        bestD = dist;
        best = d;
      }
    }
    if (best) fn(best);
  }

  private giveKey(id: string): void {
    if (this.game.access.addKey(id, "", id.endsWith("_card") ? "ACCESS_CARD" : "KEY", true)) {
      this.devGranted.add(id);
      this.game.hud.showMessage(`DEV · ${id.toUpperCase()} GRANTED`);
    }
  }

  private clearDevItems(): void {
    this.game.inventory.clearDevOnly();
    this.game.weapons?.remove();
    this.devGranted.clear();
  }

  /** Exit Dev Mode: clears cheats and dev-granted inventory, restores doors. */
  returnToNormal(): void {
    const g = this.game;
    const s = this.state;
    s.invulnerable = s.noclip = s.invisible = s.cones = false;
    g.guards.invulnerable = false;
    g.guards.devInvisible = false;
    g.guards.showCones = false;
    g.player.noclip = false;
    g.player.collider.setEnabled(true);
    g.env.cycleEnabled = true;
    this.clearDevItems();
    for (const d of g.doors) if (d.isOpen && d.isLocked === false && d.spec.startsLocked && !g.access.isAccessUnlocked(d.spec.persistentId)) d.reset();
  }
}
