import {
  AdditiveBlending, Group, Mesh, MeshBasicMaterial, PlaneGeometry, PointLight, Quaternion, Raycaster, Vector3, type PerspectiveCamera, type Scene,
} from "three";
import { gsap } from "gsap";
import { MeshKit } from "../world/builder";
import type { Game } from "../game/game";
import type { Guard } from "../ai/guard";

const V = (x: number, y: number, z: number) => new Vector3(x, y, z);

/** resources/weapons/pistol.tres */
export const PISTOL = {
  id: "pistol",
  magazineSize: 8,
  reserveCapacity: 24,
  shotInterval: 0.5,
  reloadTime: 1.5,
  damage: { lower: 30, torso: 70, head: 120 },
  baseNoiseRadius: 38,
  hipSpread: 0.018,
  adsSpread: 0.004,
  hipFov: 72,
  adsFov: 54,
};

/**
 * Dev-only pistol (player_weapon_controller.gd + firearm_component.gd +
 * pistol_visual.gd): semi-auto hitscan, ADS, recoil that recovers without
 * moving the base aim, 1.5 s magazine-swap reload, muzzle flash and noise.
 */
export class PistolController {
  owned = false;
  equipped = false;
  ammo = PISTOL.magazineSize;
  reserve = PISTOL.reserveCapacity;
  private cooldown = 0;
  private reloading = false;
  ads = 0;
  readonly view = new Group();
  private kick = new Group();
  private slide: Mesh;
  private mag: Mesh;
  private flash: Mesh;
  private flashLight: PointLight;
  private raycaster = new Raycaster();
  private ammoEl: HTMLElement;
  private readonly hip = V(0.2, -0.2, -0.42);
  private readonly adsPos = V(0, -0.118, -0.32);
  private guardHealth = new Map<Guard, number>();

  constructor(private game: Game, camera: PerspectiveCamera, scene: Scene) {
    const kit = new MeshKit(game.materials);
    kit.box(V(0, -0.02, 0.02), V(0.034, 0.03, 0.17), "gunmetal", 0x2a2d2e);
    kit.box(V(0, -0.075, 0.07), V(0.032, 0.11, 0.045), "gunmetal", 0x1c1e1f, new Quaternion().setFromAxisAngle(V(1, 0, 0), -0.25));
    kit.box(V(0, -0.045, 0.025), V(0.006, 0.03, 0.05), "gunmetal", 0x111213);
    const frame = kit.build("PistolFrame");
    const slideKit = new MeshKit(game.materials);
    slideKit.box(V(0, 0.012, -0.005), V(0.032, 0.028, 0.19), "gunmetal", 0x3a3e40);
    slideKit.box(V(0, 0.03, -0.09), V(0.006, 0.008, 0.008), "gunmetal", 0x111111);
    slideKit.box(V(0, 0.03, 0.075), V(0.016, 0.008, 0.008), "gunmetal", 0x111111);
    for (let i = 0; i < 5; i++) slideKit.box(V(0, 0.014, 0.05 + i * 0.008), V(0.034, 0.02, 0.002), "gunmetal", 0x1a1a1a);
    slideKit.cylinder(V(0, 0.005, -0.1), 0.006, 0.01, "dark", 0x050505, new Quaternion().setFromAxisAngle(V(1, 0, 0), Math.PI / 2));
    this.slide = slideKit.build("PistolSlide");
    const magKit = new MeshKit(game.materials);
    magKit.box(V(0, -0.085, 0.07), V(0.026, 0.1, 0.035), "gunmetal", 0x141516, new Quaternion().setFromAxisAngle(V(1, 0, 0), -0.25));
    this.mag = magKit.build("PistolMag");
    for (const m of [frame, this.slide, this.mag]) {
      m.castShadow = false;
      m.renderOrder = 10;
    }
    this.flash = new Mesh(new PlaneGeometry(0.12, 0.12), new MeshBasicMaterial({ color: 0xffc070, transparent: true, opacity: 0, blending: AdditiveBlending, depthWrite: false }));
    this.flash.position.set(0, 0.008, -0.13);
    this.kick.add(frame, this.slide, this.mag, this.flash);
    this.view.add(this.kick);
    this.view.position.copy(this.hip);
    this.view.visible = false;
    camera.add(this.view);
    this.flashLight = new PointLight(0xffb060, 0, 9, 2);
    scene.add(this.flashLight);
    this.ammoEl = document.createElement("div");
    this.ammoEl.style.cssText = "position:absolute;right:28px;bottom:70px;font:500 18px Oswald,sans-serif;letter-spacing:0.2em;color:#d9dfd2;display:none;text-shadow:0 1px 6px #000";
    game.hud.root.appendChild(this.ammoEl);
  }

