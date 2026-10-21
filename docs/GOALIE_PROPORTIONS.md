# Goalie construction correction — 2026-10-21

The owner correctly identified construction errors in the previous checkpoint:
an oversized mitt/web, detached hinged pad tops, an unconvincing stick heel and
skates exposed in butterfly. The earlier finish/animation pass did not correct
those structural errors. This checkpoint supersedes that pad construction.

Source: `39bd21e`, followed by `01c54c4` (heel finish/reach verification).
Claude through 85fd791 and all modes, tactics, bench, skater helmet/visor work are
preserved. No outside asset or plugin is required.

## Measured proportions

Measurements come from actual generated mesh vertices in engine metres, converted
below to centimetres. Glove perimeter is the projected convex silhouette; it is a
sanity measurement, not the official 3D equipment-inspection procedure.

| Item | Previous 7241889 | Corrected |
|---|---:|---:|
| Complete mitt width including cuff | 46.8 cm | 32.6 cm |
| Complete mitt height | 45.5 cm | 35.2 cm |
| Projected convex mitt perimeter | 151.8 cm | 110.8 cm |
| Laced catching web width | 24.6 cm | 16.3 cm |
| Laced catching web height | 17.4 cm | 9.8 cm |
| Pad face width | 27.5 cm | 27.5 cm |
| Complete pad length | 73 cm | 86 cm |

The web is reduced independently of the cuff/body: its area is about 63% smaller.
The cuff is narrower and integrated into the mitt rather than looking like an
additional blocker board. The padded back and T-trap remain, with its leather
support recessed behind the laces. Catcher contact-box dimensions/offsets now fit
the smaller mitt; the automatic catch gate uses its smaller actual web. A front
palm hit outside that web does not become an automatic catch. The held puck uses
the same shared pocket coordinate as contact handling.

## Pads and butterfly

Each pad now has **one continuous shell** from thigh rise to boot. The separate
upper mesh, hinge, folding/shrinking transforms and shortened butterfly collision
box are removed from production posing. The knee break is a sewn flex groove;
it does not detach or rotate the pad top independently. Full visible pad length
is represented in contact coverage throughout the drop. This increases low-shot
coverage and needs human balance playtests.

The entire pad rolls toward the shooter into butterfly; its inner edge becomes
horizontal on the ice. Knee/ankle spacing, skate orientation and a recessed boot
channel leave the boots behind the face. A small whole-shell adjustment preserves
toe coverage during wide pad extensions. The skate geometry remains present and
unchanged in size. Front-view boot/toe coverage is tested for butterfly, left and
right pad extensions; heel/cuff details can still be visible behind the top of the
pad from elevated/side views. No skates are hidden to obtain the image.

The complete shells are kept clear of each other, gloves, blocker, pants and
skates through the existing clipping checks. The test inventory now reads the
whole pad instead of nonexistent detached thigh nodes and includes the new heel
geometry. Its tolerance and forbidden-contact rules were not weakened.

## Stick joint

Blade heel, paddle bottom and shaft bottom now share an exact anchor, tested
through the drop and a raised blocker save. A solid curved heel bridges the
corner. White heel material continues into the first quarter of the blade before
black tape begins, giving the joint a consistent visible construction. Skater
stick geometry/controls are unchanged.

## Reference access and limits

Fresh lookup was attempted on 2026-10-21, including NHL media rulebook, NHL rules
page, IIHF rulebook, Hockey Canada, Bauer, GoalieMonkey, Pure Hockey and Wikipedia.
Requests returned HTTP/proxy 403; no new page, manufacturer photograph or PDF was
successfully viewed. Exact attempted URLs/errors are recorded in the verification
JSON. The implementation therefore uses the owner's explicit corrections,
previously documented equipment-limit figures and measured mesh proportions; it
must not be presented as a newly researched manufacturer replica.

The earlier GOALIE_GEAR.md reference notes record approximately 28 cm maximum pad
face width and 114 cm catching-glove perimeter. Those figures are sanity ceilings,
not instructions to make the pocket itself that size. The 86 cm pad length and
compact web are original adult-gear design targets, not newly verified brand
specifications. Official dimensional certification, manufacturer photo matching,
youth-specific fit, post/RVH/recovery choreography and hardware visual/FPS review
remain open.

## Actual Godot JPEGs

- [Ready stance](screenshots/goalie-proportions-ready-20261021.jpg)
- [Butterfly](screenshots/goalie-proportions-butterfly-20261021.jpg)
- [Complete gear in neutral light](screenshots/goalie-proportions-quarter-20261021.jpg)
- [Smaller mitt/web](screenshots/goalie-proportions-catcher-20261021.jpg)
- [Continuous pad detail](screenshots/goalie-proportions-pad-20261021.jpg)
- [Joined heel close-up](screenshots/goalie-proportions-heel-20261021.jpg)

These are direct unretouched viewport JPEGs. Arena views use main.tscn with HUD
hidden and a frozen inspection camera, 1440×900; neutral views are 960×960. Poses
are generated by production save functions. They are staged inspections, not live
match footage. Production/tests remain Godot 4.6.3. Diagnostic captures use verified
official 4.6.2 Compatibility/llvmpipe, as in previous checkpoints.

Verification: `verification/goalie-proportions-20261021.json`. The broad development
run exposed one stale save-reach assertion after widening the ready hand position.
Its replacement keeps the original required vertical rise and arm-length limit,
requires movement toward the shot line and checks outward direction rather than
an additional fixed 10 cm from an already spread hand. Final affected suites rerun
separately; no atomic all-green final-tree broad rerun is claimed.
