//// Phoenix channel wire frame encoding and decoding.
////
//// Text frames use Phoenix's JSON array format:
////
//// ```
//// [join_ref, ref, topic, event, payload]
//// ```
////
//// Binary frames use direction-specific headers followed by an opaque byte
//// payload. roost models the direction explicitly because kind `0` has
//// different client-to-server and server-to-client layouts.

import gleam/bit_array
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
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

const push_kind = 0

const reply_kind = 1

const broadcast_kind = 2

/// The direction a frame travels over the socket.
pub type Direction {
  ClientToServer
  ServerToClient
}

/// Encoded data to hand to, or received from, a transport.
///
/// The caller is responsible for using the matching WebSocket text or binary
/// opcode.
pub type WireData {
  TextData(String)
  BinaryData(BitArray)
}

/// A frame payload, parameterised by its JSON representation.
///
/// Outbound frames use `json.Json`; decoded frames use `Dynamic`.
pub type Payload(json) {
  JsonPayload(json)
  BinaryPayload(BitArray)
}

/// A normalised Phoenix channel frame.
///
/// JSON does not preserve the distinction between a server push and a
/// broadcast, so decoded non-reply text frames are represented as `Push`.
pub type Frame(json) {
  Push(
    join_ref: Option(String),
    ref: Option(String),
    topic: String,
    event: String,
    payload: Payload(json),
  )
  Reply(
    join_ref: Option(String),
    ref: String,
    topic: String,
    status: ReplyStatus,
    response: Payload(json),
  )
  Broadcast(topic: String, event: String, payload: Payload(json))
}

/// Errors emitted when encoding a frame.
pub type EncodeError {
  InvalidDirection(reason: String)
  InvalidBinaryPayload
  MetadataTooLong(field: String, size: Int)
}

/// Errors emitted when decoding wire data.
pub type DecodeError {
  InvalidJson(reason: String)
  InvalidFormat(reason: String)
  InvalidBinary(reason: String)
}

/// Phoenix reply status.
pub type ReplyStatus {
  StatusOk
  StatusError
  StatusOther(String)
}

/// Encode a Phoenix frame as text or binary based on its payload.
pub fn encode(
  frame: Frame(json.Json),
  direction direction: Direction,
) -> Result(WireData, EncodeError) {
  case frame {
    Push(join_ref, ref, topic, event, JsonPayload(payload)) ->
      encode_text_push(join_ref, ref, topic, event, payload)
      |> TextData
      |> Ok
    Reply(join_ref, ref, topic, status, JsonPayload(response)) ->
      case direction {
        ClientToServer ->
          Error(InvalidDirection("Clients cannot send Phoenix reply frames"))
        ServerToClient ->
          encode_text_reply(join_ref, ref, topic, status, response)
          |> TextData
          |> Ok
      }
    Broadcast(topic, event, JsonPayload(payload)) ->
      case direction {
        ClientToServer ->
          Error(InvalidDirection("Clients cannot send Phoenix broadcast frames"))
        ServerToClient ->
          encode_text_push(None, None, topic, event, payload)
          |> TextData
          |> Ok
      }
    Push(join_ref, ref, topic, event, BinaryPayload(payload)) ->
      case direction {
        ClientToServer ->
          encode_client_push(join_ref, ref, topic, event, payload)
        ServerToClient -> encode_server_push(join_ref, topic, event, payload)
      }
      |> result.map(BinaryData)
    Reply(join_ref, ref, topic, status, BinaryPayload(response)) ->
      case direction {
        ClientToServer ->
          Error(InvalidDirection("Clients cannot send Phoenix reply frames"))
        ServerToClient ->
          encode_server_reply(join_ref, ref, topic, status, response)
          |> result.map(BinaryData)
      }
    Broadcast(topic, event, BinaryPayload(payload)) ->
      case direction {
        ClientToServer ->
          Error(InvalidDirection("Clients cannot send Phoenix broadcast frames"))
        ServerToClient ->
          encode_server_broadcast(topic, event, payload)
          |> result.map(BinaryData)
      }
  }
}

