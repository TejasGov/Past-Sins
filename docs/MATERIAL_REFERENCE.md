# Surface material reference

Named materials live in `materials/props/`. Keep functional finishes separate:
do not repurpose a generic palette slot to texture weapons, wet rooms or wood.
Resource names are stable; replace their normal PBR texture slots to retune them.

## Authored additions (2026-09-18)

| Material | Source | Placement / intent | Mapping |
| --- | --- | --- | --- |
| `tile_shower.tres` | [Tiles133A](https://ambientcg.com/view?id=Tiles133A) | Small pale ceramic grid: campus shower/toilet floors, shower banks, half-walls, urinal dividers | World; 0.7 repeats/m (authored scale) |
| `gym_rubber.tres` | [Rubber004](https://ambientcg.com/view?id=Rubber004) | Fine-grained institutional gym floor, not residential carpet | World; 1.3333 repeats/m, matching 75cm source |
| `court_concrete.tres` | [Concrete048](https://ambientcg.com/view?id=Concrete048) | Smooth maintained basketball slab, deliberately distinct from current generic concrete; track keeps its existing finish | World; 0.65 repeats/m (authored scale) |
| `gunmetal.tres` | [Metal032](https://ambientcg.com/view?id=Metal032) | Clean cool blued steel: pistol, SMG, carbine and sniper metal parts, both FP and world visuals | Local; 3 repeats/m; shared helper varies receiver/edge tint |
| `wood_furniture.tres` | [Wood059](https://ambientcg.com/view?id=Wood059) | Worn gray-brown wood: cell cupboards/wooden chairs, common tables, guard desk tops, workshop worktops | World; 1.25 repeats/m (authored scale) |
| `wood_ak_furniture.tres` | [Wood030](https://ambientcg.com/view?id=Wood030) | Warmer orange/red varnished AK-pattern carbine stock, grip and handguard; not general furniture | Local; 2 repeats/m; lower roughness/normal strength |

All six sets are ambientCG **1K-JPG** packages, licensed [CC0](https://docs.ambientcg.com/license/).
Only Color, NormalGL and Roughness are installed; gunmetal also includes Metalness.
No displacement, AO, DX-normal duplicates, ZIPs or preview renders ship in res://.
All new maps are 1024 x 1024; VRAM compression (`compress/mode=2`), mipmaps,
and OpenGL normals are checked in via the adjacent `.jpg.import` files. Normal
maps use `compress/normal_map=1`. No additional lights, transparency, probes,
post-processing or gameplay logic are needed for these materials.

The exact filenames and reproducible installer are in
`tools/install_ambientcg_surfaces.py`. It installs only known ZIP members and
refuses to silently overwrite changed maps. Downloads/ZIPs belong outside the
project. Prefer referencing these resources rather than making new equivalents.

## Existing authored slots (preserved)

These texture sets predate this reference list; their original source IDs were
not recorded locally. Do not infer IDs from appearance. Record verified sources
when they become available rather than duplicating the assets.

| Existing material(s) | Existing map folder | Role / reuse guidance |
| --- | --- | --- |
| `concrete.tres` | `textures/concrete/` | Generic structural concrete; not the maintained court finish |
| `painted_metal.tres`, `security_dark.tres` | `textures/metal/` | Environmental painted metal; not firearm blued steel |
| `dirty_off_white.tres` | `textures/plaster/` | Institutional painted/plaster surfaces |
| `stainless_steel.tres` | `textures/steel/` | Kitchen/clinical stainless equipment; not gunmetal |
| `shower_tile.tres` | `textures/tiles/` | Legacy tile slot; preserved, but active wet-room props now use `tile_shower` |
| `court_surface.tres` | `textures/asphalt/` | Existing track/court-style coating; track retained, basketball slab now uses `court_concrete` |
| `asphalt.tres` | `textures/road/` | Campus road finish |
| `yard_green.tres` | `textures/grass/` | Yard grass |
| `gravel.tres` | `textures/gravel/` | Gravel strips |
| `rusted_iron.tres`, `cell_bars.tres` | `textures/iron/` | Old prison/security iron, separate from maintained weapons |
| `chainlink_fence.tres` | `textures/fence/` | Fence maps including opacity; keep transparency restricted to this use |

Other palette slots retain the shared 256px procedural fallback described in
`SURFACE_MATERIALS.md`. Add a row here before introducing another finish.

## Validation and visual checks

Run `scenes/tests/AuthoredSurfaceValidation.tscn`,
`scenes/tests/MaterialSurfaceValidation.tscn`, and
`scenes/tests/FirearmArchitectureValidation.tscn` headless. The first checks
source/map/import settings, distinct court/wood maps, actual campus assignment,
shared firearm surface usage, and preserved factory collision.

Run `scenes/tests/AuthoredSurfaceReview.tscn` with a real Compatibility display
for captures in `/tmp/blacksite-surface-*.png` (not headless).
Visual review: shower grid and gym under both day/night lighting; court slab
versus adjacent ground with markings still readable; worn cell chair/cupboard;
all firearm receivers and carbine wood in hip/ADS. Use the existing visual-review
scenes and Web export to verify Compatibility rendering.
