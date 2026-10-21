> Current construction correction: [GOALIE_PROPORTIONS.md](GOALIE_PROPORTIONS.md).
> Detached/hinged pad-top descriptions below are superseded historical notes.

# Goalie equipment and motion checkpoint — 2026-10-21

Owner-directed continuation of goalie graphics/animation, preserving Claude through
85fd791 and the tactical AI work at 668d99a. Main source change: df15aee. No new
plugin, downloaded art, brand logo or paid asset was needed.

## Finish and construction

Neutral engine close-ups exposed black speckling on untextured atlas surfaces:
pad sidewalls, glove binding/laces and cage bars. A controlled capture changing
only anisotropic filtering to regular mipmapped filtering removed it. The shared
MeshBuilder now uses that fallback in Compatibility, retaining anisotropy for
other rendering methods. This is verified on the existing official 4.6.2
llvmpipe diagnostic renderer; it is not a claim about every GPU driver.

- [Original catcher](screenshots/goalie-before-catcher-20261021.jpg)
- [Filtering-only control](screenshots/goalie-filter-probe-catcher-20261021.jpg)
- [Final catcher](screenshots/goalie-final-catcher-20261021.jpg)

Pad faces now have flatter quilting, shallower seams, quieter stitching and a
narrow sewn perimeter binding. Catcher perimeter binding uses a smoothly
subdivided padded curve with rounded ends. Existing white/team-colour graphics
and gear dimensions remain recognizable.

Pad, blocker and catcher share cached synthetic-leather normal/roughness maps
per piece type, independently of colourway. The grain is deliberately subtle
and mipmapped; the reserved atlas strip stays flat. New finite orthogonal tangent
frames handle degenerate constant-UV regions safely. Catcher morph tangents and
normals rotate with its finger fold. These additions do not replace the original
gear with an inflated invisible save volume.

- [Before](screenshots/goalie-before-quarter-20261021.jpg) / [after](screenshots/goalie-final-quarter-20261021.jpg), identical neutral camera and lighting
- [Pad detail](screenshots/goalie-final-pad-20261021.jpg)

## Motion and confirmed catches

The public `butterfly` command is preserved. A smoothstep `goalie_drop` drives
hips, knees, skates, pad articulation and the existing pad contact-box dimensions,
easing into and out of the stance instead of starting/stopping at a constant pose
speed. Save weights use an exact exponential response rather than linear clamps,
retaining interruptible glove/blocker/pad reactions at different frame rates.

Without optional strafe motion capture, a short alternating procedural shuffle
now advances from measured lateral travel. Feet remain separated; one foot lifts
slightly during its recovery. Existing installed-clip behavior is retained. This
is not full world-space foot locking or a completed T-push/post-integration system.

A confirmed regulation front-pocket catch calls `secure_catch()` and folds the
catcher's finger section toward the thumb with a blend shape. Merely selecting a
glove save keeps the pocket open. Whistle phases now continue goalie animation;
the frozen caught puck follows its glove until faceoff setup clears ownership
and releases the fold. Catch eligibility, rebound materials and ordinary shot
collision rules are retained. The shootout contact branch retains its existing
save flow; this checkpoint does not claim a separate shootout catch-and-hold sequence.

- [Secured catch fold](screenshots/goalie-secured-catch-20261021.jpg)
- [Ready in arena](screenshots/goalie-arena-ready-20261021.jpg)
- [Butterfly in arena](screenshots/goalie-arena-butterfly-20261021.jpg)

## Verification and remaining work

`test_goalie_polish.gd` adds 26 checks: map/mipmap/tangent validity, eased drop,
frame-rate-independent save blending, contact-gated glove closure/release,
procedural shuffle with no clip, actual regulation catch notification, continued
animation during the whistle, puck attachment and faceoff cleanup. Existing save,
gear/contact and clipping tests remain required. Full run and final follow-up
results are recorded in `verification/goalie-polish-20261021.json`.

All published images are direct Godot viewport JPEGs. Neutral images are 960×960
with fixed cameras/lights; arena images are 1440×900, frozen inspection cameras
with the HUD hidden. They are staged pose inspections, not normal gameplay footage
or a hardware FPS benchmark. Production and tests stay on Godot 4.6.3; diagnostic
captures use verified official 4.6.2 Compatibility/llvmpipe.

Goalie realism remains partial. The thigh-rise hinge shape, mask opening/cage and
shell separation, anatomical proportions, more natural finger/web deformation,
post/RVH transitions, planted recovery/T-pushes, screens/rebound tracking and
hardware visual/performance review still need work. Existing physical proxies are
not exact mesh collision. No release-quality or Claude visual approval is claimed.
