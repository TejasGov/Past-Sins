# Blacksite: Ghost Exit — campus floor plan

Status: original authoring specification, 9 September 2026. The running campus now applies a documented runtime compaction pass; this file and its atlas intentionally preserve the pre-compaction room coordinates for design reference.

Open [the floor-plan atlas](CampusFloorPlanAtlas.html) for thirteen scaled floor sheets, room dimensions and explicit door connections. [The coordinate data](campus_floor_plans.json) is the source for those sheets. Both use metres from each building's north-west corner; north is negative Godot Z. Bay dimensions are measured to partition centerlines. Clear room dimensions must subtract wall thickness and door frames.

## Campus organization

The initial design used a 180 × 220 m compound. The implemented version is 156 × 188 m with shorter setbacks and narrower repeated corridor bands, while retaining all seven buildings, eight watchtowers and the same room program. The yard remains the outdoor center of daily prisoner movement. Deliveries, ambulance access, refuse collection and staff arrivals use the outer roads. Building thresholds separate those routes from prisoner circulation.

| Building | Existing center, Godot X/Z | Existing footprint | Planned occupied levels | Main role |
| --- | --- | --- | --- | --- |
| Cellhouse A | −57 / 0 | 44 × 34 m | Floors 1, 2, 3 at Y=0,4,8 | Ordinary cells, Parth's start, galleries and dayroom |
| Cellhouse B | 58 / 0 | 36 × 46 m | Ground and upper at Y=0,4 | Separate high-security housing and special rooms |
| Food Services | −55 / −75 | 38 × 34 m | Ground | Dining, cooking, food storage and dishwashing |
| Medical & Wellness | −55 / 75 | 38 × 34 m | Ground | Infirmary, treatment, gym and expanded hygiene facilities |
| Security HQ | 55 / −75 | 36 × 34 m | Ground, upper; separate B2 at Y=−8 | Operations, surveillance, chief, keys and concealed NIDRA facility |
| Maintenance | 55 / 75 | 36 × 34 m | Ground; separate B1 at Y=−4 | Repair, laundry, utilities and service tunnels |
| Administration & Intake | 0 / 82 | 40 × 24 m | Ground | Public reception, visitation, admission and administration |

Most buildings deliberately have one useful floor. Food Services and Maintenance retain their 5.5 m shells; Medical and Administration retain their 6 m shells. Cellhouse B's 9 m shell accommodates two levels. Security HQ needs a proposed roof increase from 7 to 8.6 m before its two-level fit-out. Cellhouse A remains three storeys inside its existing 13 m shell.

### Outdoor facilities and paths

- Preserve the central yard footprint at X=−28…28, Z=−30…30: basketball on the west, exercise on the north-east, grass/flowers/shrubs on the south-east, and a continuous perimeter walking track.
- Reserve a separate fenced pool annex at X=−33…−6, Z=51…68. A 20 × 10 m pool centered within the 27 × 17 m enclosure leaves approximately 3.5 m of deck around it. The annex does not overlap the south road, Medical, Administration or the central avenue.
- Connect the annex's west gate to Medical's east gym/shower lobby with a continuous path along Medical's east side. Return traffic passes through changing/shower space before entering the wet area. Reserve a separate controlled gate for staff/maintenance.
- Connect the recreation annex to the main yard through a marked, gated pedestrian crossing of the south cross road. Do not conceal a vehicle crossing inside uninterrupted pedestrian paving.
- Reserve a 6 × 6 m officer gazebo and a 4 × 4 m security post in the north part of the Medical–pool approach, away from the road crossing, door swings and deck circulation. Exact prop placement follows the path survey.
- Retain all eight watchtowers. The yard towers observe outdoor activity; corner towers cover the perimeter; the loading tower observes deliveries; the eastern sector tower observes Cellhouse B's separate fence.
- Extend secure fencing around the pool and its approach. Every gate requires an actual gate leaf, collision and a clear landing. Gate posts alone do not count as containment.

## 1. Cellhouse A — three floors of ordinary housing

Each floor contains seven north cells, eight south cells and the same north-east guard/elevator corner: 15 cells per floor, 45 total. Parth remains in Floor 3 north cell 03. Preserve every existing cell ID that remains in the building.

