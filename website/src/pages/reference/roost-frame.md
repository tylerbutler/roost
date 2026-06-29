---
layout: ../../layouts/ReferenceLayout.astro
title: "roost/frame"
description: "Phoenix wire frame encoding and decoding."
referenceModules: [{"name":"roost","href":"/reference/roost/","description":"Phoenix channel wire protocol helpers for Gleam."},{"name":"roost/frame","href":"/reference/roost-frame/","description":"Phoenix wire frame encoding and decoding."}]
---

# `roost/frame`

Phoenix wire frame encoding and decoding.

 Phoenix uses a JSON array format:

 ```
 [join_ref, ref, topic, event, payload]
 ```

 Both `join_ref` and `ref` may be `null`. The reserved heartbeat topic is
 the literal string `"phoenix"`.

## Types

### `DecodeError`

Errors emitted when decoding inbound frames.

```gleam
pub type DecodeError {
  InvalidJson(reason: String)
  InvalidFormat(reason: String)
}
```

### `Incoming`

A normalised inbound frame received from a Phoenix-compatible server.

 The `payload` is kept as a `Dynamic` so callers can decode it with their
 own schema.

```gleam
pub type Incoming {
  Incoming(
    join_ref: option.Option(String),
    ref: option.Option(String),
    topic: String,
    event: String,
    payload: dynamic.Dynamic
  )
}
```

### `ReplyStatus`

Phoenix reply status.

```gleam
pub type ReplyStatus {
  StatusOk
  StatusError
}
```

## Constants

### `close_event`

Phoenix channel close event.

```gleam
pub const close_event: String
```

### `error_event`

Phoenix channel error event.

```gleam
pub const error_event: String
```

### `heartbeat_event`

Phoenix heartbeat event.

```gleam
pub const heartbeat_event: String
```

### `heartbeat_topic`

Phoenix heartbeat topic.

```gleam
pub const heartbeat_topic: String
```

### `join_event`

Phoenix channel join event.

```gleam
pub const join_event: String
```

### `leave_event`

Phoenix channel leave event.

```gleam
pub const leave_event: String
```

### `reply_event`

Phoenix reply event.

```gleam
pub const reply_event: String
```

## Functions

### `decode`

Decode a Phoenix wire JSON string into an `Incoming`.

```gleam
pub fn decode(String) -> Result(Incoming, DecodeError)
```

### `encode`

Encode an outbound frame as a Phoenix wire JSON string.

```gleam
pub fn encode(
  join_ref: option.Option(String),
  ref: option.Option(String),
  topic: String,
  event: String,
  payload: json.Json
) -> String
```

### `encode_heartbeat`

Encode a Phoenix heartbeat frame.

 Heartbeats use the reserved topic `"phoenix"` and event `"heartbeat"`,
 with an empty object payload and no `join_ref`.

```gleam
pub fn encode_heartbeat(String) -> String
```

### `encode_reply`

Encode a Phoenix reply frame.

```gleam
pub fn encode_reply(
  join_ref: option.Option(String),
  ref: String,
  topic: String,
  status: ReplyStatus,
  response: json.Json
) -> String
```

### `is_system_event`

Check whether an event name is a Phoenix-reserved system event.

```gleam
pub fn is_system_event(String) -> Bool
```

### `matches_join_reply`

Check whether an inbound frame is the `phx_reply` for the given join.

 True when the event is `phx_reply` and the frame's `ref` matches the
 `join_ref` the join was sent with. This is the Phoenix correlation rule for
 pairing a join request with its reply.

```gleam
pub fn matches_join_reply(
  Incoming,
  String
) -> Bool
```

### `reply_status`

Interpret a Phoenix `phx_reply` payload's `status`.

 Returns `Ok(Nil)` when the status is `"ok"` (joined), or `Error(reason)`
 when the join was rejected. The reason comes from `response.reason` if
 present, otherwise the status string.

```gleam
pub fn reply_status(Incoming) -> Result(Nil, String)
```
