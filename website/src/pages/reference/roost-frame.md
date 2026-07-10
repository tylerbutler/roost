---
layout: ../../layouts/ReferenceLayout.astro
title: "roost/frame"
description: "Phoenix channel wire frame encoding and decoding."
referenceModules: [{"name":"roost","href":"/reference/roost/","description":"Phoenix channel wire protocol helpers for Gleam."},{"name":"roost/frame","href":"/reference/roost-frame/","description":"Phoenix channel wire frame encoding and decoding."}]
---

# `roost/frame`

Phoenix channel wire frame encoding and decoding.

 Text frames use Phoenix's JSON array format:

 ```
 [join_ref, ref, topic, event, payload]
 ```

 Binary frames use direction-specific headers followed by an opaque byte
 payload. roost models the direction explicitly because kind `0` has
 different client-to-server and server-to-client layouts.

## Types

### `DecodeError`

Errors emitted when decoding wire data.

```gleam
pub type DecodeError {
  InvalidJson(reason: String)
  InvalidFormat(reason: String)
  InvalidBinary(reason: String)
}
```

### `Direction`

The direction a frame travels over the socket.

```gleam
pub type Direction {
  ClientToServer
  ServerToClient
}
```

### `EncodeError`

Errors emitted when encoding a frame.

```gleam
pub type EncodeError {
  InvalidDirection(reason: String)
  InvalidBinaryPayload
  MetadataTooLong(
    field: String,
    size: Int
  )
}
```

### `Frame`

A normalised Phoenix channel frame.

 JSON does not preserve the distinction between a server push and a
 broadcast, so decoded non-reply text frames are represented as `Push`.

```gleam
pub type Frame(a) {
  Push(
    join_ref: option.Option(String),
    ref: option.Option(String),
    topic: String,
    event: String,
    payload: Payload(a)
  )
  Reply(
    join_ref: option.Option(String),
    ref: String,
    topic: String,
    status: ReplyStatus,
    response: Payload(a)
  )
  Broadcast(
    topic: String,
    event: String,
    payload: Payload(a)
  )
}
```

### `Payload`

A frame payload, parameterised by its JSON representation.

 Outbound frames use `json.Json`; decoded frames use `Dynamic`.

```gleam
pub type Payload(a) {
  JsonPayload(a)
  BinaryPayload(BitArray)
}
```

### `ReplyStatus`

Phoenix reply status.

```gleam
pub type ReplyStatus {
  StatusOk
  StatusError
  StatusOther(String)
}
```

### `WireData`

Encoded data to hand to, or received from, a transport.

 The caller is responsible for using the matching WebSocket text or binary
 opcode.

```gleam
pub type WireData {
  TextData(String)
  BinaryData(BitArray)
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

Decode Phoenix text or binary wire data.

```gleam
pub fn decode(
  WireData,
  direction: Direction
) -> Result(Frame(dynamic.Dynamic), DecodeError)
```

### `encode`

Encode a Phoenix frame as text or binary based on its payload.

```gleam
pub fn encode(
  Frame(json.Json),
  direction: Direction
) -> Result(WireData, EncodeError)
```

### `heartbeat`

Build a Phoenix heartbeat frame.

 Heartbeats use the reserved topic `"phoenix"` and event `"heartbeat"`,
 with an empty JSON object payload and no `join_ref`.

```gleam
pub fn heartbeat(String) -> Frame(json.Json)
```

### `is_system_event`

Check whether an event name is a Phoenix-reserved system event.

```gleam
pub fn is_system_event(String) -> Bool
```

### `matches_join_reply`

Check whether a frame is the `phx_reply` for the given join.

```gleam
pub fn matches_join_reply(
  Frame(a),
  String
) -> Bool
```

### `reply_status`

Interpret a Phoenix reply frame's status.

 Returns `Ok(Nil)` for an `"ok"` reply. Error replies use
 `response.reason` when the response is JSON and contains one, otherwise the
 status string.

```gleam
pub fn reply_status(Frame(dynamic.Dynamic)) -> Result(Nil, String)
```
