# Development research applied to this alpha

Reviewed 2026-10-20, America/Toronto. Scope: original Godot hockey project, small
team, preserve Claude's art/animation work, no release or paid tooling. These
sources inform concrete changes; they are not proof of AAA quality.

## Primary sources actually read

Official Godot documentation source, branch 4.6, verified head
`b10b7ed373c2d15555186914b82e167169b5b87b` before/after reading:

| Source | Finding | Applied work |
|---|---|---|
| [Keyboard/controller focus](https://github.com/godotengine/godot-docs/blob/b10b7ed373c2d15555186914b82e167169b5b87b/tutorials/ui/gui_navigation.rst) | Give a scene initial focus; explicitly define neighbors; hidden controls can lose focus; keep built-in UI actions separate from gameplay | Explicit complete forward/reverse preferences focus loop, cross-column neighbors, real `ui_focus_next` test, existing gameplay actions preserved |
| [General optimization](https://github.com/godotengine/godot-docs/blob/b10b7ed373c2d15555186914b82e167169b5b87b/tutorials/performance/general_optimization.rst) | Identify and measure the bottleneck; remeasure after changing it; results depend on hardware | Reproducible isolated 992-fixture/14,745-player snapshot profile; move measured multi-second GM day save off the UI thread |
| [The profiler](https://github.com/godotengine/godot-docs/blob/b10b7ed373c2d15555186914b82e167169b5b87b/tutorials/scripting/debug/the_profiler.rst) | Separate logic/physics/render costs; interpret measurement scope | CPU data timings are labeled separately from gameplay/render FPS; no unsupported hardware performance claim |
| [Thread-safe APIs](https://github.com/godotengine/godot-docs/blob/b10b7ed373c2d15555186914b82e167169b5b87b/tutorials/performance/thread_safe_apis.rst) | Active scene-tree access is not thread-safe; avoid shared mutable resources and GPU work in workers | One isolated data-only checkpoint worker; deep-copied state/strengths; no Node/GPU/ResourceLoader work; publish result on main thread after joining |
| [Multiple resolutions](https://github.com/godotengine/godot-docs/blob/b10b7ed373c2d15555186914b82e167169b5b87b/tutorials/rendering/multiple_resolutions.rst) | Treat project viewport as a design size; use scalable/container layout rather than assume physical resolution | Container-driven two-column preferences at the existing 1440×900 design size; genuine engine JPEG layout inspection. Wider resolution/device certification remains open |

The public docs website and Microsoft XAG 107 request returned HTTP 403. The
attempted accessibility-specific Godot path returned 404. Those pages were not
read and are not represented as verified research. Official GitHub source was
accessible through the normal supported network route. No external game code,
branding or assets were copied into the project.

## What changed

**Visibility and comfort:** saved optional reduced-motion and puck-marker flags
preserve older settings. Reduced motion fixes the rink camera, stops title orbit,
removes banner scale/fade and suppresses animated goal-light/arena celebrations;
actual goals and gameplay remain active. Practice uses the same fixed view.
A fixed-size black/white screen-space marker follows the actual puck projection
without modifying puck scale, collisions or shot physics; it can be disabled and
hides on pause. These are original design choices responding to the audit, not
an assertion that an inaccessible standard mandated this exact implementation.
The preferences page has text On/Off states, a labeled marker preview and clear
keyboard/controller help. This does not establish screen-reader support, complete
remapping, text scaling, color-blind certification or accessibility compliance.

**Responsive GM day checkpoints:** the measured baseline was approximately
3.8 seconds for the first full save and 5.6 seconds with backup on this cloud CPU;
all 992 fixture simulations took about 13 ms. The UI now retains the current
season until the worker atomically saves the next day; a failure leaves the live
season and valid previous disk save intact. Duplicate UI/session operations are
blocked until completion. The screen continues processing while saving and shows
its actual busy status. Atomic validation/checksum/backup behavior is retained.
Closing the scene externally joins the finite worker; force-killing the process
still relies on the existing atomic-file recovery rules. Total disk save latency
is not claimed faster. Isolated remeasurement recorded about 105 ms of main-thread
launch work and 5.75 seconds total asynchronous work; snapshot copying can still
cause a short hitch. The opening-day and completed-season profiles have different
fixture-result counts and are not a consumer-frame-rate comparison. Initial season creation/resume and some other save paths
remain synchronous. A background game-data worker is not an unattended Codex task.

**Measurement:** `tools/profile_gm.gd` writes `build/gm-profile.json` and uses a
throwaway build save. It never touches the real GM slot. Figures describe one
Linux cloud workload, not consumer hardware, actual rendered FPS or a Windows/Deck
performance promise. Evidence and exact measured values are in
verification/research-implementation-20261020.json.

## JPEG progress evidence

All pictures are actual 1440×900 Godot renders using Mesa softpipe, captured as
JPEG directly by `Image.save_jpg`. No generated concept art or fake gameplay.
Preferences toggles in the after image are deliberately enabled and saved to an
isolated capture path; the marker strip is explicitly labeled as a preview.
The GM images show a real isolated worker save, then its completed day.

- [Before preferences](screenshots/research-before-20261020.jpg)
- [After: visibility and comfort](screenshots/research-after-20261020.jpg)
- [GM checkpoint in progress](screenshots/research-saving-20261020.jpg)
- [GM checkpoint completed](screenshots/research-saved-20261020.jpg)

Full arena rendering remains blocked by the native allocator failure documented
in HOCKEY_AUDIO.md. Headless camera/projection/actual-goal tests validate behavior,
not fresh 3D visual quality. No additional plugin is required for this pass:
Godot already provides focus controls, profiling/timing, threads and image export.
Physical-controller/human comfort sessions and broader resolution checks remain
open; hardware testing will add more value than an unrelated free plugin.
