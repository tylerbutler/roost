# Agent instructions for roost

## Build, test, and lint commands

This is a Gleam package for Phoenix channel wire protocol helpers.

```sh
just deps          # gleam deps download
just build         # gleam build
just build-strict  # gleam build --warnings-as-errors
just check         # gleam check
just test          # gleam test
just format        # gleam format src test
just format-check  # gleam format --check src test
just docs          # gleam docs build
just ci            # format-check, check, test, build-strict
just main          # ci plus docs
```

Run a single Startest test:

```sh
gleam build
gleam test -- test/frame_test.gleam --test-name-filter="encodes a phx_join"
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

- Keep the package protocol-only. Do not add transport,
  channel lifecycle, heartbeat actors, ref counters, or runtime-specific APIs.
- Phoenix refs are `String` values on the wire. Any monotonic counter or ref
  generation belongs to the caller.
- Reserved Phoenix events are `phx_join`, `phx_leave`, `phx_reply`,
  `phx_error`, `phx_close`, `heartbeat`. Heartbeat topic is the literal
  `"phoenix"`.
- Tests use Startest with public describe functions ending in `_tests` under
  `test/` (matches the Gluegun and Beryl conventions).
- The wire codec is currently Phoenix-only. A future major version may expose
  a pluggable `Codec` similar to `beryl/wire/codec`.
