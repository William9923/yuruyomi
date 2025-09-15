# Yuruyomi Development Makefile
.PHONY: dev format lint test test-all ci-check build docs help install

# Default target
.DEFAULT_GOAL := help

help: ## Show this help message
	@echo "Yuruyomi Development Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Examples:"
	@echo "  make dev          # Start development environment"
	@echo "  make test         # Run unit tests"
	@echo "  make ci-check     # Run all CI checks locally"

## Development Commands
dev-backend: ## Run only the backend server
	devenv shell dev-backend

dev-frontend: ## Run only the frontend (requires backend running)
	devenv shell dev-frontend

dev-both: ## Run both frontend and backend
	devenv shell dev-both

debug: ## Run development environment with debug mode
	devenv shell debug

## Code Quality Commands
format: ## Format all code (Rust)
	devenv shell format

lint: ## Run linters and fix issues (Rust + Lua)
	devenv shell lint

check-format: ## Check code formatting without fixing
	devenv shell check-format

check-lint: ## Check linting without fixing
	devenv shell check-lint

## Testing Commands
test: ## Run unit tests (backend + frontend)
	devenv shell test

test-all: ## Run all tests including E2E
	devenv shell test-all

test-frontend: ## Run only frontend tests
	devenv shell test-frontend

test-e2e: ## Run only E2E tests
	devenv shell test-e2e

ci-check: ## Run full CI validation locally
	devenv shell ci-check

## Build Commands
build: ## Build all targets (aarch64, desktop, kindle, kindlehf)
	nix build .#aarch64 .#desktop .#kindle .#kindlehf

build-desktop: ## Build desktop target only
	nix build .#desktop

build-schema: ## Build settings schema
	nix build .#settings-schema

## Documentation & Utilities
docs: ## Start documentation server
	devenv shell docs

prepare-sql: ## Prepare SQL queries for compilation
	devenv shell prepare-sql-queries

## Quick Development Workflow
check: check-format check-lint test ## Quick local validation before commit

clean: ## Clean build artifacts
	rm -rf build/
	rm -rf result*
	cd backend && cargo clean

## Environment Setup
setup: ## Initial setup (fetch dependencies)
	nix develop --command bash -c "echo 'Environment ready!'"
