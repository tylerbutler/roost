---
layout: ../../layouts/ReferenceLayout.astro
title: "roost"
description: "Phoenix channel wire protocol helpers for Gleam."
referenceModules: [{"name":"roost","href":"/reference/roost/","description":"Phoenix channel wire protocol helpers for Gleam."},{"name":"roost/frame","href":"/reference/roost-frame/","description":"Phoenix wire frame encoding and decoding."}]
---

# `roost`

Phoenix channel wire protocol helpers for Gleam.

 This module is the public protocol facade. It forwards to `roost/frame`
 for Phoenix wire frame encoding, decoding, heartbeat frames, reply frames,
 and reserved system-event checks.

## Functions

### `decode`

Decode a Phoenix wire JSON string into an inbound frame.

```gleam
pub fn decode(String) -> Result(frame.Incoming, frame.DecodeError)
```

### `encode`

Encode an outbound Phoenix wire frame.

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
  status: frame.ReplyStatus,
  response: json.Json
) -> String
```

### `is_system_event`

Check whether an event name is a Phoenix-reserved system event.

```gleam
pub fn is_system_event(String) -> Bool
```
