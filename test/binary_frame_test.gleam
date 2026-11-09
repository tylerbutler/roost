import gleam/option.{None, Some}
import roost/frame

pub fn encode_client_push_test() {
  let assert True =
    binary_push()
    |> frame.encode(direction: frame.ClientToServer)
    == Ok(
      frame.BinaryData(<<
        0,
        2,
        3,
        5,
        5,
        "12":utf8,
        "123":utf8,
        "topic":utf8,
        "event":utf8,
        101,
        102,
        103,
      >>),
    )
}

pub fn encode_server_push_test() {
  let assert True =
    frame.Push(
      join_ref: Some("12"),
      ref: None,
      topic: "topic",
      event: "event",
      payload: frame.BinaryPayload(<<101, 102, 103>>),
    )
    |> frame.encode(direction: frame.ServerToClient)
    == Ok(
      frame.BinaryData(<<
        0,
        2,
        5,
        5,
        "12":utf8,
        "topic":utf8,
        "event":utf8,
        101,
        102,
        103,
      >>),
    )
}

pub fn encode_server_reply_test() {
  let assert True =
    frame.Reply(
      join_ref: Some("12"),
      ref: "123",
      topic: "topic",
      status: frame.StatusOk,
      response: frame.BinaryPayload(<<101, 102, 103>>),
    )
    |> frame.encode(direction: frame.ServerToClient)
    == Ok(
      frame.BinaryData(<<
        1,
        2,
        3,
        5,
        2,
        "12":utf8,
        "123":utf8,
        "topic":utf8,
        "ok":utf8,
        101,
        102,
        103,
      >>),
    )
}

pub fn encode_server_broadcast_test() {
  let assert True =
    frame.Broadcast(
      topic: "topic",
      event: "event",
      payload: frame.BinaryPayload(<<101, 102, 103>>),
    )
    |> frame.encode(direction: frame.ServerToClient)
    == Ok(
      frame.BinaryData(<<
        2,
        5,
        5,
        "topic":utf8,
        "event":utf8,
        101,
        102,
        103,
      >>),
    )
}

pub fn encode_counts_utf8_bytes_in_metadata_lengths_test() {
  let assert True =
    frame.Push(
      join_ref: None,
      ref: None,
      topic: "café",
      event: "é",
      payload: frame.BinaryPayload(<<>>),
    )
    |> frame.encode(direction: frame.ClientToServer)
    == Ok(frame.BinaryData(<<0, 0, 0, 5, 2, "café":utf8, "é":utf8>>))
}

pub fn encode_accepts_255_byte_metadata_and_rejects_256_bytes_test() {
  let assert Ok(_) =
    frame.Push(
      join_ref: None,
      ref: None,
      topic: repeat("a", 255),
      event: "e",
      payload: frame.BinaryPayload(<<>>),
    )
    |> frame.encode(direction: frame.ClientToServer)

  let assert True =
    frame.Push(
      join_ref: None,
      ref: None,
      topic: repeat("a", 256),
      event: "e",
      payload: frame.BinaryPayload(<<>>),
    )
    |> frame.encode(direction: frame.ClientToServer)
    == Error(frame.MetadataTooLong("topic", 256))
}

pub fn encode_rejects_non_byte_aligned_payloads_test() {
  let assert True =
    frame.Push(
      join_ref: None,
      ref: None,
      topic: "topic",
      event: "event",
      payload: frame.BinaryPayload(<<1:size(1)>>),
    )
    |> frame.encode(direction: frame.ClientToServer)
    == Error(frame.InvalidBinaryPayload)
}

pub fn decode_client_push_test() {
  let assert Ok(frame.Push(
    join_ref: Some("12"),
    ref: Some("123"),
    topic: "topic",
    event: "event",
    payload: frame.BinaryPayload(<<101, 102, 103>>),
  )) =
    frame.decode(
      frame.BinaryData(<<
        0,
        2,
        3,
        5,
        5,
        "12":utf8,
        "123":utf8,
        "topic":utf8,
        "event":utf8,
        101,
        102,
        103,
      >>),
      direction: frame.ClientToServer,
    )
  Nil
}

