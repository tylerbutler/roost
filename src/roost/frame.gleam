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
    topic: "phoenix",
    event: "heartbeat",
    payload: json.object([]),
  )
}

/// Decode a Phoenix wire JSON string into an `Incoming`.
pub fn decode(text: String) -> Result(Incoming, DecodeError) {
  let frame_decoder = {
    use join_ref <- decode.subfield([0], decode.optional(decode.string))
    use ref <- decode.subfield([1], decode.optional(decode.string))
    use topic <- decode.subfield([2], decode.string)
    use event <- decode.subfield([3], decode.string)
    use payload <- decode.subfield([4], decode.dynamic)
    decode.success(Incoming(
      join_ref: join_ref,
      ref: ref,
      topic: topic,
      event: event,
      payload: payload,
    ))
  }

  case json.parse(from: text, using: frame_decoder) {
    Ok(frame) -> Ok(frame)
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

/// Check whether an event name is a Phoenix-reserved system event.
pub fn is_system_event(event: String) -> Bool {
  case event {
    "phx_join"
    | "phx_leave"
    | "phx_reply"
    | "phx_error"
    | "phx_close"
    | "heartbeat" -> True
    _ -> False
  }
}

fn option_to_json(opt: Option(String)) -> json.Json {
  case opt {
    None -> json.null()
    Some(s) -> json.string(s)
  }
}
