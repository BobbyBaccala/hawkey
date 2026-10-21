# Original on-ice audio foundation

2026-10-20, America/Toronto. Alpha work on codex/game-modes / existing draft PR #2.

Replaced the short electronic impact beeps in Play Now and Practice with 33
original, reproducible mono PCM effects: three variants each for wrist shots,
slap shots, passes, boards, pads/body equipment, posts, netting, checks, controlled
skater stops, penalty whistles and goal horns. Noise transients, filtered resonance
and amplitude envelopes approximate the material/gesture of each event. These are
synthesized project assets, not hockey recordings, copied EA sounds or a claim of
finished professional sound design. Generator: tools/generate_hockey_audio.py.

The runtime preloads imported Godot WAV resources once into a 12-voice spatial
pool. Cues follow the puck/player/contact position, impact/release speed bounds
strength, variants cycle with small pitch variation, repeated contact cues are
rate-limited, and horn/whistle cues can preempt ordinary impacts. Ordinary cues
cannot steal those higher-priority voices. Ice support contacts are ignored;
net collisions and goal-frame contacts are classified separately. Pause freezes
voices and event scheduling. The SFX slider can mute cues and persists separately
from GM saves; old camera/dead-zone-only settings remain valid and gain the default
80% audio value in memory. No per-event audio generator or unbounded player creation.

Actual integration covers player and AI pass/shot releases, practice pass/shoot,
regular and shootout goalie contacts, physical board/post/net contacts, legal
checks/pokes, controlled-skater stop onset, penalty whistles and regular goals.
It does not provide continuous skate/glide loops, every AI stop, reception sounds,
contextual crowd layers/chants, commentary, music, every rule whistle or a distinct
shootout-result celebration. These remain explicit coverage/quality gaps.

Tests verify nonempty PCM, sample rate/format/duration, bounded amplitude, nonzero
signal energy, clean endpoints, distinct variants and byte-identical regeneration.
Native tests cover resource loading, spatial event coordinates, rate limits,
voice priorities, pause/mute, saved volume and real match shot/pass routing.
No automated test establishes whether these samples sound convincing, how well
hardware speakers/headphones reproduce them, or whether the overall mix is fun.
Human listening and comparison across devices remain necessary.

## Current cloud rendering diagnosis

The default Mesa llvmpipe 256-bit renderer previously trapped. A small native 2D
probe succeeded with LP_NATIVE_VECTOR_WIDTH=128, but actual preferences/arena
captures still aborted with a native allocator error (`malloc(): invalid size`).
Reducing raster threads, direct/single-thread scene modes and a Mobile/Vulkan
attempt did not produce a new arena image; the latter fell back to OpenGL here.
A diagnostic system-font substitution also failed, so no unproven font change was
committed. These are observed failures, not evidence of a fixed renderer or a
proven cause in game code. Default/software-renderer CPU performance is unmeasured.

Mesa `GALLIUM_DRIVER=softpipe` successfully rendered the actual current preferences
screen at 1440×900: [sound preferences](screenshots/realism-preferences-20261020.png).
No old arena image is presented as a new capture. Files/evidence:
verification/realism-audio-20261020.json. No hardware/controller, Windows/Deck,
packaged-export or AAA quality claim is made.
