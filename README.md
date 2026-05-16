# claude-usage

A native macOS menu-bar app that monitors Claude Code and Codex CLI usage in real time — rate-limit gauges, productivity tracking, and live agent observability.

**Status:** Pre-V1 scaffolding. The full design is in [docs/design.md](docs/design.md). Domain context, key terms, and the source-of-truth data layout are in [CONTEXT.md](CONTEXT.md).

## V1 scope

Three rate-limit gauges in a menu-bar popover: **5h Claude · Weekly Claude · Weekly Codex**. Color-coded status icon, reset-in countdowns, notifications at 80% and 95% per window. Codex gauges are oracle-accurate (read directly from `~/.codex/sessions/**.jsonl` `token_count` events); Claude gauges are API-cost-equivalent estimates (parsed from `~/.claude/projects/**.jsonl` `message.usage` blocks).

## Stack

Swift + SwiftUI + AppKit. `LSUIElement=true`. GRDB.swift for SQLite cache at `~/Library/Application Support/com.<user>.claude-usage/`. Targeted distribution: GitHub Releases + Homebrew Cask, notarized.

## License

[MIT](LICENSE).
