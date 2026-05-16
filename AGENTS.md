# Agents

Instructions for AI coding agents working in this repo.

Start by reading [CONTEXT.md](CONTEXT.md) for the project's domain vocabulary, source-of-truth data layout, and key external constraints. Then [docs/design.md](docs/design.md) for the V1 scope and full architecture.

## Agent skills

### Issue tracker

Issues live as GitHub issues at [EmmanuelOluwafemi/claude-usage](https://github.com/EmmanuelOluwafemi/claude-usage). Use the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Default canonical label strings (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `CONTEXT.md` and one `docs/adr/` at the repo root. See `docs/agents/domain.md`.
