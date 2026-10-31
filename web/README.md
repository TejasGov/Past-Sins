# Blacksite: Ghost Exit — web build

A browser rebuild of the Godot 4.7 prototype in this repository (the Godot project at the repo root stays untouched as the reference). Stack: **Vite + TypeScript**, **three.js r186** (WebGL2), **@dimforge/rapier3d-compat** (kinematic character controller), **GSAP** (camera moves, doors and gates, cinematics), **anime.js v4** (HUD text, transcript reveal, prompts, suspicion meter), **pmndrs postprocessing + n8ao** (AO, bloom, SMAA, AgX, vignette, film grain, chromatic aberration), **three-mesh-bvh** (interaction and line-of-sight raycasts) and **lil-gui** (dev menu).

## Run, build, deploy

```bash
npm install
npm run dev        # http://localhost:5173 (strict port; .claude/launch.json config "web")
npm run build      # tsc --noEmit + vite build → dist/
npm run preview    # serve dist/ on :4173
```

`dist/` is a fully static site with relative paths (`base: "./"`), so you can host it from any static server or subfolder: GitHub Pages, Netlify, S3/CloudFront, `npx serve dist`, and so on. No server code or special headers are needed, because Rapier ships its wasm inlined. `public/` (textures, data and the character GLB) is copied verbatim.

Production builds strip the developer surface: `window.__game` (the automation hook) and the Dev Mode unlock exist only under `npm run dev`. Download size is about 31 MB (one ~6 MB JS bundle, 2.2 MB gzipped, 12 MB of WebP textures and 7 MB of prop models).

