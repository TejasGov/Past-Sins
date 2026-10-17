import { Mesh, Object3D, Raycaster, Vector3, type Camera } from "three";
import type { Player } from "../player/player";

/**
 * Port of the Godot duck-typed contract: anything implementing
 * get_interaction_prompt(player) / interact(player). The player raycasts and
 * walks up the hit object's parent chain looking for `userData.interactable`.
 */
export interface Interactable {
  getInteractionPrompt(player: Player): string;
  interact(player: Player): void;
  /** Root object whose descendants are raycast targets. */
  readonly root: Object3D;
}

export function markInteractable(obj: Object3D, interactable: Interactable): void {
  obj.userData.interactable = interactable;
}

export function findInteractable(start: Object3D | null): Interactable | null {
  let node: Object3D | null = start;
  for (let depth = 0; depth < 6 && node; depth++) {
    const candidate = node.userData.interactable as Interactable | undefined;
    if (candidate && typeof candidate.getInteractionPrompt === "function" && typeof candidate.interact === "function") return candidate;
    node = node.parent;
  }
  return null;
}

/**
 * Per-frame interaction ray (Player._update_interaction_target). Static
 * geometry comes from the BVH occluder; interactables are only tested when
 * their root is within reach, so the cost stays flat as content grows.
 */
export class InteractionSystem {
  private items = new Set<Interactable>();
  private raycaster = new Raycaster();
  current: Interactable | null = null;
  prompt = "";
  distance = 3.2;
  private tmp = new Vector3();

  constructor(private occluder: Mesh) {
    (this.raycaster as Raycaster & { firstHitOnly?: boolean }).firstHitOnly = false;
  }

  register(i: Interactable): void {
    this.items.add(i);
  }

  unregister(i: Interactable): void {
    this.items.delete(i);
    if (this.current === i) this.current = null;
  }

  update(camera: Camera, player: Player): void {
    let next: Interactable | null = null;
    if (player.controlEnabled) {
      const origin = camera.getWorldPosition(this.tmp.clone());
      const dir = camera.getWorldDirection(new Vector3());
      this.raycaster.set(origin, dir);
      this.raycaster.far = this.distance;
      const roots: Object3D[] = [];
      for (const i of this.items) {
        if (!i.root.visible) continue;
        i.root.getWorldPosition(this.tmp);
        if (this.tmp.distanceToSquared(origin) < 36) roots.push(i.root);
      }
      (this.raycaster as Raycaster & { firstHitOnly?: boolean }).firstHitOnly = true;
      const wall = this.raycaster.intersectObject(this.occluder, false)[0];
      (this.raycaster as Raycaster & { firstHitOnly?: boolean }).firstHitOnly = false;
      const hits = roots.length ? this.raycaster.intersectObjects(roots, true) : [];
      let prompt = "";
      for (const hit of hits) {
        if (!hit.object.visible) continue;
        if (wall && wall.distance + 0.02 < hit.distance) break;
        const candidate = findInteractable(hit.object);
        if (!candidate) continue;
        // An interactable with nothing to offer (open locker, collected item)
        // must not hide one behind it (the card inside the locker).
        prompt = candidate.getInteractionPrompt(player);
        if (prompt) {
          next = candidate;
          break;
        }
      }
      this.current = next;
      this.prompt = next ? prompt : "";
      return;
    }
    this.current = null;
    this.prompt = "";
  }
}
