# Blacksite developer mode

`DevModeManager` is an autoload but remains inert in Play Mode. Press Command+D
at any time to open the developer authorization box, enter `tez`, and press
Enter. Successful authorization enables Dev Mode and opens its menu immediately.
F8 then opens or closes the menu. Use **Exit Dev Mode** in the menu to clear
active cheats, dev-granted inventory, and temporary door/gate overrides before
restoring normal player control. The runtime choice lasts for the current
session only.

To start directly in Dev Mode, set `blacksite/development/dev_mode=true` in
`project.godot`, or launch a test run with the `--dev-mode` user argument.

Registration APIs keep future test content out of the menu implementation:

- `register_teleport_point(id, label, category, marker)`
- `register_test_item(id, label, give_callable, remove_callable)`
- `register_inventory_test_definition(item_definition)`
- `register_test_scene(id, label, scene_path)`
- `register_command(id, label, category, callable)`

Campus destinations are resolved by `CampusDevRegistry` from authored room
nodes. The external `DevTestHub.tscn` registers its own bays when loaded.
`WeaponRange.tscn` is a second dev-only scene with firing-distance,
damage-dummy, stealth-placeholder and control stations. The PISTOL rack is the
only functional weapon position; every other equipment or weapon label remains
a nonfunctional placeholder. Its in-world terminal returns to the Dev Test Hub.

The range now includes a reusable body-health foundation without any weapon
system. `HealthComponent` keeps base health, armor bonus and current health
separate; `BodyHitZone` exposes HEAD, TORSO and LOWER_BODY collision bodies for
future raycasts. In the range, `[` / `]` selects a test amount, `T` applies it
to the aimed mannequin zone, and `Y` resets all targets. The wall-mounted RESET
TARGETS control also works with the normal E interaction. The on-screen tool is
explicitly a DEV body-health probe, not a player weapon.

The range equipment tables also contain seven colored DEV-only inventory tokens:
three FIREARM definitions, two MELEE definitions, one unique EQUIPMENT definition
and one stackable EQUIPMENT definition. They exercise `InventoryComponent` only;
none can be equipped or used. The **Inventory / Access** tab shows FIREARM SLOT 1,
FIREARM SLOT 2, MELEE SLOT and equipment quantities, with give/remove and scoped
clear controls. Full and duplicate attempts report the production inventory result
messages rather than silently replacing a slot.

The pistol uses a data-driven `FirearmDefinition`, reusable `FirearmComponent`,
separate `PlayerWeaponController`, and separate primitive visual scenes. It is
semi-automatic, holds 8 rounds, starts with 24 reserve, fires at most once every
0.5 seconds, reloads in 1.5 seconds, and deals 30/70/120 to lower/torso/head.
Controls are 1/2 equip, left mouse fire, hold right mouse for smoothly transitioned
iron-sight aiming, R reload, H holster and G drop. Hip fire uses a centered
configurable crosshair; ADS hides it, tightens spread and narrows the camera FOV.
The controller layers subtle idle/walk/sprint/crouch motion and recoverable camera
recoil over the ADS transform. The pistol visual independently owns its cycling
slide, empty lock, separate magazine, brief emissive-only muzzle flash and timed
procedural reload. Range
hits are sent to the existing body-health readout. The range refill console and
the Dev Menu's GIVE/REMOVE/REFILL PISTOL controls are functional. No pistol is
authored into the campus.

Health, vest and stamina controls use capability checks. Until their production
systems exist, health/vest state is held as player metadata so the interface can
be exercised without adding combat logic. A future provider only needs to expose
`set_health`, `equip_vest`, or `set_infinite_stamina`; the menu does not change.
