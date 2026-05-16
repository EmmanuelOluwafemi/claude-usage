# Design — claude-usage

Captured from the initial `/grill-me` brainstorming session. 18 decisions across product, architecture, and distribution. V1 scope is a strict subset of the full vision — every line of V1 code stays in V2.

---

## Product

### Goals (overall vision)
1. **Rate-limit anxiety** — "Am I about to hit my 5-hour Claude limit / weekly Codex cap?"
2. **Productivity / activity tracking** — "How many sessions, hours, projects today/this week?"
3. **Live agent observability** — "Which Claude/Codex agents are running RIGHT NOW, on what?"

Cost-awareness is explicitly **out of scope** (user is on subscriptions, not API pay-as-you-go).

### Plans modeled
- Anthropic: Claude Max $100 (5×) — 5h rolling + weekly windows.
- OpenAI: ChatGPT Plus — weekly Codex cap.

### V1 scope (ships first, ~1–2 weeks of focused Swift work)
Rate-limit gauges only:
- Three gauges: 5h Claude · Weekly Claude · Weekly Codex, each with reset-in countdowns.
- Menu-bar icon: ring + % of most-depleted window; color thresholds (green <60 / amber <85 / red ≥85).
- Popover: gauges + "Open full window" stub button.
- macOS notifications at 80% and 95% per window crossing.
- Settings pane: edit Claude ceilings, toggle notifications.
- Auto-recalibration: when a Claude limit-hit signature is observed in JSONL, anchor the ceiling downward.

### Post-V1 backlog (additive, no new pipelines)
- Active-agents section of the popover (live, with current model + tool + elapsed time).
- Hook-install consent flow (merges entries into existing `~/.claude/settings.json` and `~/.codex/hooks.json` alongside vibe-island).
- Today / week / per-project productivity rollups; 30-day retention.
- Stuck-agent notification at >10 min running.
- WidgetKit desktop / Notification Center extension (sharing data via App Group).
- Full window view with charts / sparklines.

---

## Architecture

### Stack
- Swift + SwiftUI (with AppKit for `NSStatusItem`, `NSPopover`, `FSEventStream`).
- `LSUIElement=true` — menu-bar app, no Dock icon.
- GRDB.swift for SQLite.
- Bundled JSON pricing table (refreshable).

### Surface
- **Menu-bar app primary** — status icon + popover.
- WidgetKit extension deferred to post-V1. When added, runs as a separate target sharing data via App Group container.

### Data layer

**Claude (calibrated estimate)**
- Source: `~/.claude/projects/<encoded-cwd>/<session-uuid>.jsonl`.
- FSEventStream watches the projects directory.
- For each new line with `type == "assistant"` (or message with assistant role), extract `message.usage` block: `input_tokens`, `output_tokens`, `cache_creation_input_tokens`, `cache_read_input_tokens`, `message.model`.
- Multiply by Anthropic's API list prices (per-MTok, per-model, per-token-type) → USD-equivalent cost.
- Accumulate into the 5h-rolling window and the weekly-rolling window.
- Compare to assumed plan ceilings (Max $100 ≈ $5 / 5h, ≈ $120 / week; tunable + auto-recalibrating).

**Codex (oracle-accurate)**
- Source: `~/.codex/sessions/YYYY/MM/DD/rollout-<iso>-<uuid>.jsonl`.
- FSEventStream watches the sessions tree.
- For each new line with `payload.type == "token_count"`, read `rate_limits.primary` (300min) and `rate_limits.secondary` (10080min) directly. Each has `used_percent`, `resets_at` (Unix timestamp), and `plan_type`.
- Use the most-recent observation as ground truth — OpenAI does the math for us.

**SQLite cache**
- Path: `~/Library/Application Support/com.<user>.claude-usage/usage.sqlite`.
- Tables:
  - `raw_events` — one row per Claude assistant turn (timestamp, session_id, model, input/output/cache tokens, computed cost-USD).
  - `codex_observations` — one row per Codex `token_count` event (timestamp, session_id, primary_pct, secondary_pct, primary_resets_at, secondary_resets_at).
  - `sessions` — Claude/Codex sessions metadata (start, last_seen, cwd, model_provider).
  - `daily_aggregates` — pre-computed rollups (lifetime retention; survives 30-day raw pruning).
  - `limits_state` — current 5h / weekly ceiling overrides; last calibration anchor.

### Liveness detection (V1 file-tail, post-V1 hooks)
- **V1**: FSEventStream + "appended within last 10s = active session."
- **Post-V1**: A local Unix socket server in the daemon. Hooks registered into `~/.claude/settings.json` (SessionStart, PreToolUse, PostToolUse, Stop, SessionEnd) and `~/.codex/hooks.json` (SessionStart, UserPromptSubmit, Stop) POST a JSON event to the socket. Authoritative push signal.
- **Hook coexistence**: must merge into existing arrays (vibe-island already occupies these). Each event's hook array gains an additional entry calling our bridge binary — never replace.

