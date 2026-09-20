# Implemented prison campus

Run `project.godot` with F5. The main scene is `res://scenes/levels/campus/PrisonCampusPrototype.tscn`. The legacy CellBlockPrototype scene remains separately runnable; this pass does not fold its old gym/cafeteria/basements back into Cellhouse A.

## Buildings and access

| Building | Implemented floors and rooms |
| --- | --- |
| Cellhouse A | Three cell tiers, 15 ordinary cells per tier, guard quarter and sealed lift lobby in the same corner on each tier, open atrium and connected galleries. Parth starts on tier 3. |
| Cellhouse B | Two tiers, 12 individually keyed cells and two glass-front special rooms per tier, controlled wings, staff/support/interview rooms, two stairs and sealed lift area. |
| Food Services | 72-place dining hall with 12 supported table/bench sets, three serving stations, wash/tray return, cooking, prep, cold/dry storage and receiving. |
| Medical & Wellness | Six-bed ward, consultation/exam/treatment, medicine storage, staff room, gym, changing, ten showers, eight toilets and eight separated urinals. East door leads toward the pool/yard annex. |
| Security HQ | Ground: staff, equipment, evidence, processing and individual cell-key register. Upper: chief office, surveillance, control, briefing and servers. Two usable stairs and reserved lift. |
| Maintenance | Ground: workshop, tool issue/2718 locker, dirty-to-clean laundry, utilities, stores and waste. B1: service plant, distribution, pumps, spares and sealed future tunnel branches. |
| Administration | Public reception/waiting/visitation/WC and meeting room, physically separate prisoner booth aisle, holding/processing, records, interview and staff offices. |
| NIDRA beneath HQ | B2 laboratory, chemicals/hazard store, subject holding, decontamination, samples, records, two interrogation rooms and observation glazing. Enclosed stair connection through B1 to HQ; no public B1 exit. |

The playable compound is now a tighter 156 × 188 m footprint, reduced from the original 180 × 220 m concept (about 26% less ground area). All seven buildings, eight watchtowers, room programs, the central yard, service roads and required security circulation remain. Building setbacks are shorter, the pool annex sits directly beside Medical, and repeated 4–6 m interior circulation strips are narrowed to 3.2–4.8 m. Cells, furnished rooms, stairs, door clearances and Cellhouse A's deliberate atrium geometry were not scaled down. The original HTML atlas remains a design illustration, not the collision authority.

The outdoor addition contains a recessed 20×10 m, 2.4 m deep community pool with an open circulating deck, gazebo, security kiosk, sports/exercise/garden dressing and operable gates in the existing central-yard openings. The pool's inner and outer wire cages were removed; the campus perimeter remains secure. Supported stairs at both ends lead out without jumping. WASD swims, C dives, Space rises, and releasing the vertical controls floats the player back toward the surface. Camera submersion enables smooth water tint and distance fog; surfacing restores the previous environment. No drowning, combat, new NPCs or elevator movement were added.

## Time, lighting and weather

`CampusEnvironmentCycle` provides a configurable 24-hour clock (12 real minutes per day by default) with morning, day, evening and night phases. It continuously grades the procedural sky, sun and ambient light rather than swapping environments. At 18:30 the existing supported indoor fixtures and three designated watchtower beams switch on; they switch off at 07:00. All eight tower lenses still read as powered after dark, while only three towers own real beam lights to protect the Compatibility/Web budget.

Each new day rolls one of two weather modes. A normal previous day gives rain a 25% chance; a rainy previous day lowers the next roll to 10%. Rain uses one 650-particle camera-local volume and inexpensive distance fog. An upward clearance ray pauses the rain volume beneath roofs, so precipitation is not rendered throughout the whole campus or inside buildings. Pool submersion remains camera-local and restores the current campus environment when the player surfaces.

