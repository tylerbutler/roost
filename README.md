# roost

Phoenix channel wire protocol helpers for Gleam.

> **Status:** pre-1.0. API unstable. Not published on Hex until 1.0.

## Availability

`roost` will not be published on Hex until 1.0. There is intentionally no
Hex install command yet.

Until the first stable release, add it as a Git dependency in `gleam.toml`.
Pin `ref` to a commit, tag, or branch that matches the API you are testing.

```toml
[dependencies]
roost = { git = "https://github.com/tylerbutler/roost.git", ref = "main" }
```

## Quick start

```gleam
import gleam/json
import gleam/option.{Some}
import roost

pub fn join_message() {
  roost.encode(
    join_ref: Some("1"),
    ref: Some("1"),
    topic: "room:lobby",
    event: "phx_join",
    payload: json.object([#("name", json.string("alice"))]),
  )
}
```

## What it does

- Encodes Phoenix channel wire frames:
  `[join_ref, ref, topic, event, payload]`.
- Decodes Phoenix channel wire frames into typed values.
- Provides constants for Phoenix reserved events and heartbeat topic.
- Provides helpers for heartbeat and reply frames.

## What it doesn't do

- Open WebSocket connections.
- Manage channel processes, refs, reconnects, or heartbeats.
- Depend on Gluegun, Beryl, Mist, OTP, or any transport runtime.

## JavaScript and TypeScript clients

`roost` targets Erlang/OTP only. It is not intended to be a JavaScript or
TypeScript Phoenix client.

For a full browser or Node.js Phoenix client, prefer the official Phoenix
JavaScript client. It already handles WebSocket lifecycle, channel state,
refs, push replies, timeouts, heartbeats, reconnects, rejoins, and Presence.
Those client responsibilities intentionally live outside `roost`.

## Development

```sh
just deps          # Download dependencies
just build         # Build the project
just test          # Run tests
just check         # Type check
just format        # Format source
just ci            # format-check, check, test, build-strict
just docs          # Build docs
```
