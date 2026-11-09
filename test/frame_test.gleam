import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import phoenix_channel_fixtures/frame as fixtures
import roost
import roost/frame

pub fn text_encode_client_outbound_fixtures_test() {
  fixtures.client_outbound()
  |> list.each(fn(case_) {
    let assert True =
      frame.Push(
        join_ref: case_.join_ref,
        ref: case_.ref,
        topic: case_.topic,
        event: case_.event,
        payload: frame.JsonPayload(case_.payload),
      )
      |> frame.encode(direction: frame.ClientToServer)
      == Ok(frame.TextData(case_.encoded))
  })
}

pub fn text_encode_server_outbound_fixtures_test() {
  fixtures.server_outbound()
  |> list.each(fn(case_) {
    let assert True =
      frame.Push(
        join_ref: case_.join_ref,
        ref: case_.ref,
        topic: case_.topic,
        event: case_.event,
        payload: frame.JsonPayload(case_.payload),
      )
      |> frame.encode(direction: frame.ServerToClient)
      == Ok(frame.TextData(case_.encoded))
  })
}

pub fn text_encode_reply_fixtures_test() {
  fixtures.replies()
  |> list.each(fn(case_) {
    let assert True =
      frame.Reply(
        join_ref: case_.join_ref,
        ref: case_.ref,
        topic: case_.topic,
        status: reply_status(case_.status),
        response: frame.JsonPayload(case_.response),
      )
      |> frame.encode(direction: frame.ServerToClient)
      == Ok(frame.TextData(case_.encoded))
  })
}

