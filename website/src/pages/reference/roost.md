---
layout: ../../layouts/ReferenceLayout.astro
title: "roost"
description: "Phoenix channel wire protocol helpers for Gleam."
referenceModules: [{"name":"roost","href":"/reference/roost/","description":"Phoenix channel wire protocol helpers for Gleam."},{"name":"roost/frame","href":"/reference/roost-frame/","description":"Phoenix channel wire frame encoding and decoding."}]
---

# `roost`

Phoenix channel wire protocol helpers for Gleam.

 This module is the public protocol facade. It forwards to `roost/frame`
 for text and binary frame encoding, decoding, heartbeat construction,
 reply handling, and reserved system-event checks.

## Functions

### `decode`

Decode Phoenix text or binary wire data.

```gleam
pub fn decode(
  data: frame.WireData,
  direction: frame.Direction
) -> Result(frame.Frame(dynamic.Dynamic), frame.DecodeError)
```

### `encode`

Encode a Phoenix text or binary frame.

```gleam
pub fn encode(
  frame: frame.Frame(json.Json),
  direction: frame.Direction
) -> Result(frame.WireData, frame.EncodeError)
```

### `heartbeat`

Build a Phoenix heartbeat frame.

```gleam
pub fn heartbeat(String) -> frame.Frame(json.Json)
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
  frame.Frame(a),
  String
) -> Bool
```

### `reply_status`

Interpret a Phoenix reply frame's status.

```gleam
pub fn reply_status(frame.Frame(dynamic.Dynamic)) -> Result(Nil, String)
```