pub fn decode_server_push_test() {
  let assert Ok(frame.Push(
    join_ref: Some("12"),
    ref: None,
    topic: "topic",
    event: "event",
    payload: frame.BinaryPayload(<<101, 102, 103>>),
  )) =
    frame.decode(
      frame.BinaryData(<<
        0,
        2,
        5,
        5,
        "12":utf8,
        "topic":utf8,
        "event":utf8,
        101,
        102,
        103,
      >>),
      direction: frame.ServerToClient,
    )
  Nil
}

pub fn decode_server_reply_test() {
  let assert Ok(reply) =
    frame.decode(
      frame.BinaryData(<<
        1,
        2,
        3,
        5,
        2,
        "12":utf8,
        "123":utf8,
        "topic":utf8,
        "ok":utf8,
        101,
        102,
        103,
      >>),
      direction: frame.ServerToClient,
    )
  let assert frame.Reply(
    join_ref: Some("12"),
    ref: "123",
    topic: "topic",
    status: frame.StatusOk,
    response: frame.BinaryPayload(<<101, 102, 103>>),
  ) = reply

  let assert True = frame.matches_join_reply(reply, "123")
  let assert True = frame.reply_status(reply) == Ok(Nil)
}

pub fn decode_server_broadcast_test() {
  let assert Ok(frame.Broadcast(
    topic: "topic",
    event: "event",
    payload: frame.BinaryPayload(<<101, 102, 103>>),
  )) =
    frame.decode(
      frame.BinaryData(<<
        2,
        5,
        5,
        "topic":utf8,
        "event":utf8,
        101,
        102,
        103,
      >>),
      direction: frame.ServerToClient,
    )
  Nil
}

pub fn decode_maps_empty_refs_to_none_test() {
  let assert Ok(frame.Push(join_ref: None, ref: None, ..)) =
    frame.decode(
      frame.BinaryData(<<0, 0, 0, 1, 1, "t":utf8, "e":utf8>>),
      direction: frame.ClientToServer,
    )
  Nil
}

pub fn decode_rejects_unknown_and_directionally_invalid_kinds_test() {
  let assert Error(_) =
    frame.decode(frame.BinaryData(<<9>>), direction: frame.ServerToClient)

  let assert Error(_) =
    frame.decode(
      frame.BinaryData(<<1, 0, 0, 0, 0>>),
      direction: frame.ClientToServer,
    )
  Nil
}

pub fn decode_rejects_truncated_metadata_test() {
  let assert Error(_) =
    frame.decode(
      frame.BinaryData(<<0, 2, 5, 5, "12":utf8, "top":utf8>>),
      direction: frame.ServerToClient,
    )
  Nil
}

pub fn decode_rejects_invalid_utf8_metadata_test() {
  let assert Error(_) =
    frame.decode(
      frame.BinaryData(<<0, 1, 1, 1, 255, "t":utf8, "e":utf8>>),
      direction: frame.ServerToClient,
    )
  Nil
}

pub fn decode_rejects_non_byte_aligned_wire_data_test() {
  let assert True =
    frame.decode(
      frame.BinaryData(<<0:size(1)>>),
      direction: frame.ServerToClient,
    )
    == Error(frame.InvalidBinary(
      "Expected binary wire data to contain whole bytes",
    ))
}

fn binary_push() {
  frame.Push(
    join_ref: Some("12"),
    ref: Some("123"),
    topic: "topic",
    event: "event",
    payload: frame.BinaryPayload(<<101, 102, 103>>),
  )
}

fn repeat(value: String, times: Int) -> String {
  repeat_loop(value, times, "")
}

fn repeat_loop(value: String, remaining: Int, output: String) -> String {
  case remaining {
    0 -> output
    _ -> repeat_loop(value, remaining - 1, output <> value)
  }
}
