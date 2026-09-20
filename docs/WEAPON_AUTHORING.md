# Firearm authoring contract

New firearms plug into the existing systems through data and standardized visual
anchors. They must not add weapon-specific branches to `PlayerWeaponController`,
`FirearmComponent`, inventory, or the HUD.

## Required assets

1. Create one `FirearmDefinition` resource under `res://resources/weapons/`.
2. Create a first-person visual scene and a world visual scene.
3. The visual script must extend `FirearmVisualBase`.
4. Use the shared primitive helpers for Web-friendly procedural models, or place
   an imported optimized model beneath the visual root.

First-person visuals provide these markers:

- `ADSAnchor`
- `RearSightAimPoint`
- `FrontSightAimPoint`
- `HipAnchor`
- `MuzzlePoint`
- `MuzzleFlashPoint`
- `MagazineSocket`

World visuals provide:

- `InteractionAnchor`
- `MuzzlePoint`
- `MagazineSocket`

The front sight and muzzle face local `-Z` and sit forward of the rear sight.
Model construction, hands, slide/bolt movement, and reload choreography remain in
the weapon visual. Ammo, firing state, hitscan, HUD, inventory, ADS transitions,
recoil, sway, and input remain shared.

Choose `SEMI_AUTO`, `BURST`, `AUTOMATIC`, or `SINGLE_SHOT` in the definition. Automatic weapons
use `shot_interval` as their cadence and fire only while the shared fire action is
held; do not add weapon-specific input polling. Dropping uses the controller's
`unequip_and_drop_current()` API, which preserves ammo and frees the occupied slot.

Scoped weapons opt into the shared path with `ads_fov_override`,
`ads_motion_multiplier_override`, and `scope_overlay_scene`. A scoped visual may
override `set_ads_blend()` when its physical optic housing should disappear behind
the full-screen optical picture. Definitions with an
`individual_round_reload_time` also gain the shared Shift+R one-round load; the
runtime guarantees one ammo transfer per completed operation.
`future_suppressor_compatible` is metadata only: it reserves attachment support
without adding suppression behavior. It is currently true only for Carbine and
Sniper Rifle.

## Presentation API

Override only the callbacks a weapon needs:

- `play_fire_feedback(rounds_remaining)`
- `set_slide_locked(locked)`
- `play_reload(duration, was_empty)`
- `play_individual_round_load(duration)`
- `set_ads_blend(blend)`
- `finish_reload(rounds_loaded)`
- `cancel_weapon_animation()`

The base class supplies safe no-op implementations, anchor lookup, sight metrics,
materials, boxes, cylinders, tapered cylinders, and low-poly capsules.

## Required validation

Run `FirearmArchitectureValidation.tscn` after adding or editing any firearm. It
scans every definition automatically and rejects missing scenes, duplicate IDs,
incorrect visual base classes, missing anchors, and reversed sight/muzzle order.
Then run the weapon-specific behavior test and visually inspect hip, ADS, fire,
empty, and reload poses in the Weapons Test Range.

## Melee authoring contract

Melee weapons use the parallel `MeleeDefinition`, `MeleeComponent`,
`PlayerMeleeController`, `MeleePickup`, and `MeleeVisualBase` path. They do not
branch firearm state or player movement. A definition owns reach, attack/impact
timing, cooldown, lethal-human behavior, fallback damage for resistant targets,
camera feedback, visibility class, and its two visual scenes.

First-person melee visuals provide `GripAnchor`, `ImpactPoint`, and `HipAnchor`;
world visuals provide `InteractionAnchor` and `GripAnchor`. Override
`play_attack()`, `play_impact()`, and `cancel_melee_animation()` for presentation.
Hit resolution remains in `MeleeComponent`: a single camera ray stops at the
first solid collision, resolves once per swing, and delegates human damage to
`BodyHitZone`/`HealthComponent`. Normal humans opt into fatal melee through
`lethal_melee_vulnerable`; future special targets can disable it and receive the
definition's fallback damage instead.

Run `MeleeWeaponValidation.tscn` after changing a melee definition or visual. It
checks the one-slot inventory rule, input/controller boundaries, model parts,
timing, reach, wall occlusion, armor-independent lethality, immunity fallback,
dropping, Dev APIs, and the explicit lethal-melee range readout.

`SlingshotDefinition` is the ranged improvised specialization of the same single
slot. It remains completely separate from firearm hitscan. Its component owns a
capped hold/release draw, consumes one selected AMMO item on release, and launches
a lightweight gravity projectile. The projectile delegates ordinary 25/45/120
damage to body hit zones, emits `WorldNoiseSystem.noise_emitted` with distinct
surface intensity, optionally recovers normal nails, never recovers toxin nails,
and calls the narrow breakable-impact capability when present.

The fictional toxin is a reusable `ToxinStatusComponent`, not slingshot-specific
target logic. Inmate test targets transition rapidly; guard test targets expose
`can_use_security_actions() == false` throughout their configurable three-second
transition. `PlayerMeleeController` exposes `IMPROVISED_WEAPON`, held/aimed
suspicion floors, and a witnessed-person-hit event. Guard AI is intentionally
unchanged until its weapon-awareness integration exists. Run
`SlingshotValidation.tscn` for projectile, charge, damage, noise, recovery, toxin,
breakable-light, inventory and regression coverage.
