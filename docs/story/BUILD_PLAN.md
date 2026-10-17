# Building "Again" — parallel build plan

Goal: the whole story in `AGAIN_OUTLINE.md` (Acts I–III, 18 shards, the wipe loop, three endings) playable in the web port (`web/`). Six workstreams run in parallel sessions, each in its own git worktree on its own branch cut from `story-build`. The integration session (the one that wrote this) merges them, then builds Act III flow and the endings.

Defaults for the outline's open questions (all data, change freely): unnamed state; English with light Hindi (*beta*, *chai*); Parth's original crime stays "small and unrelated"; no Meera epilogue; title stays **Blacksite: Ghost Exit**.

## 1. The foundation (already on `story-build`)

`web/src/story/` — read these before writing anything:

| File | What it gives you |
| --- | --- |
| `types.ts` | `Place`, `Condition`, `Action`, `TriggerDef`, `DocumentDef`, `DialogueDef`, `ObjectiveDef`, `StoryEvents`, `StoryFeature` |
| `director.ts` | `game.story` — state, flags, wall, acts, `check(cond)`, `run(actions)`, `playShard(id)`, `sleep(s)`, triggers, objectives, `capture(reason)` → `wipe()`, `captureHandler`, save/load |
| `state.ts` | What survives a wipe and a page reload (localStorage `blacksite.ghostexit.save.v1`; `?fresh` in the URL clears it) |
| `ui.ts` | `game.story.ui`: `say(speaker, text, s)`, `showDocument(def)`, `choose(options, prompt)`, `banner(title, sub)`, `blocking` |
| `dialogue.ts` | Dialogue runner (lines, choices, labels/goto) |
| `triggers.ts` / `place.ts` | Data-driven props and walk-in zones; `resolvePlace()` |
| `features/index.ts` | Registry. **Every workstream already has a registered stub** in `features/<id>/index.ts` |

Data lives in `web/public/data/story/` and `index.json` lists every file. **Every workstream already has its own files listed** — you never need to edit `index.json`.

Hooks a feature gets (`StoryFeature`): `buildStatic(b, floors, data)` (static geometry before the world is finalized — signs, decals, new rooms/culverts), `init({ game, data })`, `update(dt)`, `onWipe(cycle)` (after the reset, before waking; `cycle:` flags of the ending cycle are cleared right after it).

Room ids you'll need (`{ "plan": …, "room": … }` places): food-ground `serving` (3 serving windows), `dining`; maintenance-ground `tool`, `stair` (B1 service stair), `landing` (B1 stair lobby), `utilities`; maintenance-b1 `landing` (gated landing), `pump` (drainage / sump); medical-ground `ward` (infirmary · 6 beds), `medicine` (secure medicine), `staff` (records), `showers`; admin-ground `visitation`, `records` (intake records), `office` (warden); cellhouse-b-0 `glassa` / `glassb` (special rooms A/B); hq-0 `evidence`, `keys`, `lift` (restricted lift), `liftlobby`; hq-1 `surveillance`, `control`, `chief`; nidra-b2 `interrogationa`, `observation`, `records` (subject archive), `lift`, `liftlobby`, `stairn` (restricted egress stair). Cellhouse A anchors: `parth_spawn` (N03), `parth_memory_shelf`, `cellhouse_a_key_rack`, `cellhouse_a_dayroom`; N03's gate is door `cellhouse_a_floor3_north_03`, the tier-3 guard quarter door `cellhouse_a_floor3_guard_quarter`. The pool is anchor `pool` (20 × 10 × 2.4 m, `game.pools[0]`). Listen to `game.story.events` (`flag`, `shard`, `wall`, `capture`, `wipe`, `act`, `dialogue`, `signal`, `ending`).

Existing systems you'll use: `game.env` (clock `timeHours`, `dayNumber`, `setTimeHours`, `setWeather`, `nightLevel()`), `game.player` (`teleport`, `setControlEnabled`, `enterRestrictedZone(id, mult)`), `game.suspicion`, `game.noise`, `game.guards` (nav-driven guards: `guards[i].hearNoise`, `nav.findPath`), `game.doors` (`openForAI`, `setState`, `spec.persistentId`), `game.inventory` / `game.access`, `game.memory`, `game.render` (`grade`, `fade`, `chroma`, `underwater` uniforms), `game.cine` (GSAP camera override: `weight`, `position`, `look`), `game.hud`, `game.anchors`, `game.floors` (floor plans: `roomCenters`, `rooms`, `doors`, `toWorld`), `game.pools` / `game.swim`.