The outer cell rows face broad north and south galleries. A central bridge connects the galleries on both upper floors. The dayroom occupies the ground area under the two atrium voids. No upper floor slab spans the central void.

Vertical travel uses Stair A on the west between Floors 1–2 and Stair B on the east between Floors 2–3. Each has an outside bypass strip so the top floor walkway does not force players onto stairs leading down. Rails follow the boundary between the floor and the void or stair opening; they never cross an ordinary corner route. The drawings show where each stair joins its floor, not a door placed across a tread.

The guard/elevator corner uses the one former cell bay on every tier. It contains a 2.6 × 5.7 m guard room beside a 2.4 × 3.2 m lift shaft and 2.4 × 2.5 m waiting lobby. Keep the lift position identical across all tiers. Landing doors remain sealed until the elevator phase. When that phase starts, cut a continuous shaft through slabs; stacked closed rooms are not a finished elevator shaft.

Guard rooms retain a detailed supported desk, chair, radio, monitor, locker and wall information. Ordinary cells retain the wall-mounted bed, toilet and basin on one side behind a low partition, cupboard and empty wooden chair. Keep a clear route from the cell entrance to the bed and sanitary corner. Every cell has its own sliding barred gate; Parth's remains initially unlocked.

The west ground entrance feeds the outside bypass and north gallery. It must not require passage beneath a low portion of Stair A. The east exit continues to the central yard.

## 2. Cellhouse B — high-security compound

Two occupied floors repeat a controlled central spine, two gated residential wings and opposing stair cores. Each floor has twelve secure cells, in two banks of six, plus two special rooms with see-through security doors. The proposed 6.5 × 3.25 m secure-cell bays are larger than ordinary cells; support rooms use the remaining bank depth.

The west approach enters a checkpoint lobby before the central spine. The existing north entrance is a transport sally port, with a holding/checking zone inside the north end of the spine. Two independent gates separate each residential wing from the shared circulation. Wing duty points, linen/cleaning rooms and consultation rooms open into their own wing corridors.

Special rooms occupy the north-east quadrant, each accessed individually from the staff cross corridor. Use framed security glazing, sealed wall connections and full-height collision. The south-west quadrant contains the second stair, lift lobby and private interview room. Stairs serve both levels; the lift stays nonfunctional until its movement phase.

Maintain the existing dedicated outer fence and the clear strip between fence and building. The north transport gate and west pedestrian gate must align through both layers. Patrol routes for future staffing can loop within each wing and return to its duty point without entering cells or stairs.

## 3. Food Services — recognizable working dining hall

The south entrance opens directly into one large 27 × 15.5 m dining room. Target twelve six-seat prison table/bench assemblies, arranged in three rows: 72 seats. Preserve a 2.4 m main lane from entrance to serving queue and approximately 1.2 m between furniture groups. Use an overflow queue position inside the hall, not across the entrance.

The east side contains three west-facing serving windows: Serving 1, Serving 2 and Dietary/Medical. The counter/hatch edge is a fixed barrier. Food trays, water, condiment counter, clocks, menu boards and bins sit in designated wall pockets.

A four-metre service corridor divides dining from the north production rooms. West receiving links to dry storage and chilled storage, then preparation, the cooking line and serving. The west loading opening moves one metre north so its full width fits the corridor.

Tray return and dishwashing occupy the south-east corner. Diners deposit trays through a hatch; staff move trays from dirty landing through wash/dry storage inside the service area. Clean food circulation and dirty return do not share a dining aisle. The service corridor door from dining is controlled; the cafeteria is never a shortcut through the kitchen.

## 4. Medical & Wellness — clinic separate from recreation

The west half is clinical. A north/south controlled spine connects the main north reception point with medical and gym lobbies. The west ambulance entrance aligns with the four-metre clinical cross corridor. The east entrance aligns with the gym/shower lobby; both side openings shift one metre north to fit these corridors.

The clinic includes a six-bed infirmary, examination/triage room, consultation room, treatment/isolation room, secured medicine storage and medical staff/records area. Clinical carts have parking positions outside the circulation lane. Medicine storage uses medical access and locked cabinets; treatment furniture does not block the route for a bed or trolley.

