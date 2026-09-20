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
damage-dummy, stealth-placeholder and control stations. The PISTOL, SMG,
CARBINE AR and SNIPER RIFLE rack positions are functional data-driven firearm pickups.
KITCHEN KNIFE and IMPROVISED SLINGSHOT are functional data-driven improvised-slot pickups.
MONOCULAR is a functional unique equipment pickup with an isolated 100 m observation
annex; the other unimplemented equipment labels remain placeholders. Its in-world
terminal returns to the Dev Test Hub.

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
Controls are 1/2 firearm equip, 3 melee equip, left mouse fire/attack, hold right mouse for smoothly transitioned
iron-sight aiming, R reload, H holster and G drop. Hip fire uses a centered
configurable crosshair; ADS hides it, tightens spread and narrows the camera FOV.
The controller layers subtle idle/walk/sprint/crouch motion and recoverable camera
recoil over the ADS transform. The pistol visual independently owns its cycling
slide, empty lock, separate magazine, brief emissive-only muzzle flash and timed
procedural reload. Range
hits are sent to the existing body-health readout. The range refill console and
the Dev Menu's GIVE/REMOVE/REFILL PISTOL controls are functional. No pistol is
authored into the campus.

The SMG and Carbine AR use the same firearm runtime and visual contract. Both use
trigger-held automatic fire with cadence enforced by their definitions: the SMG
runs at 750 RPM, holds 25 rounds and deals 30/65/140 damage; the steadier AK-pattern
Carbine runs at 600 RPM, holds 30 rounds, deals 35/80/150, and uses dark walnut
furniture with a separate curved magazine. Releasing LMB immediately stops fire.
Both have their own data-driven ADS transforms, spread and recoil values, reload
presentations, world pickups and GIVE/REMOVE/REFILL Dev Menu controls. The Sniper
Rifle adds a reusable scoped-ADS overlay, low-sway 30-degree optic view, five-round
bolt-action cadence, 2.5-second magazine reload and optional 1.5-second one-round
load (Shift+R). These systems remain definition-driven for future precision
weapons. None implements suppressor behavior, and none is authored into the prison
campus.

Press G while a firearm is equipped to unequip it into a world pickup directly
in front of the player's feet. This preserves its magazine/reserve ammo and frees
that firearm slot for another pickup. H remains a non-destructive holster action.

The Kitchen Knife and Improvised Slingshot share the existing single improvised/
melee inventory slot. The knife retains its lethal short-range human hit behavior.
The slingshot uses hold/release draw strength, a real gravity-driven nail projectile,
normal hit-zone damage, fictional toxin status, surface noise events, recoverable
normal ammunition, and a dedicated aiming dot. Both have world pickups,
first-person models, Dev controls, G drop and H holster. Neither is placed in the
prison campus.

The Monocular uses equipment inventory without consuming firearm or melee slots.
Press 4 to select/stow it, hold RMB to view, and release RMB to lower it. While
raised, each mouse-wheel step moves between the clamped 1x, 3x, 6x and 8x
states. Its lightweight circular
overlay owns camera FOV while active, blocks firearm/melee/slingshot use, cancels
weapon ADS, and restores the previously displayed weapon after lowering. Walking
and crouching remain available, while sprinting lowers it automatically. It is
available only from the Dev Menu and Weapons Test Range for now.

Proper and Makeshift Suppressors use the same equipment inventory and shared
firearm attachment contract. X attaches the compatible owned suppressor to the
equipped firearm or detaches the current one. Proper Suppressors fit Carbine AR /
Sniper Rifle, reduce the configurable weapon-noise radius to 30%, use a subtle
muzzle flash and are reusable. Makeshift Suppressors fit Pistol / SMG, reduce
noise to 46%, retain more flash, and survive four fired magazine cycles. A cycle
is charged only after at least one suppressed shot and cannot be reset by
detach/reattach. Switching and dropping preserve attachment and durability; a
dropped suppressed firearm temporarily owns the suppressor so inventory cannot
duplicate it. The range includes both pickups plus measured 10/25/50/100m sound
listener markers. No suppressor is placed in the prison campus and no crafting
or real-world construction information is included.

Health, vest and stamina controls use capability checks. Until their production
systems exist, health/vest state is held as player metadata so the interface can
be exercised without adding combat logic. A future provider only needs to expose
`set_health`, `equip_vest`, or `set_infinite_stamina`; the menu does not change.
