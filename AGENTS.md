# Agent instructions for roost

## Build, test, and lint commands

This is a Gleam package for Phoenix channel wire protocol helpers.

```sh
just deps          # gleam deps download
just build         # gleam build
just build-strict  # gleam build --warnings-as-errors
just check         # gleam check
just test          # Unitest on Erlang and JavaScript
just format        # gleam format src test
just format-check  # gleam format --check src test
just docs          # gleam docs build
just trellis-doctor # trellis doctor
just test-release  # Offline release workflow checks
just ci            # format-check, check, test, test-release, build-strict, trellis-doctor
just main          # ci plus site-build
```

Run a single Unitest test:

```sh
gleam test -- --test frame_test.text_encode_client_outbound_fixtures_test
```

## High-level architecture

`roost` is an Erlang-targeted Gleam package for encoding and decoding the
Phoenix channel wire protocol. It does not own sockets, channel processes,
reconnect behavior, or runtime supervision; callers provide transport and
process management.

The public API centers on:

- `src/roost.gleam` is the root protocol facade for encoding outbound frames,
  decoding inbound frames, building heartbeat and reply frames, and checking
  reserved Phoenix system events.
- `src/roost/frame.gleam` contains the Phoenix wire representation and codec for
  `[join_ref, ref, topic, event, payload]`, including `Incoming`,
  `DecodeError`, reply statuses, and reserved event constants.

## Key conventions

- Releases use Trellis 1.3.0 from `mise.toml`, exact `v{version}` Git tags, and
  GitHub Releases. Roost is `git_only` at all versions; do not add Hex publication.
- Use native Trellis release resumption and candidate continuation. Keep
  `.changes/release.toml` and candidate archives in release commits.

- Keep the package protocol-only. Do not add transport,
  channel lifecycle, heartbeat actors, ref counters, or runtime-specific APIs.
- Phoenix refs are `String` values on the wire. Any monotonic counter or ref
  generation belongs to the caller.
- Reserved Phoenix events are `phx_join`, `phx_leave`, `phx_reply`,
  `phx_error`, `phx_close`, `heartbeat`. Heartbeat topic is the literal
  `"phoenix"`.
- Tests use Unitest with public zero-argument functions ending in `_test` under
  `test/` and native Gleam assertions. Keep tests independent: Unitest randomizes
  their execution order; pass `--seed <int>` to reproduce an order.
- The wire codec is currently Phoenix-only. A future major version may expose
  a pluggable `Codec` similar to `beryl/wire/codec`.
