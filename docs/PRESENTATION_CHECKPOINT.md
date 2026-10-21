# Presentation checkpoint (Claude)

Owner of this file: Claude (presentation/animation). Codex's shared record is
docs/COORDINATION.md on codex/game-modes; this file is the presentation side of
it, kept here so neither agent edits the other's copy. Statuses follow
docs/MASTER_PRODUCTION_DIRECTIVE.md (codex/game-modes).

| Field | Value |
|---|---|
| Task | Goalie equipment v2: pads, catcher, mask rebuilt from owner reference photos |
| Owner | Claude |
| Branch | claude/presentation-goalie-gear (from prototype/skating-puck-lab aeeeca3) |
| PR | Draft PR into prototype/skating-puck-lab (see PR list) |
| Files | scripts/gear_builder.gd (equipment geometry/paint), scripts/skater_visual.gd (goalie stick grip/blade z mid-butterfly only), tools/capture_piece.gd (new), docs/ASSETS.md, docs/BACKLOG.md, this file |
| Shared files / interfaces | No change to match.gd, colliders' shapes or sizes, timing or cameras. Goalie gear collider sizes (get_goalie_gear) unchanged; the visible pad block is ~1.3 cm thicker than before (FACE_Z/BACK_Z in gear_builder.gd). Goalie stick visual sits up to 3.5 cm further forward mid-butterfly; GoalieBlade/Paddle colliders follow the visual, so a stick save mid-drop happens slightly earlier. |
| Dependencies | None on Codex work. Codex's roster/equipment IDs can later choose colourways; gear builders already take kit/accent colours. |
| Tests | All 18 suites pass on Godot 4.6.2 Linux (headless): animation, boards, clipping (incl. save poses), controller, controls, gear_graphics, goalie_gear, goalie_saves, ice, lab, lighting, match, match_loop, match_state, mocap (skipped: clips absent), puck_flight, simulation, stride. |
| Evidence (genuine engine renders, llvmpipe GL compatibility) | docs/screenshots/goalie-pads-v2-auto-20261020-1747.png, goalie-catcher-v2-auto-20261020-1747.png, goalie-mask-v2-auto-20261020-1747.png, goalie-gear-v2-saves-auto-20261020-1747.png (close range, all save poses), goalie-gear-v2-gameplay-auto-20261020-1747.png (broadcast camera) |
| Integration status | Implemented + Tested on branch; not integrated (awaiting owner review of the draft PR). Feature status: Partial. |

## What improved
- Pads read as modern flat-face pads: square block with flat sidewalls, quilted face with tack stitching, boot section kinked forward with ribs, knee landing block and calf wrap on the inside.
- Catcher reads as a modern glove: bound perimeter roll with lace wraps, string-web pocket over a dark T, padded palm, big flat cheater.
- Mask has the modern silhouette: crest, side flares, long forward chin, vents, straps, chrome cage.

## What is still visibly wrong / needs human assessment
- At broadcast gameplay distance the goalie is ~60 px tall; gear changes are subtle there. The larger visible defects at gameplay distance remain skater body proportions and the blocky jersey/torso.
- Catcher cheater sits as a separate slab; on real gloves it is sewn into the cuff and angled more. Web lattice is very regular.
- Mask backplate is a seam line, not a separate plate; cage bars are uniform tubes.
- Pads have no strap buckles/toe ties; leg channel is simplified. Renders are software (llvmpipe) - lighting differs on real GPUs.
- Human review needed: overall proportions against the photos, and how the gear moves in the butterfly in real time.

## Exact next action
Owner reviews the v2 renders; then either iterate gear pass 3 (backlog) or move to the main gameplay-distance defect: skater torso/jersey silhouette and shoulder/arm proportions (scripts/skater_visual.gd build_jersey/update_cloth_sleeve).