/// Decode Phoenix text or binary wire data.
pub fn decode(
  data: WireData,
  direction direction: Direction,
) -> Result(Frame(Dynamic), DecodeError) {
  case data {
    TextData(text) -> decode_text(text, direction)
    BinaryData(bits) -> decode_binary(bits, direction)
  }
}

/// Build a Phoenix heartbeat frame.
///
/// Heartbeats use the reserved topic `"phoenix"` and event `"heartbeat"`,
/// with an empty JSON object payload and no `join_ref`.
pub fn heartbeat(ref: String) -> Frame(json.Json) {
  Push(
    join_ref: None,
    ref: Some(ref),
    topic: heartbeat_topic,
    event: heartbeat_event,
    payload: JsonPayload(json.object([])),
  )
}

/// Check whether a frame is the `phx_reply` for the given join.
pub fn matches_join_reply(frame: Frame(a), join_ref: String) -> Bool {
  case frame {
    Reply(ref: ref, ..) -> ref == join_ref
    _ -> False
  }
}

/// Interpret a Phoenix reply frame's status.
///
/// Returns `Ok(Nil)` for an `"ok"` reply. Error replies use
/// `response.reason` when the response is JSON and contains one, otherwise the
/// status string.
pub fn reply_status(frame: Frame(Dynamic)) -> Result(Nil, String) {
  case frame {
    Reply(status: StatusOk, ..) -> Ok(Nil)
    Reply(status:, response:, ..) -> {
      let status = reply_status_to_string(status)
      case response {
        JsonPayload(response) ->
          response
          |> decode.run(decode.at(["reason"], decode.string))
          |> result.unwrap(status)
          |> Error
        BinaryPayload(_) -> Error(status)
      }
    }
    _ -> Error("Expected a Phoenix reply frame")
  }
}

/// Check whether an event name is a Phoenix-reserved system event.
pub fn is_system_event(event: String) -> Bool {
  [
    join_event,
    leave_event,
    reply_event,
    error_event,
    close_event,
    heartbeat_event,
  ]
  |> list.contains(event)
}

fn encode_text_push(
  join_ref: Option(String),
  ref: Option(String),
  topic: String,
  event: String,
  payload: json.Json,
) -> String {
  json.to_string(
    json.preprocessed_array([
      json.nullable(join_ref, of: json.string),
      json.nullable(ref, of: json.string),
      json.string(topic),
      json.string(event),
      payload,
    ]),
  )
}

fn encode_text_reply(
  join_ref: Option(String),
  ref: String,
  topic: String,
  status: ReplyStatus,
  response: json.Json,
) -> String {
  encode_text_push(
    join_ref,
    Some(ref),
    topic,
    reply_event,
    json.object([
      #("status", json.string(reply_status_to_string(status))),
      #("response", response),
    ]),
  )
}

fn decode_text(
  text: String,
  direction: Direction,
) -> Result(Frame(Dynamic), DecodeError) {
  case json.parse(from: text, using: decode.list(of: decode.dynamic)) {
    Ok([join_ref, ref, topic, event, payload]) ->
      decode_text_fields(join_ref, ref, topic, event, payload, direction)
    Ok(_) -> Error(InvalidFormat(text_frame_error()))
    Error(json.UnexpectedEndOfInput) ->
      Error(InvalidJson("Unexpected end of input"))
    Error(json.UnexpectedByte(byte)) ->
      Error(InvalidJson("Unexpected byte: " <> byte))
    Error(json.UnexpectedSequence(sequence)) ->
      Error(InvalidJson("Unexpected sequence: " <> sequence))
    Error(json.UnableToDecode(_)) -> Error(InvalidFormat(text_frame_error()))
  }
}

