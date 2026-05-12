# roost

Phoenix-channel WebSocket client for Gleam, built on [Gluegun](https://github.com/tylerbutler/gluegun).

Pairs with [Beryl](https://github.com/tylerbutler/beryl) on the server side, but speaks the standard Phoenix wire protocol so it works against any Phoenix-compatible server.

> **Status:** pre-0.1. API unstable.

## Install

```sh
gleam add roost
```

Erlang target only (inherited from Gluegun and Gun).

## Quick start

```gleam
import gleam/io
import roost

pub fn main() {
  let assert Ok(channel) =
    roost.connect(
      host: "localhost",
      port: 4000,
      path: "/socket/websocket",
      topic: "room:lobby",
      payload: roost.empty_payload(),
    )

  let assert Ok(_) = roost.push(channel, "new_msg", roost.empty_payload())

  case roost.receive(channel) {
    Ok(frame) -> io.debug(frame)
    Error(_) -> io.println("receive failed")
  }

  let assert Ok(_) = roost.close(channel)
}
```

## What it does

- Opens a WebSocket connection via Gluegun.
- Sends `phx_join` with your topic and payload.
- Tracks `join_ref` / `ref` for reply correlation.
- Runs a 30s heartbeat actor in the background.
- Decodes server pushes and replies into typed `IncomingFrame` values.

## What it doesn't do (yet)

- TLS / `wss://`.
- Reconnect / backoff.
- Automatic channel rejoin after disconnect.
- Pluggable wire codec (Phoenix-only for now).

## Development

```sh
just deps         # Download dependencies
just build        # Build the project
just test         # Run tests
just check        # Type check
just format       # Format source
just ci           # format-check, check, test, build-strict
```