The minimap automatically switches from the outdoor overview to the occupied building/storey, including B1 and B2. Indoor room layouts come from the same floor-plan JSON as the architecture; live access markers are filtered to that floor. M still hides/shows the map. Ordinary doors have reusable two-sided painted leaves, handles, hinges, kick plates and nameplates. Lift doors and sealed service/vehicle shutters have their own distinct visual styles; existing key rules remain unchanged.

## Reusable architecture

- `data/campus/floor_plans.json`: exportable room/threshold data. Coordinates start at each building's north-west corner. X is east; JSON Y is Godot Z/south. Elevations are finished floor levels.
- `CampusBlueprintFloor.tscn`: independently configurable floor with shared boundary deduplication, collision-backed walls/slabs, intended openings, service hatches, signs and ceiling-mounted fixtures.
- `CampusInteriorAssembly.tscn`: associates floors with the seven existing shells and connects their shafts. Ground terrain is cut at the actual basement stairs instead of covering them with a global slab.
- `campus_plan_compactor.gd`: applies named, deterministic circulation-strip reductions to runtime plan copies. The source floor-plan JSON stays readable and reusable; room contents and door widths retain their authored dimensions.
- `CampusPrisonCell.tscn` and `CampusGuardElevatorCore.tscn`: reusable general-population cells and detailed guard/lift corner modules.
- `CampusStairFlight.tscn` and `CampusSwitchbackStair.tscn`: supported treads over smooth collision ramps, level landings, connected rails, configurable primary/secondary entrances. Parent floors omit the whole shaft footprint.
- `CampusTelescopicGate.tscn`: four lightweight sliding panels using the existing PrisonSlidingGate access/prompt/authorization/safety behavior. Surface tracks and short jamb returns keep pockets out of solid walls.
- `CampusRoomFurnisher.dress(...)`: deliberate room-local recipes using existing prop scenes plus ten new compound fixtures. See `scripts/levels/campus/furnishing/README.md` for placement/support rules.
- `CampusDetailProp.tscn`: configurable, visual-only books/clothing/cups, paperwork, food containers, wall utilities, security signage, monitor/radio/key-control, records/maps and workshop detail. It supplies semantic density without unique one-off meshes or extra light nodes.
- `CampusRecreationAnnex.tscn`, `WireMeshFence.tscn`, `CampusSecurityKiosk.tscn`: independently placeable outdoor modules.
- `CampusSessionContent.tscn`: mounts existing memory/keypad/key content without putting interaction logic in Player.
- `InstitutionalDoorVisual.tscn`: reusable hinged/lift/shutter cosmetics, separate from access, moving bodies and collision; shared paint/trim/hardware materials and per-leaf batching.
- `SwimmingPool.tscn`: independently placeable basin, supported exit stairs, water surface and grounded rules board. Hosts must remove terrain within its 20×10 m footprint; origin is deck level. `Player/Swimming` owns the optional water motor and camera-local presentation.
- `campus_environment_cycle.gd`: reusable clock/weather authority with exported timing, light cutoffs, weather chances and rain density. Indoor fixtures and tower visuals opt in through groups instead of coupling to building scripts.

Tables, beds, seating, cabinets, equipment and rails have visible legs, brackets, bases or wall connections. Ceiling fixtures attach to the actual slab underside; stair voids receive no suspended floor ceiling. Room furniture has floor-contact/bounds metadata and rejects obstructed doorway reservations. The visitation centre booth deliberately leaves seats out to preserve the entrance aisle.

Static furniture, structural geometry and stair visuals are combined by material at sensible room/module boundaries. Moving gates, collision shapes, actor animation, interaction roots and placement metadata are not merged together. Independent source scenes remain reusable; runtime batches are rebuilt from them.

## Existing gameplay and keys

Parth's starting cell door is unlocked. The ground-tier dayroom contains a supported temporary rack with `cellblock_key`, `service_key` and `medical_key`. Common dining, gym, clinical and yard routes remain explorable; service areas use the service key. Security HQ, segregation and NIDRA keep their existing deliberate authorization barriers.