fn decode_text_fields(
  join_ref: Dynamic,
  ref: Dynamic,
  topic: Dynamic,
  event: Dynamic,
  payload: Dynamic,
  direction: Direction,
) -> Result(Frame(Dynamic), DecodeError) {
  use join_ref <- result.try(decode_frame_field(
    join_ref,
    decode.optional(decode.string),
    "Expected join_ref to be a string or null",
  ))
  use ref <- result.try(decode_frame_field(
    ref,
    decode.optional(decode.string),
    "Expected ref to be a string or null",
  ))
  use topic <- result.try(decode_frame_field(
    topic,
    decode.string,
    "Expected topic to be a string",
  ))
  use event <- result.try(decode_frame_field(
    event,
    decode.string,
    "Expected event to be a string",
  ))

  case event, direction {
    event, ServerToClient if event == reply_event ->
      decode_text_reply(join_ref, ref, topic, payload)
    event, ClientToServer if event == reply_event ->
      Error(InvalidFormat("Clients cannot send Phoenix reply frames"))
    _, _ ->
      Ok(Push(
        join_ref: join_ref,
        ref: ref,
        topic: topic,
        event: event,
        payload: JsonPayload(payload),
      ))
  }
}

fn decode_text_reply(
  join_ref: Option(String),
  ref: Option(String),
  topic: String,
  payload: Dynamic,
) -> Result(Frame(Dynamic), DecodeError) {
  use ref <- result.try(
    ref
    |> option.to_result(InvalidFormat(
      "Expected a Phoenix reply ref to be a string",
    )),
  )
  use status <- result.try(decode_frame_field(
    payload,
    decode.at(["status"], decode.string),
    "Expected a Phoenix reply payload with a string status",
  ))
  use response <- result.try(decode_frame_field(
    payload,
    decode.at(["response"], decode.dynamic),
    "Expected a Phoenix reply payload with a response",
  ))

  Ok(Reply(
    join_ref: join_ref,
    ref: ref,
    topic: topic,
    status: reply_status_from_string(status),
    response: JsonPayload(response),
  ))
}

fn decode_binary(
  bits: BitArray,
  direction: Direction,
) -> Result(Frame(Dynamic), DecodeError) {
  use _ <- result.try(
    validate_binary_payload(bits)
    |> result.map_error(fn(_) {
      InvalidBinary("Expected binary wire data to contain whole bytes")
    }),
  )

  case direction {
    ClientToServer -> decode_client_binary(bits)
    ServerToClient -> decode_server_binary(bits)
  }
}

fn decode_client_binary(bits: BitArray) -> Result(Frame(Dynamic), DecodeError) {
  case bits {
    <<kind, join_ref_size, ref_size, topic_size, event_size, body:bits>>
      if kind == push_kind
    -> decode_client_push(body, join_ref_size, ref_size, topic_size, event_size)
    <<kind, _rest:bits>> ->
      Error(InvalidBinary(
        "Expected client binary frame kind 0, got " <> int.to_string(kind),
      ))
    _ -> Error(InvalidBinary("Truncated client binary frame header"))
  }
}

fn decode_server_binary(bits: BitArray) -> Result(Frame(Dynamic), DecodeError) {
  case bits {
    <<kind, join_ref_size, topic_size, event_size, body:bits>>
      if kind == push_kind
    -> decode_server_push(body, join_ref_size, topic_size, event_size)
    <<kind, join_ref_size, ref_size, topic_size, status_size, body:bits>>
      if kind == reply_kind
    ->
      decode_server_reply(
        body,
        join_ref_size,
        ref_size,
        topic_size,
        status_size,
      )
    <<kind, topic_size, event_size, body:bits>> if kind == broadcast_kind ->
      decode_server_broadcast(body, topic_size, event_size)
    <<kind, _rest:bits>> ->
      Error(InvalidBinary(
        "Unknown server binary frame kind " <> int.to_string(kind),
      ))
    _ -> Error(InvalidBinary("Truncated server binary frame header"))
  }
}

fn decode_client_push(
  body: BitArray,
  join_ref_size: Int,
  ref_size: Int,
  topic_size: Int,
  event_size: Int,
) -> Result(Frame(Dynamic), DecodeError) {
  let sizes = [join_ref_size, ref_size, topic_size, event_size]
  use decoded <- result.try(
    decode_binary_fields(body, sizes, ["join_ref", "ref", "topic", "event"]),
  )
  let #(fields, payload) = decoded
  let assert [join_ref, ref, topic, event] = fields

  Ok(Push(
    join_ref: empty_as_none(join_ref),
    ref: empty_as_none(ref),
    topic: topic,
    event: event,
    payload: BinaryPayload(payload),
  ))
}

