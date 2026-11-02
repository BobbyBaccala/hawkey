# Blender kit pipeline

**Current kit: `kit_v2.py` (pass 2) -> `assets/kit/skater-kit-v2.glb`.**
Pass 2 replaces pass 1's shrink-wrap (which printed the navel, hips and shoulder
blades into the cloth as dents and lumps, and made the breezers crumple in a
crouch) with deliberately shaped garments:

- lofted superellipse sections sized from body measurements, the profile
  smoothed along its length; shoulder pads, chest protector, a loose hem sized
  over the breezer rings so it clears them by construction (then levelled);
- padded breezers: straight-cut legs kept apart at the crotch, hip pads, thigh
  guards, tailbone pad, raised belt band, rolled (thick) leg openings;
- the body is never a wrap target. Garments are only lifted off the body parts
  the game draws (head/neck and legs below the breezers, regions 0 and 3);
  the torso, arms and shorts region are discarded under the kit in
  `assets/uniform.gdshader`, so lifting off them only added lumps. A lift
  only trusts a body surface facing the same way as the garment (so the torso
  never balloons a sleeve), is capped and spread into a soft bulge;
- stiff skinning: breezer weights smoothed over the surface and limited to
  pelvis/spine/thigh bones; sweater weights drop the leg bones and are
  smoothed round the waist and hem (the hem used to fold when a leg lifted);
- vertex budgets: sweater ~4.0k, breezers ~3.7k.

Previews written next to the GLB: front, back, side, crouch_side, crouch_34.
Pass 1 (`kit_v1.py`) is kept for reference.

Pass 1: `kit_v1.py` builds the skater sweater (body + sleeves) and breezers as real
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

## Gear from downloaded models (night shift)

- `skate_v1.py` -> `assets/gear/skate-v1.glb` (HKY skate, CC-BY 4.0).
- `helmet_v2_debrand.py` -> `helmet_v2_smooth.py` -> `helmet_v2_normals.py` -> `assets/gear/helmet-v2.glb`
  (Novichkov helmet, CC-BY 4.0): drops every texture/UV (all logos, numbers, signature), vertex-colour
  team shell, decimate, Taubin smooth, split shell/fittings, sharp normals above 35 deg. They read the
  owner's `Hawkey/art` folder by absolute path, so run them through the bridge.