  give(): void {
    if (!this.owned && this.game.inventory.add({ id: "pistol", displayName: "Pistol", category: "FIREARM", devOnly: true }, 1, false)) {
      this.owned = true;
      this.ammo = PISTOL.magazineSize;
      this.reserve = PISTOL.reserveCapacity;
      this.game.hud.showMessage("PISTOL · PRESS 1 TO EQUIP");
    }
  }

  remove(): void {
    if (!this.owned) return;
    this.owned = false;
    this.setEquipped(false);
    this.game.inventory.remove("pistol");
  }

  /** guard.gd: a clearly visible firearm is an immediate identification. */
  get visiblyHeld(): boolean {
    return this.equipped && !this.reloading;
  }

  setEquipped(on: boolean): void {
    this.equipped = on && this.owned;
    this.view.visible = this.equipped;
    this.ammoEl.style.display = this.equipped ? "block" : "none";
    if (this.equipped) gsap.fromTo(this.view.position, { y: this.hip.y - 0.25 }, { y: this.hip.y, duration: 0.3, ease: "power2.out" });
  }

  update(dt: number): void {
    const input = this.game.input;
    const player = this.game.player;
    if (input.justPressed("Digit1") && this.owned) this.setEquipped(!this.equipped);
    if (input.justPressed("KeyH")) this.setEquipped(false);
    if (input.justPressed("KeyG") && this.equipped) this.remove();
    if (!this.equipped) {
      this.ads = Math.max(0, this.ads - dt * 6);
      this.applyAds();
      return;
    }
    this.cooldown -= dt;
    const wantsAds = input.mouseDown(2) && !this.reloading && player.controlEnabled;
    this.ads += ((wantsAds ? 1 : 0) - this.ads) * (1 - Math.exp(-dt * 14));
    this.applyAds();
    // Weapon sway/bob follows the camera motion, damped while aiming.
    const sway = player.motion.positionOffset;
    this.view.position.x += sway.x * 0.6 * (1 - this.ads);
    this.view.position.y += sway.y * 0.8 * (1 - this.ads);
    if (input.justPressed("KeyR")) this.reload();
    if (input.mouseJustPressed(0) && player.controlEnabled) this.fire();
    this.ammoEl.textContent = `${this.ammo} / ${this.reserve}`;
  }

  private applyAds(): void {
    const cam = this.game.render.camera;
    this.view.position.lerpVectors(this.hip, this.adsPos, this.ads);
    const fov = PISTOL.hipFov + (PISTOL.adsFov - PISTOL.hipFov) * this.ads;
    if (Math.abs(cam.fov - fov) > 0.01) {
      cam.fov = fov;
      cam.updateProjectionMatrix();
    }
    this.game.player.motion.precision = this.ads;
  }

  private fire(): void {
    if (this.reloading || this.cooldown > 0) return;
    if (this.ammo <= 0) {
      gsap.fromTo(this.kick.rotation, { x: 0 }, { x: 0.02, duration: 0.05, yoyo: true, repeat: 1 });
      return;
    }
    this.ammo -= 1;
    this.cooldown = PISTOL.shotInterval;
    const cam = this.game.render.camera;
    const origin = cam.getWorldPosition(new Vector3());
    const spread = PISTOL.hipSpread + (PISTOL.adsSpread - PISTOL.hipSpread) * this.ads;
    const dir = cam.getWorldDirection(new Vector3()).add(V((Math.random() - 0.5) * spread, (Math.random() - 0.5) * spread, (Math.random() - 0.5) * spread)).normalize();
    this.hitscan(origin, dir);
    // Presentation: flash, slide cycle, recoil kick that recovers.
    const flashMat = this.flash.material as MeshBasicMaterial;
    flashMat.opacity = 1;
    this.flash.rotation.z = Math.random() * Math.PI;
    gsap.to(flashMat, { opacity: 0, duration: 0.06 });
    this.flash.getWorldPosition(this.flashLight.position);
    this.flashLight.intensity = 40;
    gsap.to(this.flashLight, { intensity: 0, duration: 0.08 });
    gsap.fromTo(this.slide.position, { z: 0 }, { z: 0.045, duration: 0.04, yoyo: true, repeat: 1, ease: "power1.out" });
    const k = 1 - this.ads * 0.6;
    gsap.fromTo(this.kick.rotation, { x: 0 }, { x: 0.16 * k, duration: 0.05, ease: "power2.out", yoyo: true, repeat: 1 });
    gsap.fromTo(this.kick.position, { z: 0 }, { z: 0.045 * k, duration: 0.05, yoyo: true, repeat: 1 });
    const player = this.game.player;
    const pitchKick = 0.012 * k;
    player.pitch += pitchKick;
    gsap.delayedCall(0.06, () => (player.pitch -= pitchKick * 0.8));
    this.game.noise.emitWeaponNoise(origin, "pistol", PISTOL.baseNoiseRadius, PISTOL.baseNoiseRadius, false);
    if (this.ammo === 0) this.slide.position.z = 0.04;
  }

