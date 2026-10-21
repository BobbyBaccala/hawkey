# Helmet photo comparison — 2026-10-21

Code `99933f1`, source baseline `efeaf31`, Claude presentation history through
`e3caa27` preserved. Owner supplied and Codex actually reviewed two screenshots:
`Screenshot 2026-10-21 072400.png` (navy Bauer, uncaged) and
`Screenshot 2026-10-21 072432.png` (black CCM with cage). These replace the previous
blocked-web reference request. No product photograph was downloaded as a game
asset. The first image guides this original uncaged model; the second supports
construction observations, not an instruction to add a cage. Exact product
edition, dimensions and manufacturing specifications have not been verified.

| Observed in supplied photos | Implemented original geometry |
|---|---|
| Shaped crown and separate top section | Crown lowered 8 mm, broad moulded rails and a satin crown panel; smooth normal field retained |
| Horizontal temple vent rows with internal supports | Three lateral rows on each side, rounded mesh openings and recessed bridge ribs; matte black liner backing |
| A defined lower side-shell section | Narrow raised shell break along both sides |
| Thin clear ear protection with open windows | Rounded translucent frames and two cross ribs replace opaque padded blocks |
| Small mounting screws and strap fasteners | Separate silver-grey fasteners and black ladder-lock adjusters |
| Flat retention webbing | Existing fitted 12 mm black nylon strap retained, with adjusters added |

The approved visor mesh, material and attachment are unchanged. Runtime comparison
against `9844db3` reports byte-identical mesh arrays (32,948 bytes). Crown shaping
blends out above the visor mount. No logos or branding were added. The result is
reference-informed original equipment, not a dimensionally exact branded replica.

## Genuine Godot JPEGs

[Before quarter](screenshots/helmet-reference-before-quarter-20261021.jpg) ·
[Final quarter](screenshots/helmet-reference-final-quarter-20261021.jpg) ·
[Final front](screenshots/helmet-reference-final-front-20261021.jpg) ·
[Final side](screenshots/helmet-reference-final-side-20261021.jpg) ·
[Final rear](screenshots/helmet-reference-final-rear-20261021.jpg)

[Actual arena model close-up](screenshots/helmet-reference-arena-closeup-20261021.jpg) ·
[Actual match camera](screenshots/helmet-reference-arena-match-20261021.jpg)

Neutral views: 960×960, identical cameras/light before/after, actual production
skater in a staged Godot 4.6.2 llvmpipe scene. Arena: 1440×900, actual main scene;
close-up freezes simulation and hides HUD for inspection. All direct viewport
JPEGs; no retouching or image generation. Metadata in `verification/helmet-reference-*.json`.
Production/CI stay pinned to 4.6.3; 4.6.2 remains a separately verified diagnostic
renderer, not a silent downgrade. No hardware FPS/Forward+ approval is inferred.

## Verification and limits

Sixty-nine surface checks include clearances/normal continuity, open vent rays
through shell and crown, finite/unit geometry, cached part sharing and mesh budget.
The complete assembly (including visor and strap) is 8,215 vertices /14,932 triangles;
the shell alone is 4,634 /8,412. New crown, ear and hardware children add three
material draws per skater compared with the prior retention checkpoint. Their
geometry and materials are cached; no rendered FPS improvement is claimed.

A real capture exposed collapsed ear-frame/buckle loops: `add_tube` initialized a
zero tangent when its endpoints coincided. It now seeds a closed loop from its
first segment. A raw-geometry regression checks thickness/nonzero normals before
GPU normal packing can hide that defect. Opaque ear-block experiments were removed;
matte liner material prevents distracting glossy flashes inside vent openings.

Final affected run:11suites pass. Broad regression:47checks pass,zero fail,one
optional mocap skip (44native suites plus31Python tests). Results are recorded in
`verification/helmet-reference-20261021.json`. Broad checks began before the last
small vent-rib addition; the final affected suite run covers the final code.
The fit test now measures the actual crown surface instead of the former nominal
height constant, so the lowered crown cannot evade the clearance check.

Remaining: facial anatomy/likenesses, more authored shell/ear contours and material
bakes, distance LODs and hardware performance review. The supplied single-angle
photos do not establish unseen geometry or safety certification. Claude handoff
CX-20261021-007 requests review; no acknowledgement is assumed. No PR merge/release.