The north-east gym is one 16.5 × 13.5 m room. Place weight stations along the walls and reserve a center exercise lane; keep the heavy bag swing area separate from doors. The south-east zone contains changing lockers, ten showers, eight toilets and eight urinals. Urinals receive divider panels; toilets use enclosed cubicles. Include an enlarged toilet cubicle within the count and keep the center circulation clear.

Wet-room fixture arrays are a follow-on detailed layout within these reserved rooms. Verify the 8+8+10 fixture counts with full-size partitions, plumbing and circulation before adding small props. The east lobby leads to the outdoor pool/yard path without taking recreation users through patient treatment areas.

## 5. Security HQ — operations, command and concealed research

Ground contains screening/interview space, briefing/staff ready room, secure equipment storage, evidence intake and the dedicated cell-key room. Put wall cabinets, evidence shelves and safes inside those rooms, not in the secure corridor. Reserve equipment/armory space architecturally; no combat systems are introduced.

The upper floor contains the police chief's office, surveillance, control/radio, incident planning and server/archive rooms. Separate surveillance from the radio/control room so it reads as a staffed department. Chief and staff offices connect to the ordinary staff corridor; sensitive storage requires its own secure threshold.

The individual cell keys previously assigned to the legacy Floor 4 storage room move to the ground-floor secure key room here. Retain key IDs and cabinet labels. The future police chief retains the master cell key; neither security_key nor lab_key becomes a starter pickup.

The two stair cores occupy identical positions on both levels. The south-east restricted lift corner also aligns with B2. All stairs terminate at actual landings before a door/gate. Increase the HQ shell to 8.6 m before building the upper floor, then realign the existing command windows and upper-floor markers.

### B2 — Project NIDRA beneath HQ

Subject handling occupies the west side; the clean laboratory and chemical work occupy the east. A controlled transfer spine connects them. A lift arrival checkpoint leads through gowning/decontamination into the laboratory corridor.

Include subject hold/preparation, neural-response laboratory, chemical research, hazardous storage, sample cold store, two separate interrogation rooms, staff observation/recording and subject archive. Observation has fixed windows into both interrogation rooms, with a staff-only entrance from the spine. The windows do not become traversal gaps.

The north stair provides a reserved restricted route to HQ ground through an enclosed B1 segment; B1 is not a public stop. The south-east elevator follows the same rule. Build continuous shaft geometry and ceiling openings when activating vertical access. Keep all unfinished entrances sealed.

Environmental storytelling uses equipment, restraints and understated labels. No new memory shards or story progression are scheduled by this plan.

## 6. Maintenance — workshop, laundry and infrastructure

The north door opens onto a central service spine. Workshop/repair is north-west; soiled laundry/washing and drying/folding are north-east. A controlled clean transfer connects laundry stages. Tool issue/parts, plant utilities, bulk/janitor storage and waste/cart washing occupy the south half.

The south door leads to the service/waste yard. Supplies and refuse use carts with a clear four-metre transfer corridor. The transformer stays in its existing exterior east enclosure. Small tool-rack props and CCTV mounts must remain outside circulation and door-opening volumes.

Reserve the existing memory-related maintenance locker/keypad for the tool-issue room when that gameplay content migrates. Preserve its ID, clue and unlock behavior.

### B1 — service hub

A dedicated stair and gated landing connect Maintenance ground to the B1 service hub. The hub contains heat/water plant, electrical distribution, service spares, drainage/sump and ventilation utilities.

Reserve a north tunnel toward HQ and a west utility branch toward Medical/Food Services. Keep both sealed until destination entries, terrain/slab cutouts and a continuous traversable route exist. Survey their complete routes around building foundations before generating geometry. A tunnel anchor is not a usable connection.

## 7. Administration & Intake — public and prisoner routes

The south portico serves public reception, visitor waiting, public toilets and private visitor/legal meetings. Prison intake enters north through the secure spine into search/property, changing and holding/transfer. Staff records and admissions interviews connect through the east staff corridor.

Visitation occupies the west-middle block. Build it as a reusable assembly with two separate aisles: visitors enter from waiting on the south; escorted prisoners enter from holding on the north. Fixed screens/booths divide those sides. There is no ordinary door through the screen and no visitor path into the intake spine.

