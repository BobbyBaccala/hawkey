# Player realism review — 2026-10-20

Combined branch preserves Claude presentation history through `90e1870`.
This is an improvement checkpoint; it has not met a release-quality graphics bar.

## Implemented

The prepared CC0 body had lost its UVs/material assignments, so eyes inherited clay
skin. Restore separate skinned eyes/lips and stable bind-pose UVs. Cache remapped
meshes and retain positions, indices, bones, weights and imported LODs. Normal
re-encoding measured at most 0.00013 difference, bounded at 0.0005 by tests.
Add restrained iris/pupil, lip and brow definition; reduce plastic skin, breezer and
glove highlights. Correct Compatibility vertex-color conversion while retaining
linear-space metal classification. Guard degenerate detail normals. Hide idle CPU
snow artifacts while allowing active spray to finish its lifetime. Clear visors no
longer cast opaque shadows. No new external asset was imported.

Full-scene review caught black facial stripes from negative GLSL pow inputs. All
new facial exponent bases use absolute values. A displayed-GPU regression test
checks the production shader: 576 samples, zero black pixels. A deliberately faulty
negative control reproduces 480 black samples, confirming this test detects the
bug. An initial probe with unspecified ambient color/insufficient warmup was
underlit and not used as final evidence.

## Genuine engine JPEGs

- [Before](screenshots/player-realism-before-head-20261020.jpg) / [after](screenshots/player-realism-after-head-20261020.jpg)
- [Equipment](screenshots/player-realism-equipment-20261020.jpg)
- [Goalie pad-save pose](screenshots/player-realism-goalie-20261020.jpg)
- [Match camera](screenshots/player-realism-arena-20261020.jpg)
- [Frozen arena close-up](screenshots/player-realism-arena-closeup-20261020.jpg)

Neutral before/after: Godot 4.6.3 softpipe, identical lighting/cameras, 960×960;
baseline source `eceda47` predates material fixes. Goalie is a staged pose, not
proof of a live save. Full arena: official Godot 4.6.2 llvmpipe, 1440×900, following
Claude's renderer lead. Close-up freezes simulation and hides HUD for inspection.
All are direct viewport JPEGs, without retouching or image generation. Metadata:
`docs/verification/*-20261020.json`.

## Research read and applied

Official Godot 4.6 docs read 2026-10-20, documentation head
`b10b7ed373c2d15555186914b82e167169b5b87b`:

- [Standard materials](https://github.com/godotengine/godot-docs/blob/4.6/tutorials/3d/standard_material_3d.rst): roughness/normal detail versus actual geometry; normal maps cannot fix silhouette.
- [Spatial shaders](https://github.com/godotengine/godot-docs/blob/4.6/tutorials/shaders/shader_reference/spatial_shader.rst): OUTPUT_IS_SRGB distinguishes Compatibility color-space handling.
- [Shader functions](https://github.com/godotengine/godot-docs/blob/4.6/tutorials/shaders/shader_reference/shader_functions.rst): negative pow bases are undefined, even with nominally integral floating exponents.
- [Model export](https://github.com/godotengine/godot-docs/blob/4.6/tutorials/assets_pipeline/importing_3d_scenes/model_export_considerations.rst): preserve scale, orientation, UVs and normals.
- [Mesh LOD](https://github.com/godotengine/godot-docs/blob/4.6/tutorials/3d/mesh_lod.rst): retain imported simplification data when rebuilding surfaces.
- [Rendering limits](https://github.com/godotengine/godot-docs/blob/4.6/tutorials/3d/3d_rendering_limitations.rst): renderer-specific capability checks remain necessary.

Free authoring tools researched through their actual READMEs, not installed:
[Material Maker](https://github.com/RodZill4/material-maker) at
`67446621f5104c55defe720c33beed32c4e1f85f` for procedural PBR;
[MPFB](https://github.com/makehumancommunity/mpfb2) at
`b1a2dc98776da9d1eea751b159d42cf61778fe2e` for Blender human generation.
No extra plugin is necessary for this increment. Future imported assets need their
own license review; tool availability is not evidence of finished hockey models.

## Validation and remaining work

Full Godot 4.6.3 runner: 45 passed, zero failed, one optional mocap skip; includes
42 native suites and 31 Python tests. That run used the 70-check surface test;
subsequent LOD-preservation recheck passes 77 checks. Displayed 4.6.2 shader test
passes 576 samples; negative control fails 480 as expected. See verification JSON.

Production/CI remain pinned to 4.6.3. The separate official 4.6.2 diagnostic binary
was verified against the release SHA512 list. This host's 4.6.3 full-arena software
rendering remains unreliable; hardware GPU, Forward+ and export checks remain open.

```sh
python3 tools/check_project.py --suite all --workers 2 --output build/realism-checks
# Working X display required; diagnostic binary is not the production pin:
DISPLAY=:9 LP_NUM_THREADS=2 build/renderer-diagnostic/godot-4.6.2 --path . --rendering-method gl_compatibility --audio-driver Dummy --script tests/visual/test_skin_render.gd
# Add -- --negative-control to verify detection of the old shader defect.
DISPLAY=:9 LP_NUM_THREADS=2 build/renderer-diagnostic/godot-4.6.2 --path . --rendering-method gl_compatibility --audio-driver Dummy --script tools/capture_realism_game.gd
```

Claude owns the next helmet silhouette, padding fit, visor-rim and pose review.
Close-ups still show broad helmet highlights, limited facial variety/coarse anatomy
and a pronounced visor edge. Authored anatomy/UVs, equipment normal/roughness bakes
and motion-reference review are needed. Materials alone cannot deliver AAA models.
No PR merge, publication, purchase or game release was performed.