HQ's ground-floor key register holds all 69 individual cell keys: 45 for A, 24 for B. No chief/master key, `security_key` or `lab_key` is spawned. Those restricted areas can be inspected using the development test/review scenes until later progression supplies access. Ordinary keys are not consumed and remain in the current session through reloads.

`memory_001` rests on a bracketed shelf in Parth's cell. Its original HUD sequence teaches `2718`, which opens the supported, hollow keypad cabinet in Maintenance's tool room. Keys do not bob in the air and cannot be collected twice.

## Development mode

Play Mode is the default: `blacksite/development/dev_mode=false` in `project.godot`. In that state the `DevModeManager` autoload is inert except for the deliberate Command+D authorization shortcut, the F8 menu action is ignored, no developer menu is instantiated, and normal access, suspicion, inventory and failure rules are unchanged. Command+D opens a focused authorization text box; entering `tez` enables Dev Mode during the running game and opens the menu immediately. **Exit Dev Mode** clears cheats and dev-granted inventory, restores temporarily overridden door/gate states, and returns to Play Mode. The choice is session-only. A testing run can still start in Dev Mode by changing the setting to `true`, or passing the `--dev-mode` user argument after Godot's `--` separator.

Dev Mode displays a permanent gold indicator and F8 opens a tabbed menu while releasing the mouse and pausing player control. Closing it restores the previous FPS mouse/control state. The menu provides searchable, named campus destinations for all Cellhouse A/B tiers, Food Services, Medical/gym/showers, both HQ floors, Maintenance/B1, Administration, yard, pool and B2 NIDRA areas. The markers are registered from authored room nodes rather than menu coordinates.

Player tools cover test health, standard/advanced vest state, suspicion reset, invulnerability, noclip free flight and return-to-normal. Infinite stamina is ready for a future stamina provider. Inventory tools show two firearm slots, the melee slot, equipment quantities, current keys/access cards and unlocked access. The DEV controls give/remove registered data definitions and clear firearm, melee, equipment, DEV-only or complete inventory scopes explicitly. World tools operate selected loaded doors/gates, restore authored poses, re-enter the nearest registered area or restart the scene.

`scenes/dev/DevTestHub.tscn` is a separate non-campus scene with reserved Character Gallery, AI/Suspicion and Interaction bays plus a transfer bay for the range. `scenes/dev/WeaponRange.tscn` is the dedicated permanent Weapons Test Range: it contains functional pistol, SMG and Carbine AR pickups, measured target lanes, reusable hit-zone dummies, enclosed stealth placeholders, range controls and return terminal. Sniper, melee, suppressor, noose and tranquilizer positions remain nonfunctional placeholders. Future systems register destinations, items, scenes and command callbacks through the APIs documented in `scripts/dev/README.md`; the menu renders those registrations automatically.

The range damage stations use reusable `HealthComponent`, `ArmorTypes` and `BodyHitZone` components. Human base health is 100; standard and advanced vests add 25 and 50 effective health without resistance or reduction. The DEV-only body-health probe selects fixed values with `[` / `]`, applies test damage to the aimed HEAD/TORSO/LOWER_BODY collider with `T`, and resets all targets with `Y` or the physical RESET TARGETS interaction. Its readout reports target, zone, requested damage, remaining health or DEAD; dead targets reject further damage until reset.

The reusable `ItemDefinition` / `InventoryComponent` layer is separate from movement, AI, Dev Mode and future item behavior. It defines FIREARM, MELEE, EQUIPMENT, KEY, ACCESS_CARD, MISSION_ITEM and inert future AMMO categories. Firearms fill the first of two slots without replacement, melee has one non-replacing slot, and other categories use unique or stackable quantity records with no general equipment cap. `InventoryManager` owns current-session player state, while `AccessManager` retains its existing key API as a compatibility view over KEY/ACCESS_CARD records so all authored gates continue to work.

