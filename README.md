# Blacksite: Ghost Exit

A Godot 4 stealth greybox set in a seven-building prison campus. Parth starts on the third cell tier of Cellhouse A; food services, medical/gym/showers, high security, command, maintenance and administration are separate buildings with implemented interiors. The original single-building prison remains available as a legacy reference.

See [the campus implementation and test guide](docs/CAMPUS_IMPLEMENTATION.md) for the current layout, reusable modules, access rules and validation commands.

Everything in the prototype uses Godot primitives, built-in materials, and GDScript. There are no external or paid assets.

## Launch

1. Install Godot 4.3 or newer.
2. Import `project.godot` from this directory into the Godot Project Manager.
3. Press **F5** to run `scenes/levels/campus/PrisonCampusPrototype.tscn`. To inspect the old reference instead, open `scenes/levels/CellBlockPrototype.tscn` and press **F6**.

The prototype starts immediately in Parth's prison cell. Godot captures the mouse on launch; press Escape to release or recapture it.

## Controls

| Action | Input |
| --- | --- |
| Move | W, A, S, D |
| Look | Mouse |
| Sprint | Hold Shift |
| Crouch | Hold C |
| Jump | Space |
| Interact / collect / use | E |
| Release or recapture mouse | Escape |
| Toggle minimap | M |
| Request Dev Mode access | Command+D, enter `tez`, then Enter |
| Developer menu (Dev Mode only) | F8 |
| Equip / toggle firearm slots | 1 / 2 |
| Fire equipped pistol | Left mouse button |
| Aim down pistol sights | Hold right mouse button |
| Reload pistol | R |
| Holster pistol | H |
| Drop equipped pistol | G |
| Range health probe value | [ / ] |
| Apply range health probe | T |
| Reset range targets | Y, or E at the console |
| Swim / dive / rise (in pool) | WASD / hold C / hold Space |

The minimap automatically shows the current building and floor indoors, then returns to the campus overview outside. The community pool beside Medical has an open deck and steps at both ends. Underwater tint/fog clears when you surface; no drowning mechanic is enabled.

The campus runs a configurable morning/day/evening/night clock. Supported facility lights and designated watchtower searchlights switch on after dark. Each new day has a 25% rain chance, reduced to 10% when the previous day was rainy; the HUD shows the current day, time, phase and weather.

Play Mode is the default and contains no developer UI or cheats. While playing, press Command+D, type `tez`, and press Enter to authorize Dev Mode and open its menu. F8 opens/closes the menu while Dev Mode is active; **Exit Dev Mode** returns to Play Mode and clears test overrides. You can still start directly in Dev Mode with `blacksite/development/dev_mode=true` in `project.godot` or the `-- --dev-mode` launch argument. The external Dev Test Hub and registration APIs are documented in [scripts/dev/README.md](scripts/dev/README.md).

The reusable inventory foundation provides two category-neutral firearm slots, one melee slot, and expandable equipment/key/access-card/mission-item storage. The Weapons Test Range contains seven colored DEV-only data tokens for exercising full-slot, unique-item and stack-count behavior; they have no combat or item-use behavior. Current slot contents and clear/give/remove controls are under **F8 → Inventory / Access**.

The pistol is the only implemented weapon and remains restricted to Dev Mode. Its reusable low-poly model has a chamfered slide, tapered grip, open trigger guard, barrel/bore, ejection port, serrations, controls, sights and removable magazine rather than a box-only silhouette. Its authored pickup is in the Weapons Test Range; it can also be granted through **F8 → Inventory / Access**. Hip fire displays a responsive centered crosshair; holding right mouse smoothly aligns the iron sights, tightens spread, reduces weapon motion and narrows FOV. Recoil recovers without shifting the base camera aim, movement drives subtle sway/bob, the slide cycles and locks open on empty, and the unchanged 1.5-second reload visibly exchanges the separate magazine. No suitable existing dry-fire audio was available, so empty trigger pulls remain silent. No pistol pickup is authored in the prison campus, and all SMG, AR, sniper, melee, suppressor, noose and tranquilizer displays remain nonfunctional placeholders.

Walk out of the cell, recover the blue memory shard near the bed, and wait for the reconstruction to finish. The recovered `2718` clue changes the maintenance locker's prompt from **[E] Examine keypad** to **[E] Enter remembered code**. The locker then reveals the **MAINTENANCE ACCESS CARD** placeholder.

The translucent green/red wedge is the guard's development-only detection visualization. It turns red when the guard has field-of-view and unobstructed line-of-sight to Parth.

## Folder architecture

```text
res://
├── data/                         # Content records, currently memory_001.json
├── scenes/
│   ├── interactables/            # Memory shard, keypad locker, restricted zone
│   ├── levels/                   # Main scene plus reusable floor modules
│   ├── npc/                      # Reusable Guard scene
│   ├── player/                   # CharacterBody3D first-person player
│   └── ui/                       # HUD, memory reconstruction, failure overlay
└── scripts/
    ├── ai/                       # Patrol, perception, pursuit
    ├── interactables/            # Reusable interaction behaviors
    ├── levels/                   # Greybox factory, floor layouts, mission flow
    ├── player/                   # Movement, look, raycast interaction
    ├── inventory/                # Reusable item definitions and slot/stack component
    ├── systems/                  # Autoloaded suspicion, memory, access and inventory services
    └── ui/                       # HUD presentation
```

The player does not know about specific interactable classes. It walks up the raycast collider's parent chain and accepts any node that implements `get_interaction_prompt(player)` and `interact(player)`.

