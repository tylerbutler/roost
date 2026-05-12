# Agent instructions for roost

## Build, test, and lint commands

This is a Gleam package targeting Erlang only.

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

`roost` is a typed Gleam client for the Phoenix channel wire protocol, built on
[Gluegun](https://github.com/tylerbutler/gluegun) (which wraps Erlang Gun). The package opens a WebSocket
connection to a Phoenix-compatible server, joins a channel, manages refs and
heartbeats, and surfaces server pushes as typed Gleam values.

The public API is split by concern:

- `src/roost.gleam` is a root facade that re-exports the most common channel
  lifecycle, push, receive, and close functions.
- `roost/frame.gleam` encodes/decodes the Phoenix wire array
  `[join_ref, ref, topic, event, payload]`.
- `roost/ref.gleam` is a monotonic ref counter actor — Phoenix refs are
  strings (e.g. `"1"`, `"2"`).
- `roost/channel.gleam` is the opaque `Channel` type and its lifecycle
  (`join`, `push`, `receive`, `close`).
- `roost/heartbeat.gleam` runs a 30s heartbeat actor that pushes
  `{topic: "phoenix", event: "heartbeat"}` frames.
- `roost/error.gleam` is the typed error surface — wraps Gluegun errors and
  adds Phoenix-specific failure modes (`JoinRejected`, `ChannelClosed`, etc.).

Gluegun owns the WebSocket transport (`gluegun/websocket.Socket`,
`websocket.connect`, `websocket.send_text`, `websocket.close`). Roost is
framing-only — it never reaches past the Socket abstraction.

## Key conventions

- Erlang target only. Gluegun is Erlang-only and `gleam.toml` sets `target = "erlang"`.
- Public operations return `Result(_, error.RoostError)`. Map underlying
  `GluegunError` values through `error.from_gluegun/1`.
- Phoenix refs are `String`. The internal ref counter produces monotonic ints
  but they are serialised as `int.to_string` when crossing the wire.
- Reserved Phoenix events are `phx_join`, `phx_leave`, `phx_reply`,
  `phx_error`, `phx_close`, `heartbeat`. Heartbeat topic is the literal
  `"phoenix"`.
- Tests use Startest with public describe functions ending in `_tests` under
  `test/` (matches the Gluegun and Beryl conventions).
- The wire codec is currently Phoenix-only. A future major version may expose
  a pluggable `Codec` similar to `beryl/wire/codec`.
