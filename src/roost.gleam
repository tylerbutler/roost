//// Phoenix channel wire protocol helpers for Gleam.
////
//// This module is the public protocol facade. It forwards to `roost/frame`
//// for text and binary frame encoding, decoding, heartbeat construction,
//// reply handling, and reserved system-event checks.

import gleam/dynamic.{type Dynamic}
import gleam/json
import roost/frame.{
  type DecodeError, type Direction, type EncodeError, type Frame, type WireData,
}

/// Encode a Phoenix text or binary frame.
pub fn encode(
  frame frame: Frame(json.Json),
  direction direction: Direction,
) -> Result(WireData, EncodeError) {
  frame.encode(frame, direction:)
}

/// Decode Phoenix text or binary wire data.
pub fn decode(
  data data: WireData,
  direction direction: Direction,
) -> Result(Frame(Dynamic), DecodeError) {
  frame.decode(data, direction:)
}

/// Build a Phoenix heartbeat frame.
pub fn heartbeat(ref: String) -> Frame(json.Json) {
  frame.heartbeat(ref)
}

/// Check whether an event name is a Phoenix-reserved system event.
pub fn is_system_event(event: String) -> Bool {
  frame.is_system_event(event)
}

/// Check whether a frame is the `phx_reply` for the given join.
pub fn matches_join_reply(incoming: Frame(a), join_ref: String) -> Bool {
  frame.matches_join_reply(incoming, join_ref)
}

/// Interpret a Phoenix reply frame's status.
pub fn reply_status(incoming: Frame(Dynamic)) -> Result(Nil, String) {
  frame.reply_status(incoming)
}
