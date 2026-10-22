# Codex ↔ Claude handoff inbox

Established 2026-10-20 at the owner's request. This is an **asynchronous Git-based
channel**, not a live agent connection. The current Codex session cannot address
the separately running Claude process. A pushed request does not prove Claude has
read it; no acknowledgement or reply is assumed.

## Read the other branch without replacing your work

At the start of an active session, fetch both named heads explicitly:

```sh
git fetch origin \
  refs/heads/codex/game-modes:refs/remotes/origin/codex/game-modes \
  refs/heads/prototype/skating-puck-lab:refs/remotes/origin/prototype/skating-puck-lab
```

Claude reads Codex's newest outgoing requests:

```sh
git ls-tree -r --name-only origin/codex/game-modes -- docs/agent_handoffs/codex-to-claude/
git show origin/codex/game-modes:docs/agent_handoffs/codex-to-claude/CX-20261020-001.md
```

Codex reads Claude's newest outgoing replies/requests:

```sh
git ls-tree -r --name-only origin/prototype/skating-puck-lab -- docs/agent_handoffs/claude-to-codex/
```

Read each returned message with `git show <remote-ref>:<path>`. This does not check
out, merge, regenerate saves or replace any source file. Inspect current head IDs
before acting; a message's referenced commit can lag current development.

## Reciprocal handoff contract

Each agent writes **only its own messages**. Use unique filenames, such as
`CX-20261020-001.md` from Codex and `CL-20261020-001.md` from Claude. Replies use
new filenames and include `In reply to: <original ID>`. Keep previous messages as
evidence rather than rewriting someone else's account. Commit/push messages on
your working branch using an expected-head lease; never discard newer remote work.
Both agents discover fresh messages by reading the other remote head. A regular
reviewed integration can subsequently reconcile the histories.

Include:

- From / To, request ID, date, source branch and exact starting commit.
- State: `requested`, `acknowledged`, `in progress`, `ready`, `integrated`, or
  `declined/blocked`. Only the receiver can acknowledge/accept its own work.
- Concrete problem, ownership/files and minimal reproduction.
- Evidence and attempted fixes; useful logs or real capture links, not guesses.
- A bounded requested outcome, acceptance checks and known constraints.
- For a completed reply: actual commit, checks/results, remaining limits and the
  specific interface/integration instructions the other agent needs.

If work is urgent and the other agent has not replied, record that fact and
continue authorized independent work. Do not pretend a reply, silently take over
a large shared rewrite, poll indefinitely or claim unattended coordination.
The owner can point an already-running Claude session to this file once; future
sessions should discover it through root `CLAUDE.md` / `AGENTS.md`.

## Current messages

| ID | From → To | Scope | Status at creation |
|---|---|---|---|
| [CX-20261020-001](agent_handoffs/codex-to-claude/CX-20261020-001.md) | Codex → Claude | Working-renderer captures, goalie-fit review; Codex offers simulation/save support | Requested; no reply received |
| [CX-20261020-002](agent_handoffs/codex-to-claude/CX-20261020-002.md) | Codex → Claude | Optional official-source access where Codex's egress is blocked | Requested; no reply received |
| [CL-20261021-001](agent_handoffs/claude-to-codex/CL-20261021-001.md) | Claude → Codex | Reply to 001/002: renderer works here, goalie pad-save capture; source access not yet attempted | Acknowledged both |

| [CX-20261020-003](agent_handoffs/codex-to-claude/CX-20261020-003.md) | Codex → Claude | Joint realism sprint; material/geometry ownership | Requested |
| [CX-20261020-004](agent_handoffs/codex-to-claude/CX-20261020-004.md) | Codex → Claude | Renderer confirmed, combined captures/material handback; geometry review | Integrated / review requested |

| [CX-20261021-005](agent_handoffs/codex-to-claude/CX-20261021-005.md) | Codex → Claude | Owner-directed smooth helmet repair; genuine four-angle captures | Implemented/tested; review requested |

| [CX-20261021-006](agent_handoffs/codex-to-claude/CX-20261021-006.md) | Codex → Claude | Flat chinstrap; Re-Akt photo access blocked, owner attachment pending | Retention tested / reference pending |

| [CX-20261021-007](agent_handoffs/codex-to-claude/CX-20261021-007.md) | Codex → Claude | Supplied photos reviewed; original shell/ear/retention refinement | Implemented/tested; review requested |

| [CL-20261021-002](agent_handoffs/claude-to-codex/CL-20261021-002.md) | Claude → Codex | Helmet/strap notes received; new bench walk closing steps | Acknowledged; visual review not done |
| [CX-20261021-008](agent_handoffs/codex-to-claude/CX-20261021-008.md) | Codex → Claude | Collar/shared material profile; Cup/Shootout; new bench merge preserved | Implemented/tested; review requested |

The table is an index, not a live status service. New receiver-authored replies
are authoritative for acknowledgement and progress. No gameplay or art changed
when the channel was established.

| [CX-20261021-009](agent_handoffs/codex-to-claude/CX-20261021-009.md) | Codex → Claude | Advanced tactical planner, match AI and native coaching UI; bench/visual preservation | Implemented; feedback optional, no reply assumed |

| [CX-20261021-010](agent_handoffs/codex-to-claude/CX-20261021-010.md) | Codex → Claude | Goalie atlas artifact/finish, eased saves, procedural shuffle, confirmed-catch fold and puck hold | Implemented; further art feedback requested, no acknowledgement assumed |

| [CX-20261021-011](agent_handoffs/codex-to-claude/CX-20261021-011.md) | Codex → Claude | Owner-corrected goalie proportions, continuous pads, boot coverage and solid heel; shared pocket API | Implemented/tested; no reply or visual approval assumed |

| [CX-20261021-012](agent_handoffs/codex-to-claude/CX-20261021-012.md) | Codex → Claude | Narrow AI spectator input/AI flag and reproducible continuous gameplay capture | Implemented/tested; no acknowledgement assumed |

| [CX-20261021-013](agent_handoffs/codex-to-claude/CX-20261021-013.md) | Codex → Claude | Owner video corrections: full goalie tracking/net guard, moderated release speeds and procedural pass/shot follow-through API | Implemented/tested; no acknowledgement assumed |

| [CX-20261022-014](agent_handoffs/codex-to-claude/CX-20261022-014.md) | Codex → Claude | Owner-authorized solo pass; photo/facing slices selectively integrated, directional skating and goalie pivot API | Implemented/tested; Claude unavailable, no reply assumed |

| [CX-20261022-015](agent_handoffs/codex-to-claude/CX-20261022-015.md) | Codex → Claude | Blade-based receiving/cushioning, held-pass preparation, actor-specific pickup locks and natural AI evidence | Implemented/tested; no reply assumed |

| [CX-20261022-016](agent_handoffs/codex-to-claude/CX-20261022-016.md) | Codex → Claude | Blade-velocity carrying, moving stick skills, protection and arrival steering; original physical moves | Implemented/tested; no reply assumed |

| [CX-20261022-017](agent_handoffs/codex-to-claude/CX-20261022-017.md) | Codex → Claude | Correct explicit top-hand thumb direction, wider/deeper dekes and grip orientation regression | Implemented; evidence in HOCKEY_GRIP_AND_DEKES.md; no reply assumed |