Administration/warden office, meeting space and staff rest/WCs occupy the south-east side. The administrative office is separate from the police chief's security command office. The controlled partition between public and secure spines remains closed to ordinary visitor circulation.

## Shared construction rules

1. Derive wall runs, doorway openings, slabs and railing edges from the same room/void boundaries. Do not maintain separate hand-entered coordinates for what should be the same edge.
2. Use 0.18–0.22 m ordinary partitions and thicker 0.25–0.35 m secure dividers; subtract them when checking the clear width inside each bay. Keep the existing exterior shell thickness.
3. Target 1.2 m clear ordinary room doors, 1.4–1.8 m for carts/patients, and 2–3 m for main gates. Existing ordinary cells keep 1.35 m openings and their fitted gate. Resolve the compact guard-quarter entrance separately before fitting furniture.
4. Reserve at least 3 m depth between a secure gate and the adjacent stair landing. Door swings and gate travel pockets must fit inside this reservation.
5. A stair is a three-dimensional reserved volume: tread/ramp surface, player standing envelope, headroom, top/bottom landings, bypass and rails. Cut every intersecting slab before furniture placement. Test the complete path up and down with the actual player controller, including the final ramp-to-floor transition.
6. Every exposed floor edge needs a connected railing. An outside bypass overlooking descending stairs needs its own level guardrail; a lower sloped handrail does not protect people on the upper floor.
7. Repeated occupied rooms receive full-height partitions or a deliberately defined open threshold. Only planned atria are voids. Unallocated shell-edge strips are sealed wall/service space, not walkable shortcuts.
8. Keep full standing clearance along corridors. Minimum design target is 2.4 m clear above stair travel and 2.7 m for ordinary room ceilings. Verify with geometry after beams, fixtures and ducts are fitted.
9. Fit ceilings and visible fixture supports together. No hanging light floats below an absent slab. Reuse simple materials and unshadowed lighting; use coarse collision only within visible furniture outlines.
10. Preserve string access IDs and generic interactables. Fit normal doors to room openings, sliding gates to controlled thresholds, and permanently sealed placeholders to unfinished lifts/tunnels.

## Build sequence and reusable content

1. Establish the building blueprint format from this coordinate schedule: named rooms, shared wall boundaries, explicit openings, floor elevations, stair/shaft voids and access policy. Keep each building and floor independently placeable.
2. Finish the Cellhouse A circulation regression pass first. Verify every point of both stairs, all bypasses, cell exits and elevator/guard-room approaches before another furnishing pass.
3. Fit Food Services as the first complete single-floor slice. Its dining/service boundaries provide a clear test of the room and opening system.
4. Fit Medical & Wellness, resolve its wet-room fixture arrays, then connect the planned outdoor pool annex through the actual east doorway.
5. Fit Maintenance ground; migrate its existing locker content after checking the dependency on memory content. Build B1 only after the surface floor is validated.
6. Fit Administration and its dual-access visitation assembly.
7. Fit Security HQ after its height correction; relocate key storage here. Fit Cellhouse B behind its existing perimeter access gates.
8. Build NIDRA B2 and continuous underground access last. Elevator movement remains a separate feature task.

Reusable modules should include the existing furnished cell and guard corner plus StairwellCore, ElevatorLobby, RoomBoundary, VisitationBooths, ShowerBank, ToiletBank, UrinalBank, ServingLine and ClinicalBedBay. These are proposed module names, not claims that those scenes already exist. Reuse the current prop and interactable libraries within them.

Implement one building slice at a time, with a temporary inspection camera and actual walking route. A passing room count or a few capsule samples cannot establish full traversal or visual quality. Treat the atlas as the intended layout; validate generated geometry against it before declaring a slice complete.

## Verification performed for this planning artifact

The coordinate audit checks all thirteen sheets for room bounds, overlapping rectangles, duplicate IDs, openings on shared boundaries, opening width, and reachable room-access graphs. It does not run the Godot game or prove that future instantiated wall, stair, door and furniture collisions are correct.

Existing source used: `scripts/levels/prison_campus_prototype.gd`, the seven `scripts/levels/campus/buildings/*.gd` shell builders, `central_yard_grounds.gd`, `roads_and_paths.gd`, and the Cellhouse A interior modules.