## 2. Rules for parallel work

1. **Only edit files you own** (table below). Everything else is read-only — including `game.ts`, `director.ts`, `types.ts`, `ui.ts`, `story.css`, `index.json`, other features and other workstreams' JSON.
2. If you genuinely need a change in a shared file, don't make it: implement what you can inside your feature, and list the exact hook you need under **"Integration requests"** in your hand-over note. The integration session applies them.
3. New code goes under your folder (`web/src/story/features/<id>/…`, plus any extra files listed for you). New JSON goes in your listed data files.
4. Per-cycle flags start with `cycle:` (the wipe clears them). Use the vocabulary below; add new ids with your workstream prefix and document them in your hand-over.
5. Text the player reads is data, never hard-coded TypeScript.
6. Keep the console clean; `npx tsc --noEmit` and `npm --prefix web run build` must pass on your branch.

## 3. Workstreams and ownership

| # | Workstream | Owns (write) | Delivers |
| --- | --- | --- | --- |
| W1 | **Loop, capture & the wall** | `src/story/features/loop/**`, `data/story/features/loop.json`, `data/story/triggers/loop.json` | Capture cinematic via `story.captureHandler` (guards drag Parth → HQ restricted lift → NIDRA B2 Interrogation A chair → speaker plays a child's *"Again."* → fade → wake in N03). Tally scratches under the bunk (count = cycle − 1) and the wall of N03 that fills with an entry per `wall` event (decals/text on the cell wall; readable with E as a document). Cold open on a fresh save (black, water, *"two… seven… one… eight…"*, a hand slipping, gasp awake). Cistern stash in N03 (`stash` in state; unlocked by flag `stash_unlocked`). First-capture-is-intended: B1 stair gate alarm → capture (`capture("alarm")`); dose knock-out at 21:00 if never captured. Wake in **Infirmary bed 4** instead of N03 when `cycle:jagran` (plays M09; `onWipe` still sees the ending cycle's `cycle:` flags). **Owns the act 1 → 2 transition**: after the first wipe set `capture_first` and `act: 2`. Act III rule: a capture restarts the night at 19:00 instead of wiping (`act === 3` → handler returns `"handled"`). |
| W2 | **Daily routine & the dose** | `src/story/features/routine/**`, `data/story/features/routine.json`, `data/story/triggers/routine.json` | Schedule on the 12-min clock from data (06:00 count → missing it raises suspicion/alarm; 07:00 breakfast + dose; 09:00 work; 12:30 lunch + Bhosle away → `signal routine:lunch`; 14:00 yard/pool; 18:00 dinner + dose; 19:00 lock-in (N03 gate closes); 21:00 lights out; day 3 10:00 visitation). HUD clock/next-beat line. Dietary window (Food Services serving windows) offers the pill: **take** (clean) or **pocket** (`cycle:dose_pocketed`, item `pill`) → withdrawal: grade drift (`game.render.grade` saturation/tint wobble), camera sway, suspicion ×1.3 via `player.enterRestrictedZone("withdrawal", 1.3)`, flag `cycle:withdrawal` (shimmering shards use it in their `when`). First breakfast plays **M03**. Routine signals for the others (see vocabulary). |
| W3 | **Water** | `src/story/features/water/**`, `src/world/pool.ts`, new `src/world/campus/culvert.ts`, `data/story/features/water.json`, `data/story/triggers/water.json` | Breath meter (4 segments **2 · 7 · 1 · 8**, 18 s) with Raman counting (subtitles), drowning → `capture("drowned")` (or Act III: restart). Pool dives: T1 at the shallow end on first dive; the deep-end **drain grate** reachable with a full 18 s + `cycle:withdrawal` → **T2**; with `cycle:jagran` too → **T3** (surfaces into guards at the deck, Meera's own voice). **Owns the act 2 → 3 transition** (`act: 3` when T3 ends). The **drainage route**: Maintenance B1 Gated Landing → Drainage/Sump → flooded culvert under the perimeter wall (new geometry via the feature's `buildStatic`, never editing campus files) with air pockets spaced 2, 7, 1, 8 s of swimming apart → final 8: **T4** + the hand (`signal hand_offered`; player releases/holds → `signal hand_released` / `hand_taken`) → reservoir outside the wall at dawn. |
| W4 | **NPCs & dialogue** | `src/story/features/npcs/**`, `data/story/features/npcs.json`, `data/story/triggers/npcs.json`, `data/story/dialogue/npcs.json` | Bhosle (tier-3 guard quarter, chai at the cell each morning, *"Good morning, beta. Sleep well?"* every cycle; away 12:30–13:00; Act III: card under the tumbler → `cycle:bhosle_card` + item `bhosle_card`, *"They told me to bring you down at two. I'll be slow."*), Kabir (Cellhouse B Special Room A behind glass; remembers every cycle; counts Parth's visits; reveals Meera = Raman's sister and the drainage route → **M08**; freeable with `cell_master_key` → `kabir_freed`), Parth's mother (Admin visitation booth, day 3 10:00 → **M06** + photo), Meera (B2 observation silhouette + speaker voice; the **Observation-glass conversation** after **M14** with the confession choice → flags `confessed`, `observation_done`). Stand-in visuals from `guard.glb` (tints/props) unless the character pipeline provides more. |
| W5 | **Content & interactables** | `public/data/memories/*.json` (all new shard texts), `data/story/triggers/act1.json`, `act2.json`, `act3.json`, `data/story/documents.json`, `data/story/dialogue/story.json`, `data/story/objectives.json`, `data/story/features/content.json`, `src/story/features/content/**` | Every shard's text (M02–M14, T1–T4; same JSON shape as `memory_001.json`). Props/triggers/documents for every room in the outline (M02 tumbler, M04 handwriting note in the 2718 locker, M05 stair gate, M07 intake file, the Warden memo, M10 showers, M11 property bag → code **281828**, M12 monitor wall, M13 tape archive, radio to kill searchlights → `searchlights_off`, Jagran in Secure Medicine → item `jagran` / `cycle:jagran` when taken, records drawer, doorplates **Dr. M. Varma** and **S-07** via `buildStatic`). The **restricted lift** (HQ ↔ B2) as a keypad interactable (281828) with a fade "ride" (no geometry). Full objective chain Acts I–III with conditions (acts change elsewhere: W1 sets act 2, W3 sets act 3). |
| W6 | **Audio** | `src/audio/**`, `src/story/features/audio/**`, `public/audio/**`, `data/story/features/audio.json` | WebAudio engine (unlocked on the start click), procedural/synth where there are no files: room-tone hum, fluorescent buzz, rain on roofs and puddles (tied to `env.weather`, indoor factor), footsteps per surface (`player.events.footstep`), doors/gates (noise events with `source: "door"`), alarms, water/underwater muffling (`swim.immersion`), searchlight hum, heartbeat under suspicion, story stingers on `shard`/`capture`/`wipe`/`act`, the **2·7·1·8** motif. Optional per-line voice clips (`audio` field on dialogue lines). Master/music/sfx volumes in data. |
| — | **Integration** (this session) | `game.ts`, `src/story/*.ts` (foundation), `src/story/features/endings/**`, `data/story/features/endings.json`, shared files | Merges, integration requests, Act III night flow (forced monsoon, termination order at 02:00), endings (Let Go / Hold On / Mercy), credits, New Game+, full play-through. |