The pistol is defined by `resources/weapons/pistol.tres` and executed by the reusable `FirearmComponent`; input/equip/drop orchestration is isolated in `PlayerWeaponController`, while first-person and world visuals are separate scenes. It is semi-auto with an 8-round magazine, 24 reserve, 0.5-second shot interval, 1.5-second reload and lower/torso/head damage of 30/70/120. Hitscan stops at the first world or hit-zone collision and reports confirmed dummy hits to the existing DEV readout. It is available only from the range rack or Dev Menu during Dev Mode, never as authored campus content.

## Validation run

Validated in Godot 4.7.2 Compatibility mode:

- `scenes/tests/CampusFoundationValidation.tscn`: isolated shells, eight towers, infrastructure and legacy-scene instantiation.
- `scenes/tests/CampusPhaseTwoValidation.tscn`: isolated Cellhouse A regression; explicitly disables the expanded interiors.
- `scenes/tests/CampusBuildingValidation.tscn`: ten new floor plans / 169 room zones, 157 physical access doors, 167 usable threshold paths and 579 furnishing assemblies. Closed doors contain; opened doors, rooms and approaches remain clear. Hatches, sealed lifts and ordinary stair transitions are intentionally handled separately.
- `scenes/tests/CampusCirculationValidation.tscn`: actual player movement on A's stairs/bypasses, 16 switchback entrance combinations and repeated shaft segments.
- `scenes/tests/CampusIntegratedCirculationValidation.tscn`: actual player ascent/descent through all seven switchbacks in the fully furnished campus, the complete B2-to-HQ-upper shaft, and both secondary Cellhouse B staff entrances.
- `scenes/tests/CampusGateTravelValidation.tscn`: all 125 remaining sliding gates at 25%, 50%, 75% and fully open; no neighboring solid intersects their sampled travel. The redundant pool crossing gate was removed when the annex moved beside Medical.
- `scenes/tests/CampusDoorsWaterMapValidation.tscn`: 90 ordinary doors at five swing poses and two-sided detail; all 13 floor-map contexts, live marker filtering and building entry/exit; actual player fall-in, float, dive, surface, both step exits and dry-land crouch/stand.
- `scenes/tests/CampusFeedbackVisualReview.tscn`: native-rendered door faces, building map, open pool deck, underwater and resurfaced views.
- `scenes/tests/CampusEnvironmentCycleValidation.tscn`: all four phases, day rollover, 25%/10% rain logic, outdoor/roof rain sheltering, HUD state and automatic indoor/searchlight switching.
- `scenes/tests/CampusEnvironmentVisualReview.tscn`: native morning, noon, evening, night, night-interior and rainy renders.
- `scenes/tests/DevModeValidation.tscn`: Play/Dev isolation, Command+D authorization and rejection, F8 and mouse behavior, named teleport transforms, health/vest/invulnerability/noclip restoration, individual/all/clear key tools, selected access operations, extension registration APIs and the external test hub.
- `scenes/tests/WeaponRangeValidation.tscn`: dev-only access, player spawn/movement/crouch, base/armor/current-health separation, 100/125/150 totals, aimed HEAD detection, requested damage cases, death lockout/reset, required labels, exact 5/15/30/60m target offsets, stealth placeholders, Web-conscious counts and return-to-hub registration.
- `scenes/tests/InventoryValidation.tscn`: two firearm slots and full rejection, single melee slot and rejection, equipment slot isolation, unique/stackable quantities, all seven range pickups, live Dev Menu summary, complete clearing and Play Mode cleanup.
- `scenes/tests/PistolValidation.tscn`: real rack pickup, complete low-poly handgun-part silhouette and Web mesh budget, responsive crosshair and hip/ADS spread, smooth RMB ADS/FOV/iron-sight transforms, recoverable hip/ADS recoil, idle/walk/sprint/crouch/ADS motion, slide cycling and empty lock, valid-shot-only muzzle flash, inert dry fire, separate magazine and exact 1.5-second reload presentation, all nine hit-zone outcomes, semi-auto cadence, drop/repick, range refill and Dev controls.
- `scenes/tests/DevModeVisualReview.tscn`: native tabbed-menu and empty test-hub renders.
- `scenes/tests/CampusDensityValidation.tscn`: all 45 numbered A cells retain sliding doors and six deterministic personal-item variants; requested HQ, maintenance, food, yard and utility detail classes are present; six clinical beds, 10 showers, eight toilets, eight urinals, 12 dining sets, 51 CCTV cameras and eight watchtowers remain.
- `scenes/levels/campus/zones/RecreationAnnexValidation.tscn`: open pool deck, remaining gates, Medical/yard path and roads.
- `scripts/levels/campus/furnishing/furnishing_validation.gd`: independent room recipes, required counts, floor contact and doorway reservations.
- `scenes/levels/campus/gameplay/CampusSessionContentValidation.tscn`: unique keys, duplicate prevention, existing memory/2718 workflow.
- `scenes/tests/CampusVisualReview.tscn`: native OpenGL screenshots of representative furnished rooms and annex, visually inspected. This is a developer camera tour, not a claim of human/manual playtesting.

