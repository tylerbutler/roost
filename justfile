# Gleam Project Tasks

# === ALIASES ===
alias b := build
alias t := test
alias f := format
alias c := check
alias d := docs
alias cl := change
alias td := trellis-doctor

default:
    @just --list

# === DEPENDENCIES ===

# Download project dependencies
deps:
    gleam deps download

# Install the optional Erlang codec benchmark toolchain and dependencies
bench-codec-deps:
    cd benchmarks/codec && mise install elixir
    cd benchmarks/codec && mise exec -- mix local.hex --force --if-missing
    cd benchmarks/codec && mise exec -- gleam deps download

# Validate benchmark fixtures without measuring performance
bench-codec-check:
    cd benchmarks/codec && mise exec -- gleam format --check src dev test
    cd benchmarks/codec && mise exec -- gleam build --warnings-as-errors
    cd benchmarks/codec && mise exec -- gleam test

# Measure codec calls locally; first run bench-codec-deps
bench-codec:
    git rev-parse HEAD
    git status --short
    cd benchmarks/codec && mise exec -- gleam --version
    cd benchmarks/codec && mise exec -- elixir --version
    cd benchmarks/codec && mise exec -- gleam run -m roost_codec_bench

# === BUILD ===

# Build project
build:
    gleam build

# Build with warnings as errors
build-strict:
    gleam build --target erlang --warnings-as-errors
    gleam build --target javascript --warnings-as-errors

# === TESTING ===

# Run all tests
test:
    gleam test --target erlang
    gleam test --target javascript

# Check release workflow safety without GitHub writes
test-release:
    python3 -B -m unittest discover -s test -p release_workflow_test.py

# === CODE QUALITY ===

# Format source code
format:
    gleam format src test

# Check formatting without changes
format-check:
    gleam format --check src test

# Type check without building
check:
    gleam check --target erlang
    gleam check --target javascript

# === DOCUMENTATION ===

# Build documentation
docs:
    gleam docs build

# Generate website reference docs from Gleam docs metadata
site-reference: docs
    cd website && pnpm generate:reference

# Build website
site-build: site-reference
    cd website && pnpm build

# === CHANGELOG ===

# Create a new changelog entry
[positional-arguments]
change *ARGS:
    trellis changelog new "$@"

# Preview unreleased changelog
[positional-arguments]
changelog-preview *ARGS:
    trellis version plan "$@"

# Apply pending versions and regenerate CHANGELOG.md
[positional-arguments]
changelog *ARGS:
    trellis version apply "$@"

# Validate the release workspace
trellis-doctor:
    trellis doctor

# === MAINTENANCE ===

# Remove build artifacts
clean:
    rm -rf build

# === CI ===

# Run code and release configuration checks
ci: format-check check test test-release build-strict trellis-doctor

# Alias for PR checks
alias pr := ci

# Run extended checks for main branch
main: ci site-build
