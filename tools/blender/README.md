# Blender kit pipeline

`kit_v1.py` builds the skater sweater (body + sleeves) and breezers as real
meshes around the CC0 base body (`assets/player-base-v1.glb`), skins them to
the same skeleton and exports `kit_v1.glb` (copied into the game as
`assets/kit/skater-kit-v1.glb`). Everything is generated from code: no
third-party or commercial art, no logos.

Run headless with Blender 4.x/5.x:

    blender -b --factory-startup --python-exit-code 1 --python tools/blender/kit_v1.py -- <folder>

`<folder>` must contain `input/player-base-v1.glb`; results go to `<folder>/out/`
(`kit_v1.glb` plus front/back/posed Workbench previews). The log prints
`CLEARANCE`, `WAIST` and `GARMENT` lines and ends with `KIT_V1_OK`.

## How the garments are made

1. Clean lofted tubes per part (trunk, neckband, fixed-girth sleeves; pelvis
   and thighs for the pants) fused with a voxel remesh, so sleeves and
   shoulders are one continuous surface (no welded seams).
2. Openings cut with planes (hem, collar, cuffs, waist, leg openings);
   only the largest piece is kept.
3. Relax + Shrinkwrap (outside) cycles against a smoothed copy of the body,
   then garment volume (shoulder caps, chest protector, hip pads), and a final
   guard against the true body on the sleeves only.
4. The sweater hem is pushed radially out past the pants' outer wall so it
   hangs over the breezers.
5. Decimated to game budgets (~3.6k sweater, ~3k pants vertices), single
   sided (the kit shaders render both faces), skin weights transferred from
   the nearest body face (top 4 bones).

In Godot, `skater_visual.gd` (`kit_garments()`) splits the sweater into body
and sleeve surfaces, adds the UV/UV2 the kit cloth shader expects (number,
nameplate, hem and elbow stripes) and binds both to the rig skeleton by
bone name. Goalies and officials keep the procedural kit.

## Bridge (Windows, owner's machine)

`bridge/` holds the file-watching runner used when Blender is only installed
on the owner's PC: double-click `Start Blender bridge.bat`; it runs any
`jobs/<name>.py` once `jobs/<name>.ready` appears and writes
`out/<name>.log` and `out/<name>.done`.