pub fn text_encode_broadcast_as_common_json_array_test() {
  let assert True =
    frame.Broadcast(
      topic: "room:lobby",
      event: "tick",
      payload: frame.JsonPayload(json.object([#("n", json.int(42))])),
    )
    |> frame.encode(direction: frame.ServerToClient)
    == Ok(frame.TextData("[null,null,\"room:lobby\",\"tick\",{\"n\":42}]"))
}

pub fn text_encode_rejects_client_reply_and_broadcast_test() {
  let assert Error(_) =
    frame.Reply(
      join_ref: None,
      ref: "1",
      topic: "room:lobby",
      status: frame.StatusOk,
      response: frame.JsonPayload(json.object([])),
    )
    |> frame.encode(direction: frame.ClientToServer)

  let assert Error(_) =
    frame.Broadcast(
      topic: "room:lobby",
      event: "tick",
      payload: frame.JsonPayload(json.object([])),
    )
    |> frame.encode(direction: frame.ClientToServer)
  Nil
}

pub fn text_decode_client_outbound_fixtures_test() {
  fixtures.client_outbound()
  |> list.each(fn(case_) {
    let assert Ok(frame.Push(
      join_ref: join_ref,
      ref: ref,
      topic: topic,
      event: event,
      payload: frame.JsonPayload(payload),
    )) =
      frame.decode(
        frame.TextData(case_.encoded),
        direction: frame.ClientToServer,
      )

    let assert True = join_ref == case_.join_ref
    let assert True = ref == case_.ref
    let assert True = topic == case_.topic
    let assert True = event == case_.event
    let assert True = payload == fixture_payload(case_.payload)
  })
}

pub fn text_decode_server_pushes_as_push_frames_test() {
  fixtures.server_outbound()
  |> list.each(fn(case_) {
    let assert Ok(frame.Push(
      join_ref: join_ref,
      ref: ref,
      topic: topic,
      event: event,
      payload: frame.JsonPayload(payload),
    )) =
      frame.decode(
        frame.TextData(case_.encoded),
        direction: frame.ServerToClient,
      )

    let assert True = join_ref == case_.join_ref
    let assert True = ref == case_.ref
    let assert True = topic == case_.topic
    let assert True = event == case_.event
    let assert True = payload == fixture_payload(case_.payload)
  })
}

pub fn text_decode_normalises_phx_reply_frames_test() {
  fixtures.replies()
  |> list.each(fn(case_) {
    let assert Ok(frame.Reply(
      join_ref: join_ref,
      ref: ref,
      topic: topic,
      status: status,
      response: frame.JsonPayload(response),
    )) =
      frame.decode(
        frame.TextData(case_.encoded),
        direction: frame.ServerToClient,
      )

    let assert True = join_ref == case_.join_ref
    let assert True = ref == case_.ref
    let assert True = topic == case_.topic
    let assert True = status == reply_status(case_.status)
    let assert True = response == fixture_payload(case_.response)
  })
}

pub fn text_decode_classifies_invalid_frame_fixtures_test() {
  fixtures.invalid_frames()
  |> list.each(fn(case_) {
    let assert Error(reason) =
      frame.decode(
        frame.TextData(case_.encoded),
        direction: frame.ClientToServer,
      )
    let assert True = decode_reason_matches(case_.reason, reason)
  })
}

pub fn text_round_trips_json_push_test() {
  let outgoing =
    frame.Push(
      join_ref: Some("3"),
      ref: Some("5"),
      topic: "doc:abc",
      event: "update",
      payload: frame.JsonPayload(json.object([#("delta", json.string("text"))])),
    )
  let assert Ok(encoded) =
    frame.encode(outgoing, direction: frame.ClientToServer)
  let assert Ok(frame.Push(
    join_ref: Some("3"),
    ref: Some("5"),
    topic: "doc:abc",
    event: "update",
    ..,
  )) = frame.decode(encoded, direction: frame.ClientToServer)
  Nil
}

pub fn heartbeat_builds_phoenix_frame_test() {
  let assert True =
    frame.heartbeat("42")
    |> frame.encode(direction: frame.ClientToServer)
    == Ok(frame.TextData("[null,\"42\",\"phoenix\",\"heartbeat\",{}]"))
}

pub fn reply_matches_join_ref_test() {
  let assert Ok(reply) =
    frame.decode(
      frame.TextData(
        "[\"1\",\"1\",\"room:lobby\",\"phx_reply\",{\"status\":\"ok\",\"response\":{}}]",
      ),
      direction: frame.ServerToClient,
    )
  let assert True = frame.matches_join_reply(reply, "1")
  let assert False = frame.matches_join_reply(reply, "2")
}

pub fn reply_matching_rejects_non_reply_frames_test() {
  let assert Ok(push) =
    frame.decode(
      frame.TextData("[\"1\",\"1\",\"room:lobby\",\"new_msg\",{}]"),
      direction: frame.ClientToServer,
    )
  let assert False = frame.matches_join_reply(push, "1")
}

pub fn reply_status_returns_ok_for_successful_replies_test() {
  let assert Ok(reply) =
    frame.decode(
      frame.TextData(
        "[\"1\",\"1\",\"room:lobby\",\"phx_reply\",{\"status\":\"ok\",\"response\":{}}]",
      ),
      direction: frame.ServerToClient,
    )
  let assert True = frame.reply_status(reply) == Ok(Nil)
}

pub fn reply_status_uses_response_reason_for_json_errors_test() {
  let assert Ok(reply) =
    frame.decode(
      frame.TextData(
        "[\"1\",\"1\",\"room:lobby\",\"phx_reply\",{\"status\":\"error\",\"response\":{\"reason\":\"unauthorized\"}}]",
      ),
      direction: frame.ServerToClient,
    )
  let assert True = frame.reply_status(reply) == Error("unauthorized")
}

pub fn reply_status_preserves_custom_status_strings_test() {
  let assert Ok(reply) =
    frame.decode(
      frame.TextData(
        "[\"1\",\"1\",\"room:lobby\",\"phx_reply\",{\"status\":\"timeout\",\"response\":{}}]",
      ),
      direction: frame.ServerToClient,
    )
  let assert True = frame.reply_status(reply) == Error("timeout")
}

pub fn system_events_recognises_all_reserved_events_test() {
  [
    frame.join_event,
    frame.leave_event,
    frame.reply_event,
    frame.error_event,
    frame.close_event,
    frame.heartbeat_event,
  ]
  |> list.each(fn(event) {
    let assert True = frame.is_system_event(event)
  })
}

pub fn system_events_rejects_user_events_test() {
  let assert False = frame.is_system_event("new_msg")
}

pub fn roost_facade_forwards_encode_decode_and_helpers_test() {
  let outgoing = roost.heartbeat("99")
  let assert Ok(encoded) =
    roost.encode(outgoing, direction: frame.ClientToServer)
  let assert True =
    encoded == frame.TextData("[null,\"99\",\"phoenix\",\"heartbeat\",{}]")

  let assert Ok(decoded) =
    roost.decode(encoded, direction: frame.ClientToServer)
  let assert frame.Push(topic: "phoenix", event: "heartbeat", ..) = decoded

  let assert True = roost.is_system_event(frame.reply_event)
}

fn reply_status(status: fixtures.ReplyStatus) -> frame.ReplyStatus {
  case status {
    fixtures.StatusOk -> frame.StatusOk
    fixtures.StatusError -> frame.StatusError
  }
}

fn fixture_payload(payload: json.Json) {
  let assert Ok(payload) =
    json.parse(from: json.to_string(payload), using: decode.dynamic)

  payload
}

fn decode_reason_matches(
  fixture_reason: fixtures.InvalidReason,
  decode_error: frame.DecodeError,
) -> Bool {
  case fixture_reason, decode_error {
    fixtures.InvalidJson, frame.InvalidJson(_) -> True
    fixtures.InvalidFormat, frame.InvalidFormat(_) -> True
    _, _ -> False
  }
}
