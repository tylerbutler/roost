import gleam/bit_array
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import roost
import roost/frame.{
  type Direction, type Frame, type WireData, BinaryData, BinaryPayload,
  Broadcast, ClientToServer, JsonPayload, Push, Reply, ServerToClient, StatusOk,
  TextData,
}

pub type Fixture {
  Fixture(
    label: String,
    direction: Direction,
    outgoing: Frame(json.Json),
    expected: Frame(Dynamic),
    wire: WireData,
  )
}

pub type Rejection {
  Rejection(
    label: String,
    direction: Direction,
    wire: WireData,
    expected: frame.DecodeError,
  )
}

pub fn text(size: Int) -> List(Fixture) {
  let payload = json.object([#("body", json.string(string.repeat("a", size)))])
  let encoded = json.to_string(payload)
  let assert Ok(dynamic) = json.parse(encoded, decode.dynamic)
  [
    Fixture(
      "text/push/client_to_server",
      ClientToServer,
      Push(Some("j1"), Some("r1"), "bench:codec", "echo", JsonPayload(payload)),
      Push(Some("j1"), Some("r1"), "bench:codec", "echo", JsonPayload(dynamic)),
      TextData("[\"j1\",\"r1\",\"bench:codec\",\"echo\"," <> encoded <> "]"),
    ),
    Fixture(
      "text/reply/server_to_client",
      ServerToClient,
      Reply(Some("j1"), "r1", "bench:codec", StatusOk, JsonPayload(payload)),
      Reply(Some("j1"), "r1", "bench:codec", StatusOk, JsonPayload(dynamic)),
      TextData(
        "[\"j1\",\"r1\",\"bench:codec\",\"phx_reply\","
        <> "{\"status\":\"ok\",\"response\":"
        <> encoded
        <> "}]",
      ),
    ),
    Fixture(
      "text/broadcast/server_to_client",
      ServerToClient,
      Broadcast("bench:codec", "echo", JsonPayload(payload)),
      Push(None, None, "bench:codec", "echo", JsonPayload(dynamic)),
      TextData("[null,null,\"bench:codec\",\"echo\"," <> encoded <> "]"),
    ),
  ]
  |> list.map(fn(input) { label_size(input, size) })
}

pub fn binary(size: Int) -> List(Fixture) {
  let payload =
    list.repeat(<<0, 255, 128, 1>>, size / 4)
    |> bit_array.concat
  [
    Fixture(
      "binary/push/client_to_server",
      ClientToServer,
      Push(
        Some("j1"),
        Some("r1"),
        "bench:codec",
        "echo",
        BinaryPayload(payload),
      ),
      Push(
        Some("j1"),
        Some("r1"),
        "bench:codec",
        "echo",
        BinaryPayload(payload),
      ),
      BinaryData(<<
        0, 2, 2, 11, 4, "j1":utf8, "r1":utf8, "bench:codec":utf8, "echo":utf8,
        payload:bits,
      >>),
    ),
    Fixture(
      "binary/push/server_to_client",
      ServerToClient,
      Push(Some("j1"), None, "bench:codec", "echo", BinaryPayload(payload)),
      Push(Some("j1"), None, "bench:codec", "echo", BinaryPayload(payload)),
      BinaryData(<<
        0, 2, 11, 4, "j1":utf8, "bench:codec":utf8, "echo":utf8, payload:bits,
      >>),
    ),
    Fixture(
      "binary/reply/server_to_client",
      ServerToClient,
      Reply(Some("j1"), "r1", "bench:codec", StatusOk, BinaryPayload(payload)),
      Reply(Some("j1"), "r1", "bench:codec", StatusOk, BinaryPayload(payload)),
      BinaryData(<<
        1, 2, 2, 11, 2, "j1":utf8, "r1":utf8, "bench:codec":utf8, "ok":utf8,
        payload:bits,
      >>),
    ),
    Fixture(
      "binary/broadcast/server_to_client",
      ServerToClient,
      Broadcast("bench:codec", "echo", BinaryPayload(payload)),
      Broadcast("bench:codec", "echo", BinaryPayload(payload)),
      BinaryData(<<2, 11, 4, "bench:codec":utf8, "echo":utf8, payload:bits>>),
    ),
  ]
  |> list.map(fn(input) { label_size(input, size) })
}

fn label_size(input: Fixture, size: Int) -> Fixture {
  let wire_size = case input.wire {
    TextData(text) -> bit_array.byte_size(bit_array.from_string(text))
    BinaryData(bits) -> bit_array.byte_size(bits)
  }
  Fixture(
    ..input,
    label: input.label
      <> " body_bytes="
      <> int.to_string(size)
      <> " wire_bytes="
      <> int.to_string(wire_size),
  )
}

pub fn all() -> List(Fixture) {
  list.flat_map([128, 4096, 65_536], fn(size) {
    list.append(text(size), binary(size))
  })
}

pub fn rejections() -> List(Rejection) {
  [
    Rejection(
      "text/reject/malformed_json/client_to_server",
      ClientToServer,
      TextData("["),
      frame.InvalidJson("Unexpected end of input"),
    ),
    Rejection(
      "text/reject/array_length/client_to_server",
      ClientToServer,
      TextData("[null,null]"),
      frame.InvalidFormat(
        "Expected array of 5 elements [join_ref, ref, topic, event, payload]",
      ),
    ),
    Rejection(
      "text/reject/topic_type/client_to_server",
      ClientToServer,
      TextData("[null,null,42,\"echo\",{}]"),
      frame.InvalidFormat("Expected topic to be a string"),
    ),
    Rejection(
      "binary/reject/truncated_metadata/client_to_server",
      ClientToServer,
      BinaryData(<<0, 0, 0, 11, 4, "short":utf8>>),
      frame.InvalidBinary("Binary frame metadata exceeds available bytes"),
    ),
    Rejection(
      "binary/reject/unknown_kind/server_to_client",
      ServerToClient,
      BinaryData(<<9>>),
      frame.InvalidBinary("Unknown server binary frame kind 9"),
    ),
    Rejection(
      "binary/reject/invalid_utf8/client_to_server",
      ClientToServer,
      BinaryData(<<0, 0, 0, 1, 1, 255, "e":utf8>>),
      frame.InvalidBinary("Expected binary topic to be valid UTF-8"),
    ),
  ]
}

pub fn oversized_topic() -> Frame(json.Json) {
  Push(None, None, string.repeat("a", 256), "echo", BinaryPayload(<<>>))
}

pub fn check(inputs: List(Fixture)) -> Nil {
  list.each(inputs, fn(input) {
    expect(
      input.label <> "/encode",
      roost.encode(input.outgoing, input.direction) == Ok(input.wire),
      "Encoded wire differs from the independent expected layout",
    )
    expect(
      input.label <> "/decode",
      roost.decode(input.wire, input.direction) == Ok(input.expected),
      "Decoded fields or complete payload differ",
    )
    case input.direction, input.wire, input.expected {
      ClientToServer, TextData(_), Push(..) ->
        expect(
          input.label <> "/server_decode",
          roost.decode(input.wire, ServerToClient) == Ok(input.expected),
          "Text push did not decode identically in the server direction",
        )
      _, _, _ -> Nil
    }
  })
}

pub fn check_rejections() -> Nil {
  list.each(rejections(), fn(input) {
    expect(
      input.label,
      roost.decode(input.wire, input.direction) == Error(input.expected),
      "Unexpected decode rejection",
    )
  })
  expect(
    "binary/reject/topic_bytes=256/client_to_server",
    roost.encode(oversized_topic(), ClientToServer)
      == Error(frame.MetadataTooLong("topic", 256)),
    "Oversized topic was not rejected with its byte size",
  )
}

pub fn check_boundaries() -> Nil {
  let assert Ok(null) = json.parse("null", decode.dynamic)
  let topic = string.repeat("a", 255)
  let inputs = [
    Fixture(
      "text/empty_refs_and_payload/client_to_server",
      ClientToServer,
      Push(Some(""), Some(""), "", "", JsonPayload(json.null())),
      Push(Some(""), Some(""), "", "", JsonPayload(null)),
      TextData("[\"\",\"\",\"\",\"\",null]"),
    ),
    Fixture(
      "binary/empty_refs_and_payload/client_to_server",
      ClientToServer,
      Push(Some(""), Some(""), "", "", BinaryPayload(<<>>)),
      Push(None, None, "", "", BinaryPayload(<<>>)),
      BinaryData(<<0, 0, 0, 0, 0>>),
    ),
    Fixture(
      "binary/omitted_ref/server_to_client",
      ServerToClient,
      Push(None, Some("ignored"), "", "", BinaryPayload(<<>>)),
      Push(None, None, "", "", BinaryPayload(<<>>)),
      BinaryData(<<0, 0, 0, 0>>),
    ),
    Fixture(
      "binary/utf8_metadata/client_to_server",
      ClientToServer,
      Push(None, None, "caf\u{e9}", "\u{e9}", BinaryPayload(<<255>>)),
      Push(None, None, "caf\u{e9}", "\u{e9}", BinaryPayload(<<255>>)),
      BinaryData(<<0, 0, 0, 5, 2, "caf\u{e9}":utf8, "\u{e9}":utf8, 255>>),
    ),
    Fixture(
      "binary/topic_bytes=255/client_to_server",
      ClientToServer,
      Push(None, None, topic, "e", BinaryPayload(<<>>)),
      Push(None, None, topic, "e", BinaryPayload(<<>>)),
      BinaryData(<<0, 0, 0, 255, 1, topic:utf8, "e":utf8>>),
    ),
  ]
  check(inputs)
  list.each(
    [
      #("ok", StatusOk),
      #("error", frame.StatusError),
      #("timeout", frame.StatusOther("timeout")),
    ],
    fn(status) {
      let #(text, canonical) = status
      check([
        Fixture(
          "text/status=" <> text <> "/server_to_client",
          ServerToClient,
          Reply(None, "", "", frame.StatusOther(text), JsonPayload(json.null())),
          Reply(None, "", "", canonical, JsonPayload(null)),
          TextData(
            "[null,\"\",\"\",\"phx_reply\",{\"status\":\""
            <> text
            <> "\",\"response\":null}]",
          ),
        ),
        Fixture(
          "binary/status=" <> text <> "/server_to_client",
          ServerToClient,
          Reply(None, "", "", frame.StatusOther(text), BinaryPayload(<<>>)),
          Reply(None, "", "", canonical, BinaryPayload(<<>>)),
          BinaryData(<<1, 0, 0, 0, string.byte_size(text), text:utf8>>),
        ),
      ])
    },
  )
}

pub fn preflight(inputs: List(Fixture)) -> Nil {
  check(inputs)
  check_rejections()
  check_boundaries()
}

fn expect(label: String, condition: Bool, reason: String) -> Nil {
  let assert True = condition as { label <> ": " <> reason }
  Nil
}
