# AGENTS.md - Yuruyomi Developer Guide

## Build Commands
- **Backend**: `./tools/dev-backend.sh [--debug] [--tcp]` or `make dev-backend`
- **Frontend**: `./tools/dev-frontend.sh` or `make dev-frontend` 
- **Full app**: `./tools/dev-both.sh` or `make dev-both`
- **Development**: `devenv shell dev` or `make dev`
- **Tests**: `devenv shell test` or `make test` (unit), `devenv shell test-all` or `make test-all` (all)
- **Single test**: `cargo test test_name`, `pytest tests/test_file.py::test_function`

## Code Quality Commands
- **Format**: `devenv shell format` or `make format`
- **Lint**: `devenv shell lint` or `make lint` 
- **Check format**: `devenv shell check-format` or `make check-format`
- **Check lint**: `devenv shell check-lint` or `make check-lint`
- **Full CI check**: `devenv shell ci-check` or `make ci-check`

## Build Targets
- **All targets**: `make build` or `nix build .#aarch64 .#desktop .#kindle .#kindlehf`
- **Desktop only**: `make build-desktop` or `nix build .#desktop`
- **Schema**: `make build-schema` or `nix build .#settings-schema`

## Code Style

### Rust
- Use `anyhow::Result<T>` for fallible operations
- SQLX queries: `sqlx::query_as!()` pattern
- Domain IDs: `SourceId -> MangaId -> ChapterId` hierarchy via `from_strings()`
- Async patterns: `tokio`, `futures::stream` for concurrency, pass `CancellationToken`
- Error handling: `thiserror` for custom errors, `anyhow` for application errors

### Lua (KOReader Plugin)
- Widget composition: `FrameContainer`, `InputContainer`, `VerticalGroup`
- Event handling: `registerTouchZones()`, return `true` to consume events
- Navigation: callback stacking in `self.paths = { { callback = onReturnCallback } }`
- Show widgets: `UIManager:show(widget)`, close with `UIManager:close(widget)`
- Use `_("text")` for translatable strings, `util.urlEncode()` for parameters