  private hitscan(origin: Vector3, dir: Vector3): void {
    const g = this.game;
    this.raycaster.set(origin, dir);
    this.raycaster.far = 120;
    (this.raycaster as Raycaster & { firstHitOnly?: boolean }).firstHitOnly = true;
    const wall = this.raycaster.intersectObject(g.occluder, false)[0];
    const wallDist = wall ? wall.distance : Infinity;
    let best: { guard: Guard; t: number; y: number } | null = null;
    for (const guard of g.guards.guards) {
      if (guard.state === "STUNNED") continue;
      const hit = rayCapsule(origin, dir, guard.position.clone().add(V(0, 0.25, 0)), guard.position.clone().add(V(0, 1.6, 0)), 0.32);
      if (hit !== null && hit < wallDist && (!best || hit < best.t)) best = { guard, t: hit, y: origin.y + dir.y * hit - guard.position.y };
    }
    if (best) {
      const zone = best.y > 1.48 ? "head" : best.y > 0.85 ? "torso" : "lower";
      const dmg = PISTOL.damage[zone];
      const hp = (this.guardHealth.get(best.guard) ?? 100) - dmg;
      this.guardHealth.set(best.guard, hp);
      g.hud.showMessage(hp <= 0 ? `${zone.toUpperCase()} · ${dmg} · DOWN` : `${zone.toUpperCase()} · ${dmg} · ${hp} HP`, 0.8);
      if (hp <= 0) best.guard.knockDown();
    } else if (wall) {
      this.impact(wall.point, wall.face?.normal ?? V(0, 1, 0));
    }
  }

  private impact(point: Vector3, normal: Vector3): void {
    const mark = new Mesh(new PlaneGeometry(0.06, 0.06), new MeshBasicMaterial({ color: 0x0c0c0c, transparent: true, opacity: 0.85, depthWrite: false, polygonOffset: true, polygonOffsetFactor: -4 }));
    mark.position.copy(point).addScaledVector(normal, 0.005);
    mark.lookAt(point.clone().add(normal));
    this.game.render.scene.add(mark);
    gsap.to(mark.material, { opacity: 0, duration: 4, delay: 20, onComplete: () => mark.removeFromParent() });
  }

  reload(): void {
    if (this.reloading || this.ammo >= PISTOL.magazineSize || this.reserve <= 0) return;
    this.reloading = true;
    const tl = gsap.timeline({
      onComplete: () => {
        const take = Math.min(PISTOL.magazineSize - this.ammo, this.reserve);
        this.ammo += take;
        this.reserve -= take;
        this.reloading = false;
      },
    });
    tl.to(this.kick.rotation, { z: 0.35, x: -0.15, duration: 0.25, ease: "power2.out" })
      .to(this.mag.position, { y: -0.25, duration: 0.25, ease: "power2.in" })
      .set(this.mag.position, { y: -0.25 })
      .to(this.mag.position, { y: 0, duration: 0.45, ease: "power2.out" }, "+=0.25")
      .to(this.slide.position, { z: 0, duration: 0.1 })
      .to(this.kick.rotation, { z: 0, x: 0, duration: 0.2, ease: "power2.inOut" });
  }

  refill(): void {
    this.reserve = PISTOL.reserveCapacity;
    this.ammo = PISTOL.magazineSize;
  }

  resetGuards(): void {
    this.guardHealth.clear();
  }
}

/** Distance along a ray to a capsule (segment a→b, radius r), or null. */
function rayCapsule(o: Vector3, d: Vector3, a: Vector3, b: Vector3, r: number): number | null {
  // Sample-based closest approach: robust and cheap for a handful of guards.
  let best: number | null = null;
  const ab = b.clone().sub(a);
  for (let i = 0; i <= 8; i++) {
    const c = a.clone().addScaledVector(ab, i / 8);
    const oc = c.clone().sub(o);
    const t = oc.dot(d);
    if (t < 0) continue;
    const closest = o.clone().addScaledVector(d, t);
    const dist = closest.distanceTo(c);
    if (dist <= r) {
      const back = Math.sqrt(r * r - dist * dist);
      const hit = t - back;
      if (best === null || hit < best) best = hit;
    }
  }
  return best;
}
