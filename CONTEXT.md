# claude-usage

A native macOS menu-bar app that monitors Claude Code and Codex CLI usage in real time, focused on rate-limit anxiety, productivity tracking, and live agent observability.

## What this project is

A long-running `LSUIElement` Swift app (no Dock icon, status-bar only) that reads local Claude Code and Codex CLI session data and surfaces three rate-limit gauges plus, post-V1, live-agent observability and productivity history.

Source of truth for usage data is the **local filesystem** — Anthropic and OpenAI do not expose subscription-tier rate-limit consumption via public API.

## Key terms

- **5h rolling window** — Anthropic Claude Max budget that counts cost-equivalent usage over the trailing 5 hours from the first message after a previous window closed. Resets dynamically, not on the clock.
- **Weekly window** — Both Anthropic ($100 Max) and OpenAI (ChatGPT Plus) impose a 7-day rolling cap.
- **API-cost-equivalent** — Our scoring model for Claude. Each assistant turn's tokens × Anthropic's published per-MTok prices = USD-equivalent cost, summed into rolling windows. Anthropic markets Max plans as "Nx the API value," so this proxy tracks the underlying (undocumented) algorithm.
- **Liveness signal** — Detection that an agent is actively generating right now. Two sources: hook push (Unix socket) and FSEvent file-tail fallback.
- **Hooks** — Both Claude Code (`~/.claude/settings.json` `hooks` block) and Codex CLI (`~/.codex/hooks.json`) support running shell commands on session events (`SessionStart`, `PreToolUse`, `Stop`, etc.).

## Source-of-truth files (data layer inputs)

- **Claude Code transcripts**: `~/.claude/projects/<encoded-cwd>/<session-uuid>.jsonl`. Each assistant turn line contains `message.usage` with `input_tokens`, `output_tokens`, `cache_creation_input_tokens`, `cache_read_input_tokens`, plus `message.model`.
- **Codex transcripts**: `~/.codex/sessions/YYYY/MM/DD/rollout-<iso>-<uuid>.jsonl`. Each `event_msg` with `payload.type == "token_count"` carries `rate_limits.primary` (300min window) and `rate_limits.secondary` (10080min weekly window), each with `used_percent`, `resets_at`, and `plan_type`. **OpenAI exposes the rate-limit state directly — we read it, not model it.**
- **Codex SQLite**: `~/.codex/state_5.sqlite` `threads` table has `tokens_used` per thread plus model, cwd, git_*.

## Key asymmetry (load-bearing)

- **Codex side is oracle-accurate** (OpenAI's own `used_percent` numbers).
- **Claude side is calibrated estimate** (no rate-limit field in the JSONL; we infer from cost-equivalent against an assumed plan ceiling).
- The UI surfaces this distinction subtly — Codex gauges are absolute, Claude gauges are "≈".

## Key external constraint

**vibe-island already occupies the hook system on this machine.** `~/.claude/settings.json` has 7+ hook events wired to `~/.vibe-island/bin/vibe-island-bridge`; `~/.codex/hooks.json` has 3. Any hook integration this app installs **must merge into existing arrays, never replace** — hook events accept arrays of commands, so coexistence is straightforward but requires JSON-merge logic.

## Stack & layout

- Swift + SwiftUI (with AppKit for `NSStatusItem` / `NSPopover` / `FSEventStream`).
- GRDB.swift for SQLite access. Cache at `~/Library/Application Support/com.<user>.claude-usage/usage.sqlite`.
- Bundled JSON pricing table, refreshable.
- GitHub Actions for signed + notarized release. Homebrew Cask formula for distribution. MIT, public from day 1.

## Plans modeled

- Anthropic: **Claude Max $100 (5×)** — 5h rolling + weekly windows.
- OpenAI: **ChatGPT Plus** — weekly Codex cap (and surfaces primary 5h window).
- API-key (pay-as-you-go) mode is out of scope for V1 (no rate-limit anxiety axis there).

## Further reading

- [docs/design.md](docs/design.md) — full design summary, V1 scope, post-V1 backlog, all 18 decisions captured from the initial brainstorming.
