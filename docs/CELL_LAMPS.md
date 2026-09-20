# Cell lamps

Every current campus cell owns `scenes/props/prison/CellLamp.tscn`:
45 in Cellhouse A (including Parth) and 24 in Cellhouse B.

Look at the horizontal wall tube near the entrance and press E within the
normal interaction distance. The HUD shows Turn On Lamp / Turn Off Lamp.
The clock supplies the initial day/night state. Manual switching overrides
the clock until the scene restarts. Lights do not affect progression or keys.

The reusable StaticBody3D uses the normal interaction API. Its origin mounts
flush to a wall face, with local +Z facing into the room. The tube is horizontal,
at 2.05 m in the cells. Color, energy, range and render layer are configurable.

The room illumination comes from a bounded pool of four nearby shadowed
OmniLight3Ds, positioned at their source fixtures. Distant fixtures keep their
correct emission state without each owning a permanent real-time light.
Cell walls cast shadows to prevent light passing through adjoining rooms.
Batching explicitly preserves live lamp nodes and their mutable materials.
The existing Compatibility screen-glow pass runs before the HUD.

Validation: run `scenes/tests/CellLampValidation.tscn` headless for checks of
all 69 fixtures, in-cell reachability, wall backing, actual E events through
Parth's Player, HUD prompts, source illumination and clock override behavior.
Run the same scene with a graphical renderer and `-- --capture` for paired
on/off images from inside Parth's actual cell in `/tmp/blacksite-parth-lamp-*.png`.
