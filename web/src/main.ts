import { Mesh } from "three";
import { acceleratedRaycast } from "three-mesh-bvh";
import { Game } from "./game/game";

// BVH-accelerated raycasts for interaction and guard line-of-sight.
Mesh.prototype.raycast = acceleratedRaycast;

const canvas = document.getElementById("game") as HTMLCanvasElement;
const hudRoot = document.getElementById("hud") as HTMLElement;
const game = new Game({ canvas, hudRoot });
(window as unknown as { __game: Game }).__game = game;
game.init().catch((err) => {
  console.error(err);
  hudRoot.innerHTML = `<pre style="color:#f88;padding:24px;font:12px monospace">${String(err?.stack ?? err)}</pre>`;
});