### Compute cadence
- Event-driven primarily (FSEvents file change + hook push when installed).
- 30-second heartbeat for "resets in Xh Ym" countdown refresh and stuck-agent threshold checks.

### Notifications
- 80% and 95% per-window thresholds (debounced — fire once per window crossing).
- Stuck-agent at >10 min (post-V1).
- `UNUserNotificationCenter`. Standard macOS notifications, click → opens popover.

---

## Modeling decisions

### Claude scoring: API-cost-equivalent
Each turn's tokens × Anthropic per-MTok prices (model-specific; cache reads heavily discounted) = USD. Sum over the 5h-rolling window and over the 7-day weekly window. Compare to plan ceilings.

### Claude budget calibration
- **Defaults** (community-empirical for $100 Max): ~$5 / 5h-window, ~$120 / week of API-equivalent. Both tunable in Settings.
- **Auto-recalibration**: when a limit-hit signature is observed in JSONL (e.g., assistant turn with `stop_reason: "max_tokens"` while at high %, or explicit 429 indicator), anchor the ceiling to match observed consumption at that moment.
- **Per-model pricing** is a bundled JSON; can be refreshed via GitHub-hosted file periodically.

### Codex scoring
No modeling. Use `rate_limits.{primary,secondary}.used_percent` from the most-recent `token_count` event. `resets_at` is Unix seconds — convert to countdown.

### History retention
- 30 days of raw events (pruned on a daily job).
- Lifetime daily aggregates (small footprint, useful for any future productivity views).

---

## UI

### Status-bar item
- Mini circular progress ring around app glyph + "% number" of most-depleted window.
- Color: green <60, amber <85, red ≥85.
- Pulses subtly when at least one agent is actively generating (post-V1).

### Popover (V1)
```
┌────────────────────────────────────────────────┐
│ USAGE                                          │
│                                                │
│  5h Claude    ████████▒▒▒  ≈73%  resets 1h12m │
│  Week Claude  ████▒▒▒▒▒▒▒  ≈41%  resets 3d 8h │
│  Week Codex   ██▒▒▒▒▒▒▒▒▒   22%  resets 4d 0h │
│                                                │
│                          [→ Open full window]  │
└────────────────────────────────────────────────┘
```

The `≈` prefix on Claude gauges (vs. no prefix on Codex) signals the oracle/estimated asymmetry.

### Popover (post-V1)
Adds an `ACTIVE AGENTS` section (per-project, with model + tool + elapsed) and a `TODAY` footer line (turns, sessions, $ equiv).

---

## Distribution

- **License**: MIT, public from day 1 (repo name `claude-usage` already suggests this).
- **Build & release**: GitHub Actions. Signs with Apple Developer ID ($99/yr), notarizes via Apple's notary service, attaches DMG to GitHub Release.
- **Install channels**: GitHub Release direct download + Homebrew Cask (formula submitted post-V1).
- **NOT App Store**: sandbox would block reads of `~/.claude/` and `~/.codex/`. Notarization only.

---

## Risks & mitigations

| Risk | Mitigation |
|---|---|
| Anthropic changes the JSONL `usage` schema | Single-file parser layer; one-line fix when it happens. ccusage/claude-monitor have weathered schema changes so far. |
| Anthropic changes per-token prices | Bundled JSON refreshable from a known URL. Calibration auto-anchors on observed limit-hits regardless of price drift. |
| OpenAI changes the `token_count.rate_limits` schema | Lower risk — it's already typed and structured. Mitigate same way: typed parser, easy swap. |
| vibe-island hook entries get overwritten by accident | Hook-install flow ALWAYS reads existing JSON, merges into the array, writes back. Idempotent. Diff shown to user before write. |
| Daemon misses events while asleep (clamshell, etc.) | FSEventStream supports historical replay via `since` IDs. Cold-start full-scan up to 5h ago on wake. |
| Calibration anchor drifts after Anthropic plan changes | Manual override in Settings; future "reset calibration" button. |

---

## Open questions (not blocking V1)

- Should the auto-recalibration anchor adjust upward too (when the user clearly *didn't* hit a limit by the time the ceiling predicted)? Probably yes, slowly, with a damping factor.
- For the Anthropic pricing JSON: bundle + OTA refresh, or just bundle and rely on app updates? Probably bundle + refresh from a GitHub raw URL daily.
- What's the precise signature for "Anthropic 429 / rate-limit hit" in the JSONL? Need to capture a real one to anchor the parser.