## Legacy single-building layout

The floor scenes under `scenes/levels/floors/` are independently reusable modules. B2 through Floor 1 share a service stairwell. Floors 1–3 form the open central atrium, using balcony walkways, collision-backed bridges, railings, and stair flights across the void. Floor 3 connects upward to surveillance on Floor 4, which connects to the roof service area.

Visible stair steps use one aligned ramp collision shape per flight. This keeps movement smooth and Web-friendly while retaining a readable stair silhouette. The shared `greybox_factory.gd` also caches repeated box meshes and materials within each floor module.

## Suspicion system

`SuspicionSystem` is an autoload with a clamped 0–100 value and the following states:

| Value | State |
| --- | --- |
| 0–24 | NORMAL |
| 25–49 | WATCHING |
| 50–74 | SUSPICIOUS |
| 75–99 | SEARCHING |
| 100 | ALERT |

It emits `suspicion_changed`, `suspicion_state_changed`, and `alert_triggered`. Suspicion decays after a short grace period when guards are no longer adding detection pressure.

Guards first test range, then field-of-view, then a physics ray for unobstructed line-of-sight. Detection is faster up close and while Parth sprints, slower while he crouches, and substantially faster while he is visible inside a restricted zone. At ALERT, guards pursue Parth. If a guard reaches him, the HUD fades to **DETAINED** and reloads the level.

The `debug_detection` export on each guard toggles its translucent detection wedge.

## Memory system

`MemoryManager` is an autoload that owns collected-memory records and learned clues for the application session. `MemoryShard` exposes editable ID, title, transcript, and practical clue fields. On collection it:

1. locks movement and look;
2. records the memory and clue;
3. plays the HUD reconstruction overlay;
4. restores player control; and
5. removes the collected shard.

Other objects use `MemoryManager.knows_clue("2718")`; they do not depend on the shard scene. Memories remain known across a detention reload because the manager is an autoload.

### Add another memory shard

1. Instantiate `scenes/interactables/MemoryShard.tscn` in a level, or instantiate it from a level script.
2. Set a unique `memory_id`, plus `memory_title` and `transcript`.
3. Set `practical_clue` to a queryable clue string, or leave it empty.
4. If keeping content records in source control, add the corresponding record under `data/`.

No manager changes are needed.

## Guard setup

To add another guard:

1. Instantiate `scenes/npc/Guard.tscn`.
2. Place `Marker3D` patrol points in the level.
3. Either assign their paths to the guard's exported `patrol_points` array in the editor or call `set_patrol_nodes()` after instantiation.
4. Tune patrol speed, pursuit speed, view distance, FOV, and suspicion rate in the Inspector.
5. Connect `caught_player` to the level's checkpoint/failure handler.

The prototype moves guards directly between visible greybox points. A later production level can replace that movement layer with navigation without changing suspicion, perception, or catch signaling.

## Restricted-area setup

To add another restricted area:

1. Instantiate `scenes/interactables/RestrictedZone.tscn`.
2. Set its size by editing the box shape and debug mesh, or call `configure(size, multiplier, zone_type)`.
3. Set `suspicion_multiplier` and a descriptive `zone_type`.

The zone only reports enter/exit state to compatible player bodies. Guards read the player's highest active zone multiplier only after visually detecting the player, so merely entering an unseen restricted area does not raise suspicion.

## Doors, gates, and access keys

`NormalDoor`, `PrisonSlidingGate`, and `KeyPickup` use the same generic interaction methods as the other interactables. The Player script contains no door-specific logic. `AccessManager` stores string-based keys and permanently unlocked access IDs for the current application session.

Normal doors support swing or slide motion, configurable direction, optional keyed locks, and doorway occupancy checks. Prison gates use a sideways-sliding barred leaf and expose locked, unlock, open, and close prompts. Moving leaves keep collision disabled during transitions and refuse to close on the player.

Temporary pickups provide `cellblock_key`, `service_key`, and `medical_key`. The `security_key` and `lab_key` have no pickup yet. Run the automated interaction workflow with:

```text
Godot --headless --path . res://scenes/tests/AccessWorkflowValidation.tscn
```

## Main files

- `project.godot` — project settings, input map, autoloads, main scene.
- `scenes/levels/CellBlockPrototype.tscn` — runnable level shell.
- `scripts/levels/cell_block_prototype.gd` — Floor 3 gameplay spawns, patrol route, environment, and detention checkpoint.
- `scenes/levels/floors/` and `scripts/levels/floors/` — modular B2-through-roof layouts.
- `scripts/levels/greybox_factory.gd` — reusable primitive geometry, stairs, bridges, railings, signs, and collision.
- `scenes/player/Player.tscn` and `scripts/player/player.gd` — first-person controller and generic interaction ray.
- `scenes/npc/Guard.tscn`, `scenes/npc/GuardVisual.tscn`, and `scripts/ai/guard.gd` — separated human placeholder visual, patrol, sight, suspicion contribution, and alert pursuit.
- `scripts/systems/suspicion_system.gd` — global suspicion state machine and decay.
- `scripts/systems/memory_manager.gd` — collected-memory and clue registry.
- `scenes/interactables/MemoryShard.tscn` — reusable collectible memory.
- `scenes/interactables/KeypadLocker.tscn` — clue-gated locker payoff.
- `scenes/interactables/RestrictedZone.tscn` — reusable multiplier zone.
- `scenes/ui/HUD.tscn` and `scripts/ui/hud.gd` — prompts, suspicion, memory, and detention presentation.
