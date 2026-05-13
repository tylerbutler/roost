# roost

Phoenix channel wire protocol helpers for Gleam.

> **Status:** pre-0.1. API unstable.

## Install

```sh
gleam add roost
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

Gleam can compile this package to JavaScript, but `roost` is still only a
Phoenix wire-protocol codec. It can be useful as the codec inside a custom
JavaScript or TypeScript client, especially when you want runtime-neutral
protocol helpers.

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