- `npm run textures` rebuilds `public/textures/*.webp` from the Godot `textures/` folder (needs `cwebp`).
- `?fps` in the URL shows an FPS / draw-call counter. `?fresh` deletes the save and starts a new game.
- `web/asset-pipeline/` and `public/assets/characters/` belong to the character pipeline (Mixamo Ch35 → `guard.glb` + `manifest.json`). Rebuild with `npm --prefix web/asset-pipeline run build:characters`.
- `public/assets/props/` holds 27 CC0 [Poly Haven](https://polyhaven.com) models (7 MB), built by the same pipeline (see its README). `src/world/models.ts` loads them before the campus is built; `StaticBuilder.prop()` places one and `finalize()` turns every placement into one `InstancedMesh` per model and chunk.

## Controls

| Action | Input |
| --- | --- |
| Move / look | W A S D / mouse. Clicking the canvas captures the pointer; if the browser refuses or delays pointer lock, moving the cursor over the canvas still turns the view (documents and choice panels freeze it so you can click) |
| Sprint / crouch / jump | Shift / C (or Left Ctrl) / Space |
| Interact, collect, use | E (also skips the memory transcript once it has been typed out, and skips seen cinematics) |
| Minimap | M |
| Mute | N (remembered between sessions) |
| Release pointer | Esc (keyboard movement still works) |
| Swim / dive / rise | WASD / hold C / hold Space |
| Dev Mode (`npm run dev` only) | ⌘D (or Ctrl+D), type `tez`, Enter. F8 or ⌘D toggles the menu afterwards |
| Pistol (Dev Mode only) | 1 equip/holster, LMB fire, hold RMB to aim, R reload, H holster, G drop |

## What is playable

1. **Movement**: walk 4.2, sprint 7.0, crouch 2.1 m/s, jump 5.4, accel 18 / air 5, gravity 18. Capsule 1.8 → 1.1 m with the base kept fixed, plus a headroom sweep before standing. Camera 0.72 / 0.04 m with Godot's bob and footfall jitter. Sensitivity 0.0022 rad/px, ±85° pitch, 3.2 m interaction ray. Smooth stair ramps are convex colliders under solid treads.
2. **Campus**: all 13 floor plans from `floor_plans.json` (compacted exactly like `campus_plan_compactor.gd`), the seven buildings and their shells, Cellhouse A's three tiers, galleries, bridges and stair flights, 45 cell modules and the guard/lift cores, Cellhouse B with its fence and sector gates, HQ + NIDRA B2 (via the sealed B1 shaft), Maintenance + B1, the perimeter wall and sally ports, the central yard, roads, the pool annex and eight watchtowers. Statics are merged per material into one mesh per chunk, with Rapier cuboids for collision and a BVH proxy for raycasts.
3. **Loop**: Parth wakes in A-3-N03 → memory_001 on the shelf (GSAP camera dolly, desaturation, chromatic pulse, then an anime.js glitch/typewriter transcript and the scrambled clue `2718`) → the dayroom rack holds `cellblock_key`, `service_key` and `medical_key` → Maintenance's tool-room keypad changes from **[E] Examine keypad** to **[E] Enter remembered code** → **MAINTENANCE ACCESS CARD**. Doors and gates go through AccessManager (keys, master key, persistent unlocks), and refuse to close on someone standing in the doorway.
4. **Guards**: patrol, wait, then range → FOV → BVH line-of-sight perception. Suspicion builds at 10/s scaled by proximity (×3 → ×0.75), stance (sprint ×1.85, crouch ×0.42), restricted zones, and darkness at night. ALERT → pursuit at 4.8 m/s, a catch within 1.25 m with LOS, then the **DETAINED** overlay and an in-place reset to the cell (memories, keys and unlocks persist, like the Godot autoloads). Noise (footsteps, landings, doors, gunshots) makes guards investigate. SEARCHING sends them to the last known position. Ch35 is animated with AnimationMixer crossfades, and timeScale is matched to speed so feet don't slide.
5. **World**: 12-real-minute day; morning/day/evening/night; fixtures on at 18:30 and off at 07:00 (interior night-only tubes idle dim by day). Rain chance is 25%, or 10% after a rainy day, with camera-local streaks that pause under roofs and wet specular ground. Three shadowed, sweeping searchlights carry volumetric cones; standing in a beam raises suspicion. Pool swimming with buoyancy and underwater tint/fog. The minimap switches between the campus and the current storey. HUD shows the clock and weather.
6. **Dev Mode**: teleports to every named room, invulnerable / invisible / noclip, time, weather and day length, key and pistol grants, door overrides, detection cones (which also mark guards on the minimap), graphics toggles (AO, bloom, shadows, render scale, FPS), and Exit Dev Mode, which clears every override. **Pistol**: 8 + 24 rounds, 0.5 s semi-auto, 1.5 s magazine-swap reload, ADS, recovering recoil, muzzle flash, head/torso/lower damage 120/70/30 against guards, and weapon noise. A visibly held firearm is an instant ALERT.

## The story ("Again")

The full outline is in `docs/story/AGAIN_OUTLINE.md`. The story layer lives in `src/story/` (director, triggers, dialogue, story UI, save state) with one folder per feature under `src/story/features/`:

| Feature | What it does |
| --- | --- |
| `loop` | Capture cinematic down to NIDRA B2 and the chair ("Again."), the wake in N03, the tally and the wall, the cistern stash, the B1 stair alarm, the 21:00 dose knock-out, and the Act III night restart |
| `routine` | The 12-minute prison day: count, meals and the dose at the dietary window, work, yard, lock-in, lights out, and day-3 visitation; pocketing the pill causes withdrawal |
| `water` | The 2·7·1·8 breath meter and drowning, pool memories T1–T3, and the Act III culvert swim with air pockets and the hand |
| `npcs` | Bhosle, Kabir (freeable, follows on the nav graph), Parth's mother at visitation, and Meera at the observation glass |
| `content` | All 18 memory shards, props, documents, doorplates, the 281828 lift and the objective chain |
| `endings` | Let Go, Hold On and Mercy, with credits |
| `audio` | A fully synthesised WebAudio soundscape and score (no sound files); voices are synth stand-ins until real clips go in `public/audio/voice/` |

**Saving:** the cycle count, wall, learned codes, cistern stash, endings seen and story variables are saved to `localStorage` (`blacksite.ghostexit.save.v1`), so progress survives a reload. Blocked storage (private mode) just means no save.

## Content is data-driven

- `public/data/content/session.json`: start hour, spawn anchor, memory shard placement, key racks, the cell-key register, lockers and their rewards, the objective chain, guard patrol routes and tuning, and restricted zones.
- `public/data/memories/*.json`: the 18 memory shards (title, transcript, clue).
- `public/data/story/`: `index.json` (features and prefetched shards), `objectives.json`, `documents.json`, `dialogue/`, `triggers/` and per-feature tuning in `features/`.
- `public/data/campus/floor_plans.json`: copied verbatim from `data/campus/`.

## Godot → TypeScript map

| Godot | TypeScript |
| --- | --- |
| `scripts/player/player.gd` | `src/player/player.ts` |
| `scripts/player/camera_motion.gd` | `src/player/cameraMotion.ts` |
| `scripts/player/player_swimming.gd`, `scripts/props/swimming_pool.gd`, `shaders/pool_water.gdshader` | `src/world/pool.ts` |
| `shaders/underwater_overlay.gdshader`, `shaders/screen_grade.gdshader` | `src/render/effects.ts` (UnderwaterEffect, GradeEffect) |
| Autoloads `suspicion_system.gd`, `memory_manager.gd`, `access_manager.gd`, `inventory_manager.gd` + `scripts/inventory/`, `world_noise_system.gd` | `src/systems/{suspicion,memory,access,inventory,noise}.ts` |
| `campus_environment_cycle.gd`, `interior_lighting_profiles.gd`, `gallery_lighting.gd` | `src/systems/environment.ts`, `src/render/worldLighting.ts`, `src/render/lightPool.ts` |
| `scripts/ai/guard.gd`, `campus_phase_two_gameplay.gd` (guard spawn, detention) | `src/ai/guard.ts`, `src/ai/guards.ts`, `src/ai/guardVisual.ts` |
| Interaction contract in `player.gd` | `src/interact/interactable.ts` (`Interactable`, ancestor walk, `InteractionSystem`) |
| `normal_door.gd`, `prison_sliding_gate.gd`, `CampusTelescopicGate` | `src/interact/door.ts` |
| `memory_shard.gd`, `key_pickup.gd`, `keypad_locker.gd`, `campus_resting_memory.gd`, `campus_mounted_key.gd`, `campus_keypad_locker.gd` | `src/interact/pickups.ts` |
| `campus_session_content.gd`, `restricted_zone.gd` | `src/game/session.ts` + `session.json` |
| `prison_campus_prototype.gd` | `src/world/campus/campus.ts`, `src/game/game.ts` |
| `greybox_factory.gd`, `campus_furniture_batcher.gd`, `campus_static_batching.gd` | `src/world/builder.ts` (`StaticBuilder`, `MeshKit`), `src/world/signAtlas.ts` |
| `interiors/campus_blueprint_floor.gd`, `campus_plan_compactor.gd`, `campus_interior_assembly.gd` | `src/world/campus/blueprintFloor.ts`, `plans.ts`, `buildings.ts` |
| `interiors/cellhouse_a_interior.gd`, `modules/campus_prison_cell.gd`, `campus_guard_elevator_core.gd` | `src/world/campus/cellhouseA.ts`, `cell.ts`, `guardCore.ts` |
| `modules/campus_stair_flight.gd`, `campus_switchback_stair.gd` | `src/world/campus/stairs.ts` |
| `building_shell_base.gd`, `buildings/*.gd` | `src/world/campus/shell.ts`, `buildings.ts` (`BUILDINGS`) |
| `campus_perimeter.gd`, `central_yard_grounds.gd`, `roads_and_paths.gd`, `zones/campus_recreation_annex.gd`, `props/watchtower.gd` | `src/world/campus/exterior.ts`, `src/render/searchlights.ts` |
| `furnishing/campus_room_furnisher.gd` | `src/world/campus/furnisher.ts` (compact recipe set) |
| Props (`props/*.gd`, `scenes/props/**`) | `src/world/props.ts` |
| `scripts/ui/hud.gd`, `scripts/ui/minimap.gd` | `src/ui/hud.ts` (+ `hud.css`), `src/ui/minimap.ts` |
| `scripts/dev/dev_mode_manager.gd`, `dev_menu.gd` | `src/ui/devMenu.ts` |
| `player_weapon_controller.gd`, `firearm_component.gd`, `pistol_visual.gd`, `resources/weapons/pistol.tres` | `src/weapons/pistol.ts` |

## Rendering notes

- **Post**: RenderPass → N8AO (half-res) → [underwater, mip-mapped bloom, AgX tone mapping, grade (contrast, saturation, split tone), vignette, fade, film grain] → chromatic aberration → SMAA. Exposure adapts between interiors, day and night.
- **Lighting**: CSM sun/moon (3 cascades, 2048²). Every fluorescent, cell lamp and sodium wall pack is a candidate for a fixed pool of 12 unshadowed point lights reassigned by distance, so shader cost stays constant (some tubes flicker). Searchlights are the only shadowed spots, and their shadow maps update only after dark. Skylight sun shafts and searchlight cones are additive "volumetric-looking" meshes. Dust motes drift around the camera.
- **Surfaces**: the Godot textures as WebP PBR sets, with world-space UVs so merged walls tile seamlessly. A shared shader patch adds damp grime streaks and blotches and rain wetness (darker albedo, glossy puddles on exterior up-faces).
- **Budget**: exterior statics are split into 80 m cells for frustum culling. Inside a building only that building's interior chunk is drawn, and cell modules skip the sun's shadow passes. Skinned guards are range-culled. An adaptive render scale (0.7 to min(DPR, 1.5)) holds about 60 fps.

## Not ported yet / known gaps

- **Navigation**: guards path with A* over a waypoint graph (`src/ai/nav.ts`, `src/world/nav.ts`) built from floor plans, stairs, the Cellhouse A tiers and every door, so pursuit and search follow stairs between storeys. There is no full navmesh; open areas use grids and links.
- **Voices**: every spoken line, including "Again." and Raman's counting, is a synthesised stand-in.
- **Input**: desktop only (keyboard + mouse). No touch or gamepad controls.
- **Bundle**: the game ships as one ~6 MB JS chunk; there is no code splitting or per-area loading yet.
- **Weapons beyond the pistol**: SMG, carbine, sniper, melee, suppressors, noose and tranquilizer, plus the Weapons Test Range, Dev Test Hub, health/armour probe and other dev scenes.
- **Props**: the per-prop libraries (cafeteria kitchen, medical lab, gym/shower, environment dressing, CCTV logic, metal detectors) are approximated by `furnisher.ts`. CCTV cameras are visual only.
- **`character_faction.gdshader`**: not ported, because it targeted the old PSX atlas; Ch35 uses its own materials.
- **Lifts**: only the HQ restricted lift runs (code 281828, as a fade between lobbies); the others stay sealed, as in Godot.
- **Automated tests**: none yet. Verification so far is by playing in the browser, plus `tsc` and `vite build`.
