//// Phoenix channel wire protocol helpers for Gleam.
////
//// This module is the public protocol facade. It forwards to `roost/frame`
//// for Phoenix wire frame encoding, decoding, heartbeat frames, reply frames,
//// and reserved system-event checks.

import gleam/json
import gleam/option.{type Option}
import roost/frame.{type DecodeError, type Incoming, type ReplyStatus}

/// Encode an outbound Phoenix wire frame.
pub fn encode(
  join_ref join_ref: Option(String),
  ref ref: Option(String),
  topic topic: String,
  event event: String,
  payload payload: json.Json,
) -> String {
  frame.encode(join_ref:, ref:, topic:, event:, payload:)
}

/// Decode a Phoenix wire JSON string into an inbound frame.
pub fn decode(text: String) -> Result(Incoming, DecodeError) {
  frame.decode(text)
}

/// Encode a Phoenix heartbeat frame.
pub fn encode_heartbeat(ref: String) -> String {
  frame.encode_heartbeat(ref)
}

/// Encode a Phoenix reply frame.
pub fn encode_reply(
  join_ref join_ref: Option(String),
  ref ref: String,
  topic topic: String,
  status status: ReplyStatus,
  response response: json.Json,
) -> String {
  frame.encode_reply(join_ref:, ref:, topic:, status:, response:)
}

/// Check whether an event name is a Phoenix-reserved system event.
pub fn is_system_event(event: String) -> Bool {
  frame.is_system_event(event)
}