Run scene tests with `godot --headless --path . res://scenes/tests/CampusBuildingValidation.tscn`. Run the independent furnishing script with `godot --headless --path . --script res://scripts/levels/campus/furnishing/furnishing_validation.gd`.

Measured assembled test scene after batching: 17,600 nodes, 5,798 visible mesh nodes and 436,798 triangles. It contains 19 bounded light nodes in the gameplay-enabled audit: 13 storey lights, three tower beams, the sun, and existing gameplay indicators. Automatic lights are shadow-free and disabled during daytime; visible room diffusers stay material-batched. The density pass contributes 87 reusable semantic-detail assemblies and the scene remains below the 25,000-node / 1,000,000-triangle regression ceilings. These are regression measurements, not a browser FPS guarantee. Web export uses Compatibility, shared primitive materials, one localized rain particle volume, one transparent water surface and a lightweight underwater overlay/fog (no refraction or extra render camera).

`export_presets.cfg` includes runtime JSON explicitly and excludes development documents/tests. A Web resource ZIP package was generated successfully, its floor-plan data verified, and the packaged main scene started headlessly. Full browser execution still requires installation of the matching Godot Web export templates; they are not installed on this host.

The host's sandboxed headless editor can emit macOS certificate/editor-settings write diagnostics. Native rendering and project-level validation are tracked separately from those host diagnostics.

## Short manual tour

1. F5: open Parth's sliding door; inspect the supported bed, toilet/basin partition, cupboard/chair and memory shelf. Collect the memory once.
2. Walk both A stairs up/down without jump or crouch; follow each gallery/bridge and enter a guard room/lift lobby. Confirm rails protect exposed edges without crossing walking paths.
3. Collect the three dayroom keys. Open/close yard and cafeteria gates; walk between tables, serving counters and kitchen equipment.
4. Visit medical/gym/showers; confirm the minimap zooms into Medical and returns to CAMPUS outside. Use the east exit to reach the open pool deck. Enter the water, swim with WASD, dive with C and rise with Space; check underwater tint/fog appears and clears. Walk up both end staircases without jumping and confirm dry-land crouch/stand works.
5. Enter Maintenance with the service key, open the 2718 cabinet, and walk down/up B1. The utility-room door beside the locker must stay clear.
6. Check visitor and prisoner booth aisles in Administration remain separated. Test a locked security gate: it must stay solid and report a missing key.
7. In development validation/review scenes, inspect both Cellhouse B tiers, the two glass-front rooms per tier, HQ key storage/control rooms and B2. Test gate closing while standing in its passage.
