# Campus room furnishing

`CampusRoomFurnisher.dress(room_root, plan_id, room_data, doorways)` populates a
room after it enters the SceneTree. The room root is the room's centre in X/Z
and its finished floor is Y=0. Room data provides `id`, `label`, `type`, `w`, `d`,
and optional `wall_thickness` (default 0.22 metres). Each doorway provides a
room-local `position: Vector3`, `width`, `axis` (`x` or `z`) and optional `kind`.
Kinds `hatch` and `window` are not pedestrian routes. Rooms classified as stair,
lift or void receive no furniture. Selected corridors receive only wall-mounted
wayfinding, CCTV and utilities; their centre circulation strips stay empty.

Recipes use the existing independently placeable prop scenes. New independently
placeable scenes are under `scenes/levels/campus/furnishing`: ShowerBank,
ToiletBank, UrinalBank, ClinicalBedBay, ServingLine, VisitationBooths,
SecureCellFurniture, LaundryMachine, PlantSkid and ServerCabinet. These use the
shared `CampusFurnishingFixture` builder; each exposes its own fixture kind,
count, bay width and label. Wall banks use a local Z=0 mounting plane and project
toward positive Z. SecureCellFurniture is a centred 6.5 by 3.25 metre bay with
entrance at positive X (rotate 180 degrees for the opposing bank).

Specific recipes include 12 supported cafeteria table/bench sets, a 3-bay
serving counter, six clinical bed bays, ten showers, eight toilet cubicles
(including a larger end cubicle), eight divided urinals, gym equipment,
industrial kitchen/food stores, office/control furniture, laundry/plant
equipment and restrained NIDRA laboratory dressing. The visitation assembly
physically separates its two aisles with fixed glazing, counter and end returns;
its central booth remains without seats to clear door swings and allow approach.

Small semantic objects use the independently placeable
`scenes/props/common/CampusDetailProp.tscn`. Its configurable variants cover
books, folded clothing, cups, paperwork, cleaning supplies, electrical boxes,
utility pipes, security/fence signs, monitor walls, radios, controlled-key
cabinets, incident boards, maps, tool boards, mechanical parts, breaker panels
and supported food containers. Screen surfaces use low-energy emission; none of
these detail assemblies creates a light or gameplay process loop.

Props are not scattered. Placement rejects room-boundary, other-furniture and
door-approach conflicts; optional rejected placements are recorded on
`Furnishings.clearance_omissions`. This may omit a secondary clock or shelf in
a compact room. Required-count assemblies have explicit measured layouts.
Stair and lift volumes stay outside these recipes. This component does not
provide navigation meshes, gates, walls, elevators or new gameplay.

Static furniture visual meshes merge by material within each room through
`campus_furniture_batcher.gd`. Per-prop roots, collision and support/audit metadata
remain. Camera meshes retain their original ownership because the camera API
keeps live mesh references. Repeated props therefore remain independently
reusable even though an assembled room has a smaller render footprint.

Every placed prop reports `support_type`, `furniture_bounds`, its source scene,
and group `campus_placed_furniture`. Room geometry has `campus_furnished_rooms`;
counts are separately tagged for dining sets, clinical beds and sanitary fixtures.
Wall fixtures adapt their actual rear bounds to the wall mounting plane. Small
legacy gaps in cafeteria frames, monitor stands, workbench pegboards and cart
castors are filled on the instantiated copy. Tabletop objects are children at
the measured support surface elevation. Large crates use the top shelf so their
height does not intersect the intermediate shelving.

Validation: run Godot with `--headless --path . --script
res://scripts/levels/campus/furnishing/furnishing_validation.gd`. This verifies
all 153 furnishable room/corridor recipes, required equipment counts, visible
floor contact, room bounds and furniture collision against every doorway
approach. `CampusDensityValidation.tscn` separately checks semantic coverage,
cell variation, CCTV/tower counts and required room equipment. These do not
replace a rendered visual review or actual player traversal tests.

## Existing content migration

`CampusSessionContent.tscn` belongs directly under the campus after
`CampusInteriors`. It defers its idempotent build until assembly is complete.
The scene adds a supported memory shelf in Parth's original cell, the original
2718 keypad content in Maintenance's tool room, a supported Floor 1 starter-key
rack, and wall-mounted individual cell key racks in HQ's ground-floor key room.
It enumerates live cell IDs: 45 Cellhouse A keys and 24 Cellhouse B keys. It does
not grant or place the future chief's master key, security key or lab key.

Reusable CampusMountedKey and CampusRestingMemory inherit the original generic
interactables; their only animation difference is resting on real supports.
CampusKeypadLocker inherits the original clue/prompt behaviour and uses a hollow
collision-backed body with its door opening outward. Session validation is
`res://scenes/levels/campus/gameplay/CampusSessionContentValidation.tscn`; run it
as a scene so Godot initializes the existing autoload managers first.