fn decode_server_push(
  body: BitArray,
  join_ref_size: Int,
  topic_size: Int,
  event_size: Int,
) -> Result(Frame(Dynamic), DecodeError) {
  let sizes = [join_ref_size, topic_size, event_size]
  use decoded <- result.try(
    decode_binary_fields(body, sizes, ["join_ref", "topic", "event"]),
  )
  let #(fields, payload) = decoded
  let assert [join_ref, topic, event] = fields

  Ok(Push(
    join_ref: empty_as_none(join_ref),
    ref: None,
    topic: topic,
    event: event,
    payload: BinaryPayload(payload),
  ))
}

fn decode_server_reply(
  body: BitArray,
  join_ref_size: Int,
  ref_size: Int,
  topic_size: Int,
  status_size: Int,
) -> Result(Frame(Dynamic), DecodeError) {
  let sizes = [join_ref_size, ref_size, topic_size, status_size]
  use decoded <- result.try(
    decode_binary_fields(body, sizes, ["join_ref", "ref", "topic", "status"]),
  )
  let #(fields, response) = decoded
  let assert [join_ref, ref, topic, status] = fields

  Ok(Reply(
    join_ref: empty_as_none(join_ref),
    ref: ref,
    topic: topic,
    status: reply_status_from_string(status),
    response: BinaryPayload(response),
  ))
}

fn decode_server_broadcast(
  body: BitArray,
  topic_size: Int,
  event_size: Int,
) -> Result(Frame(Dynamic), DecodeError) {
  let sizes = [topic_size, event_size]
  use decoded <- result.try(
    decode_binary_fields(body, sizes, ["topic", "event"]),
  )
  let #(fields, payload) = decoded
  let assert [topic, event] = fields

  Ok(Broadcast(topic: topic, event: event, payload: BinaryPayload(payload)))
}

