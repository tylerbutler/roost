//// Phoenix wire frame encoding and decoding.
////
//// Phoenix uses a JSON array format:
////
//// ```
//// [join_ref, ref, topic, event, payload]
//// ```
////
//// Both `join_ref` and `ref` may be `null`. The reserved heartbeat topic is
//// the literal string `"phoenix"`.

import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/result

/// Phoenix channel join event.
pub const join_event = "phx_join"

/// Phoenix channel leave event.
pub const leave_event = "phx_leave"

/// Phoenix reply event.
pub const reply_event = "phx_reply"

/// Phoenix channel error event.
pub const error_event = "phx_error"

/// Phoenix channel close event.
pub const close_event = "phx_close"

/// Phoenix heartbeat event.
pub const heartbeat_event = "heartbeat"

/// Phoenix heartbeat topic.
pub const heartbeat_topic = "phoenix"

/// A normalised inbound frame received from a Phoenix-compatible server.
///
/// The `payload` is kept as a `Dynamic` so callers can decode it with their
/// own schema.
pub type Incoming {
  Incoming(
    join_ref: Option(String),
    ref: Option(String),
    topic: String,
    event: String,
    payload: Dynamic,
  )
}

/// Errors emitted when decoding inbound frames.
pub type DecodeError {
  InvalidJson(reason: String)
  InvalidFormat(reason: String)
}

/// Phoenix reply status.
pub type ReplyStatus {
  StatusOk
  StatusError
}

/// Encode an outbound frame as a Phoenix wire JSON string.
pub fn encode(
  join_ref join_ref: Option(String),
  ref ref: Option(String),
  topic topic: String,
  event event: String,
  payload payload: json.Json,
) -> String {
  json.to_string(
    json.preprocessed_array([
      option_to_json(join_ref),
      option_to_json(ref),
      json.string(topic),
      json.string(event),
      payload,
    ]),
  )
}

/// Encode a Phoenix heartbeat frame.
///
/// Heartbeats use the reserved topic `"phoenix"` and event `"heartbeat"`,
/// with an empty object payload and no `join_ref`.
pub fn encode_heartbeat(ref: String) -> String {
  encode(
    join_ref: None,
    ref: Some(ref),
    topic: heartbeat_topic,
    event: heartbeat_event,
    payload: json.object([]),
  )
}

/// Encode a Phoenix reply frame.
pub fn encode_reply(
  join_ref join_ref: Option(String),
  ref ref: String,
  topic topic: String,
  status status: ReplyStatus,
  response response: json.Json,
) -> String {
  let status_string = case status {
    StatusOk -> "ok"
    StatusError -> "error"
  }

  encode(
    join_ref: join_ref,
    ref: Some(ref),
    topic: topic,
    event: reply_event,
    payload: json.object([
      #("status", json.string(status_string)),
      #("response", response),
    ]),
  )
}

/// Decode a Phoenix wire JSON string into an `Incoming`.
pub fn decode(text: String) -> Result(Incoming, DecodeError) {
  case json.parse(from: text, using: decode.list(of: decode.dynamic)) {
    Ok([join_ref, ref, topic, event, payload]) ->
      decode_fields(join_ref, ref, topic, event, payload)
    Ok(_) ->
      Error(InvalidFormat(
        "Expected array of 5 elements [join_ref, ref, topic, event, payload]",
      ))
    Error(json.UnexpectedEndOfInput) ->
      Error(InvalidJson("Unexpected end of input"))
    Error(json.UnexpectedByte(byte)) ->
      Error(InvalidJson("Unexpected byte: " <> byte))
    Error(json.UnexpectedSequence(seq)) ->
      Error(InvalidJson("Unexpected sequence: " <> seq))
    Error(json.UnableToDecode(_)) ->
      Error(InvalidFormat(
        "Expected array of 5 elements [join_ref, ref, topic, event, payload]",
      ))
  }
}

fn decode_fields(
  join_ref join_ref: Dynamic,
  ref ref: Dynamic,
  topic topic: Dynamic,
  event event: Dynamic,
  payload payload: Dynamic,
) -> Result(Incoming, DecodeError) {
  use join_ref <- result.try(decode_dynamic(
    join_ref,
    decode.optional(decode.string),
    "Expected join_ref to be a string or null",
  ))
  use ref <- result.try(decode_dynamic(
    ref,
    decode.optional(decode.string),
    "Expected ref to be a string or null",
  ))
  use topic <- result.try(decode_dynamic(
    topic,
    decode.string,
    "Expected topic to be a string",
  ))
  use event <- result.try(decode_dynamic(
    event,
    decode.string,
    "Expected event to be a string",
  ))
  Ok(Incoming(
    join_ref: join_ref,
    ref: ref,
    topic: topic,
    event: event,
    payload: payload,
  ))
}

fn decode_dynamic(
  data: Dynamic,
  decoder: decode.Decoder(a),
  error_message: String,
) -> Result(a, DecodeError) {
  data
  |> decode.run(decoder)
  |> result.replace_error(InvalidFormat(error_message))
}

/// Check whether an event name is a Phoenix-reserved system event.
pub fn is_system_event(event: String) -> Bool {
  event == join_event
  || event == leave_event
  || event == reply_event
  || event == error_event
  || event == close_event
  || event == heartbeat_event
}

fn option_to_json(opt: Option(String)) -> json.Json {
  case opt {
    None -> json.null()
    Some(s) -> json.string(s)
  }
}