## 4. Shared vocabulary

**Shard ids** (`public/data/memories/<id>.json`, written by W5, played by whoever owns the moment):

| Id | Outline | Played by |
| --- | --- | --- |
| `memory_001` | M01 A Familiar Voice (exists) | shelf in N03 (existing) |
| `m02_chai` | M02 Chai | W5 trigger (Bhosle's tumbler, guard quarter) |
| `m03_dietary_window` | M03 The Dietary Window | W2 (first breakfast) |
| `m04_handwriting` | M04 Handwriting | W5 (2718 locker note) |
| `m05_stair_gate` | M05 The Stair Gate | W5 (B1 stair lobby zone) |
| `t1_summer` | T1 The Tank I: Summer | W3 |
| `m06_visitor` | M06 Visitor | W4 (mother) |
| `m07_consent` | M07 Consent | W5 (intake records) |
| `t2_deeper` | T2 The Tank II: Deeper | W3 |
| `m08_subject_three` | M08 Subject Three | W4 (Kabir) |
| `m09_infirmary` | M09 Infirmary, Night | W1 (wake in bed 4) |
| `m10_what_i_told_them` | M10 What I Told Them | W5 (showers zone, after T2) |
| `t3_the_hand` | T3 The Tank III: The Hand | W3 |
| `m11_effects` | M11 Effects (clue `281828`) | W5 (property bag) |
| `m12_forty` | M12 Forty | W5 (monitor wall) |
| `m13_cycle_twelve` | M13 Cycle Twelve | W5 (tape archive) |
| `m14_why_i_came` | M14 Why I Came | W4 (Interrogation A chair → Observation conversation) |
| `t4_surface` | T4 The Tank IV: Surface | W3 (culvert, final 8) |

**Codes:** `2718` (M01 clue), `281828` (M11 clue: restricted lift override).

**Items:** `cellblock_key`, `service_key`, `medical_key` (dayroom rack), `maintenance_access_card` (2718 locker), `security_key`, `lab_key`, `cell_master_key` (HQ command), `bhosle_card` (ACCESS_CARD, Act III; opens Maintenance B1 Gated Landing), `pill` (pocketed dose), `jagran` (vial), `raman_notebook`, `mother_photo`.

**Counters:** `story.getVar/setVar/addVar(name)`, action `{ "add": name, "by": n }`, condition `{ "count": { "name": …, "atLeast": n, "below": n } }`; persisted, `cycle:` names cleared by the wipe. Prefix names with your workstream (`npcs:kabir_visits`).

**Flags** (persist unless prefixed `cycle:`): `capture_first`, `stash_unlocked`, `searchlights_off`, `kabir_freed`, `pistol_fired` (locks Mercy), `harmed_someone`, `confessed`, `observation_done`, `termination_tonight`; per cycle: `cycle:dose_taken`, `cycle:dose_pocketed`, `cycle:withdrawal`, `cycle:jagran`, `cycle:bhosle_card`, `cycle:locked_in`, `cycle:lights_out`. Triggers that fire once set `trigger:<id>` automatically.

**Signals** (`story.signal(id, data)`): `routine:<beat>` with beats `count`, `breakfast`, `work`, `lunch`, `yard`, `dinner`, `lockin`, `lightsout`, `visitation`; `dose_offered`, `dose_taken`, `dose_pocketed`; `breath_segment {segment: 0–3}`, `breath_out`; `air_pocket {index}`; `hand_offered`, `hand_released`, `hand_taken`; `lift_ride {to: "b2" | "hq"}`; `alarm {reason}`; `observation_choice {choice}`; `searchlights_off`.

**Capture reasons:** `caught` (guards), `alarm` (B1 stair gate), `dose` (21:00 knock-out), `drowned`, `voluntary` (the chair), `count`, `dev`.

**Endings:** `let_go`, `hold_on`, `mercy` (integration session).

## 5. Testing recipe

- Launch configs `web-w1` … `web-w6` (ports 5191–5196) exist in `.claude/launch.json`; use yours, so your page only reloads for your own edits.
- Automation: `const g = __game; g.begin(); g.started = true;` then **`await g.stepAsync(seconds)`** (yields between frames so story promises advance; plain `step()` won't run dialogue/capture chains). Keys: `g.input.simulate("KeyE", true/false)`. Aim: `g.lookAt(vec)`. Vector3: `g.player.position.constructor`.
- Between your JS calls the real loop keeps simulating; set `g.started = false` to freeze for screenshots. Take two screenshots (the first is often stale when the pane is hidden).
- `?fresh` resets the save (cycle 41). Dev Mode (⌘D → `tez`) has a **Story** folder: act, flags, cycle, capture, wipe, clear save.
- Story state: `__game.story.debugInfo()`; `__game.debugInfo().story`.

## 6. Git

`git` needs `DEVELOPER_DIR=/Library/Developer/CommandLineTools` on this machine (prefix every git command). Commit on your own branch as you go (small commits, clear messages, `Co-Authored-By` trailer). Never push, never touch `main` or `story-build`. Your final report: branch name, what's playable, how you verified it, and integration requests.
