# Third-party asset credits

## assets/gear/skate-v1.glb — "Hockey Skate" by HKY
- Source: https://sketchfab.com/3d-models/hockey-skate-a419e7bf24cd423d83bb4d0d7bcdc5ad
- Licence: Creative Commons Attribution 4.0, https://creativecommons.org/licenses/by/4.0/
- Changes (Blender 5.2, night shift item 2, jobs night_skate_0150 / night_skate_v2_0250): eyelet meshes
  removed; source materials replaced by flat per-part vertex colours (no textures, no brand text); rescaled
  to a 0.31 m skate on the Hawkey foot; split along a slanted ankle cut into a rigid boot and an ankle cuff
  that follows the shin; each part decimated (boot 2.4k, cuff 0.6k triangles); mirrored for the right foot.

## assets/gear/helmet-v2.glb — "Hockey Helmet Washington Capitals" by Andrey Novichkov
- Source: Sketchfab (art/incoming/hockey_helmet_washington_capitals.glb in the owner's Hawkey art folder)
- Licence: Creative Commons Attribution 4.0, https://creativecommons.org/licenses/by/4.0/
- Changes (Blender 5.2, night shift item 3, jobs night_helmet_debrand_0302 / night_helmet_v6_0402 / night_helmet_v7_0407, scripts in
  tools/blender/helmet_v2_*.py): **all markings removed** - every texture and UV dropped (club wordmark and
  logo, league shield, maker name, number and signature were texture-only), rebuilt as flat vertex colours
  with a plain team-colour shell; reoriented and scaled to a 0.27 m shell; decimated to 2.7k opaque triangles,
  Taubin-smoothed, sharp normals on rims above 35 deg, split into shell / fittings / visor. No club or brand identity remains.

## Goalie pads and mask (Codex model session, adopted by the night shift)

`gear/goalie-mask-v1.glb`: **Hockey Goalie Mask** by **matýsek**, [source](https://sketchfab.com/3d-models/hockey-goalie-mask-12fe01ffe0d4443b96292815bb79958a), [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Modified: welded, oriented/scaled, reduced geometry, weighted normals, all paint removed (plain team colour and metal cage).

`gear/goalie-pads-v1.glb`: **pads** by **gurjbakshi**, [source](https://sketchfab.com/3d-models/pads-e6313b4e57a04a198fbe3f8598929c05), [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Modified: extracted/mirrored, scaled, split at the thigh hinge, decimated, original texture markings removed, plain materials.


## Bench coach

`gear/coach-v1.glb`: **commanding_gesture_coach** by **restore50** (Sketchfab, CC BY 4.0, supplied in art/incoming). Modified: voxel-remeshed to ~14k triangles, scaled to 1.82 m, scan texture baked to vertex colours (no markings on the source).

## Skater head

`gear/head-v1.glb` (+ `head-v1_T_MH_Reference_BASECOLOR.jpg`): head derived from an Epic Games **MetaHuman** reference head (MetaHuman licence). Modified: split by material, teeth dropped, skin decimated to ~7.6k triangles and eyes to 900, neck cut and blended under the neck guard, base-colour texture resized to 1024, eye colours baked to vertex colours, skin weights transferred from the game's base rig (head/neck binds). Used for skaters only (`MESH_HEAD` in `scripts/skater_visual.gd`).
