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