fn decode_binary_fields(
  body: BitArray,
  sizes: List(Int),
  names: List(String),
) -> Result(#(List(String), BitArray), DecodeError) {
  let metadata_size = list.fold(sizes, 0, int.add)
  let body_size = bit_array.byte_size(body)

  use _ <- result.try(case metadata_size <= body_size {
    True -> Ok(Nil)
    False ->
      Error(InvalidBinary("Binary frame metadata exceeds available bytes"))
  })

  use fields <- result.try(decode_metadata_fields(body, sizes, names, 0, []))
  use payload <- result.try(
    bit_array.slice(body, at: metadata_size, take: body_size - metadata_size)
    |> result.replace_error(InvalidBinary("Unable to read binary frame payload")),
  )

  Ok(#(fields, payload))
}

fn decode_metadata_fields(
  body: BitArray,
  sizes: List(Int),
  names: List(String),
  offset: Int,
  decoded: List(String),
) -> Result(List(String), DecodeError) {
  case sizes, names {
    [], [] -> Ok(list.reverse(decoded))
    [size, ..sizes], [name, ..names] -> {
      use field_bits <- result.try(
        bit_array.slice(body, at: offset, take: size)
        |> result.replace_error(InvalidBinary("Unable to read binary " <> name)),
      )
      use field <- result.try(
        bit_array.to_string(field_bits)
        |> result.replace_error(InvalidBinary(
          "Expected binary " <> name <> " to be valid UTF-8",
        )),
      )
      decode_metadata_fields(body, sizes, names, offset + size, [
        field,
        ..decoded
      ])
    }
    _, _ -> Error(InvalidBinary("Mismatched binary metadata definition"))
  }
}

fn encode_client_push(
  join_ref: Option(String),
  ref: Option(String),
  topic: String,
  event: String,
  payload: BitArray,
) -> Result(BitArray, EncodeError) {
  use _ <- result.try(validate_binary_payload(payload))
  use join_ref <- result.try(encode_metadata(
    "join_ref",
    option_to_string(join_ref),
  ))
  use ref <- result.try(encode_metadata("ref", option_to_string(ref)))
  use topic <- result.try(encode_metadata("topic", topic))
  use event <- result.try(encode_metadata("event", event))

  Ok(
    bit_array.concat([
      <<push_kind, join_ref.0, ref.0, topic.0, event.0>>,
      join_ref.1,
      ref.1,
      topic.1,
      event.1,
      payload,
    ]),
  )
}

fn encode_server_push(
  join_ref: Option(String),
  topic: String,
  event: String,
  payload: BitArray,
) -> Result(BitArray, EncodeError) {
  use _ <- result.try(validate_binary_payload(payload))
  use join_ref <- result.try(encode_metadata(
    "join_ref",
    option_to_string(join_ref),
  ))
  use topic <- result.try(encode_metadata("topic", topic))
  use event <- result.try(encode_metadata("event", event))

  Ok(
    bit_array.concat([
      <<push_kind, join_ref.0, topic.0, event.0>>,
      join_ref.1,
      topic.1,
      event.1,
      payload,
    ]),
  )
}

fn encode_server_reply(
  join_ref: Option(String),
  ref: String,
  topic: String,
  status: ReplyStatus,
  response: BitArray,
) -> Result(BitArray, EncodeError) {
  use _ <- result.try(validate_binary_payload(response))
  use join_ref <- result.try(encode_metadata(
    "join_ref",
    option_to_string(join_ref),
  ))
  use ref <- result.try(encode_metadata("ref", ref))
  use topic <- result.try(encode_metadata("topic", topic))
  use status <- result.try(encode_metadata(
    "status",
    reply_status_to_string(status),
  ))

  Ok(
    bit_array.concat([
      <<reply_kind, join_ref.0, ref.0, topic.0, status.0>>,
      join_ref.1,
      ref.1,
      topic.1,
      status.1,
      response,
    ]),
  )
}

fn encode_server_broadcast(
  topic: String,
  event: String,
  payload: BitArray,
) -> Result(BitArray, EncodeError) {
  use _ <- result.try(validate_binary_payload(payload))
  use topic <- result.try(encode_metadata("topic", topic))
  use event <- result.try(encode_metadata("event", event))

  Ok(
    bit_array.concat([
      <<broadcast_kind, topic.0, event.0>>,
      topic.1,
      event.1,
      payload,
    ]),
  )
}

fn encode_metadata(
  field: String,
  value: String,
) -> Result(#(Int, BitArray), EncodeError) {
  let bits = bit_array.from_string(value)
  let size = bit_array.byte_size(bits)

  case size <= 255 {
    True -> Ok(#(size, bits))
    False -> Error(MetadataTooLong(field, size))
  }
}

fn validate_binary_payload(payload: BitArray) -> Result(Nil, EncodeError) {
  case int.modulo(bit_array.bit_size(payload), 8) {
    Ok(0) -> Ok(Nil)
    _ -> Error(InvalidBinaryPayload)
  }
}

fn decode_frame_field(
  field: Dynamic,
  decoder: decode.Decoder(a),
  error_message: String,
) -> Result(a, DecodeError) {
  field
  |> decode.run(decoder)
  |> result.replace_error(InvalidFormat(error_message))
}

fn reply_status_to_string(status: ReplyStatus) -> String {
  case status {
    StatusOk -> "ok"
    StatusError -> "error"
    StatusOther(status) -> status
  }
}

fn reply_status_from_string(status: String) -> ReplyStatus {
  case status {
    "ok" -> StatusOk
    "error" -> StatusError
    status -> StatusOther(status)
  }
}

fn option_to_string(value: Option(String)) -> String {
  case value {
    Some(value) -> value
    None -> ""
  }
}

fn empty_as_none(value: String) -> Option(String) {
  case value {
    "" -> None
    value -> Some(value)
  }
}

fn text_frame_error() -> String {
  "Expected array of 5 elements [join_ref, ref, topic, event, payload]"
}
