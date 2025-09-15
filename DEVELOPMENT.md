# Development Commands Quick Reference

This document provides a quick reference for all available development commands in Yuruyomi.

## Two Ways to Run Commands

You can use either:
1. **devenv shell commands** (recommended for Nix users)
2. **Make commands** (convenient shortcuts)

## Essential Commands

| Task | devenv shell | Make | Description |
|------|--------------|------|-------------|
| **Development** | `devenv shell dev` | `make dev` | Run KOReader with plugin |
| **Format** | `devenv shell format` | `make format` | Format all code |
| **Lint** | `devenv shell lint` | `make lint` | Run linters and fix issues |
| **Test** | `devenv shell test` | `make test` | Run unit tests |
| **Full Test** | `devenv shell test-all` | `make test-all` | Run all tests including E2E |
| **CI Check** | `devenv shell ci-check` | `make ci-check` | Full CI validation |

## Development Workflow

### Quick Start
```bash
# Format, lint, and test before commit
make ci-check
# or
devenv shell ci-check
```

### Individual Commands
```bash
# Start development
make dev

# Format code  
make format

# Run linters
make lint

# Run tests
make test              # Unit tests only
make test-all         # All tests including E2E
```

## Build Commands

```bash
# Build all targets
make build

# Build specific target
make build-desktop

# Build settings schema
make build-schema
```

## Advanced Commands

```bash
# Backend only
make dev-backend

# Frontend only (requires backend running)  
make dev-frontend

# Debug mode
make debug

# Documentation
make docs

# Clean build artifacts
make clean
```

## Help

```bash
# See all available make commands
make help

# See devenv available commands
devenv shell --help
```

## CI Integration

The GitHub workflows now:
- ✅ Run all tests including E2E before building
- ✅ Use updated actions (v4)
- ✅ Only require Prod environment for main branch pushes
- ✅ Upload test artifacts on failure

## Migration from Old Commands

| Old Command | New Equivalent |
|-------------|----------------|
| `./tools/dev-backend.sh` | `make dev-backend` |
| `cd backend && cargo fmt` | `make format` |
| `cd backend && cargo clippy` | `make lint` |
| Manual test running | `make test` or `make test-all` |

All commands work consistently across platforms and integrate with the existing Nix development environment.