import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import phoenix_channel_fixtures/frame as fixtures
import roost
import roost/frame
import startest.{describe, it}
import startest/expect

pub fn frame_tests() {
  describe("frame", [
    describe("encode", [
      it("encodes client outbound fixtures", fn() {
        fixtures.client_outbound()
        |> expect_encoded_frames
      }),
      it("encodes server outbound fixtures", fn() {
        fixtures.server_outbound()
        |> expect_encoded_frames
      }),
    ]),
    describe("encode_heartbeat", [
      it("uses the phoenix topic with heartbeat event", fn() {
        frame.encode_heartbeat("42")
        |> expect.to_equal("[null,\"42\",\"phoenix\",\"heartbeat\",{}]")
      }),
    ]),
    describe("encode_reply", [
      it("encodes reply fixtures", fn() {
        fixtures.replies()
        |> list.each(fn(case_) {
          frame.encode_reply(
            join_ref: case_.join_ref,
            ref: case_.ref,
            topic: case_.topic,
            status: reply_status(case_.status),
            response: case_.response,
          )
          |> expect.to_equal(case_.encoded)
        })
      }),
    ]),
    describe("decode", [
      it("decodes inbound common fixtures", fn() {
        fixtures.inbound_common()
        |> list.each(fn(case_) {
          let assert Ok(f) = frame.decode(case_.encoded)
          f.join_ref |> expect.to_equal(case_.join_ref)
          f.ref |> expect.to_equal(case_.ref)
          f.topic |> expect.to_equal(case_.topic)
          f.event |> expect.to_equal(case_.event)
          f.payload |> expect.to_equal(fixture_payload(case_.payload))
        })
      }),
      it("classifies invalid frame fixtures", fn() {
        fixtures.invalid_frames()
        |> list.each(fn(case_) {
          let assert Error(reason) = frame.decode(case_.encoded)
          decode_reason_matches(case_.reason, reason) |> expect.to_equal(True)
        })
      }),
      it("round-trips encode -> decode", fn() {
        let encoded =
          frame.encode(
            join_ref: Some("3"),
            ref: Some("5"),
            topic: "doc:abc",
            event: "update",
            payload: json.object([#("delta", json.string("text"))]),
          )
        let assert Ok(f) = frame.decode(encoded)
        f.join_ref |> expect.to_equal(Some("3"))
        f.ref |> expect.to_equal(Some("5"))
        f.topic |> expect.to_equal("doc:abc")
        f.event |> expect.to_equal("update")
      }),
    ]),
    describe("is_system_event", [
      it("recognises phx_join", fn() {
        frame.is_system_event(frame.join_event) |> expect.to_equal(True)
      }),
      it("recognises heartbeat", fn() {
        frame.is_system_event(frame.heartbeat_event) |> expect.to_equal(True)
      }),
      it("exposes reserved event constants", fn() {
        frame.join_event |> expect.to_equal("phx_join")
        frame.leave_event |> expect.to_equal("phx_leave")
        frame.reply_event |> expect.to_equal("phx_reply")
        frame.error_event |> expect.to_equal("phx_error")
        frame.close_event |> expect.to_equal("phx_close")
        frame.heartbeat_event |> expect.to_equal("heartbeat")
        frame.heartbeat_topic |> expect.to_equal("phoenix")
      }),
      it("rejects user events", fn() {
        frame.is_system_event("new_msg") |> expect.to_equal(False)
      }),
    ]),
    describe("roost facade", [
      it("forwards protocol helpers", fn() {
        roost.encode_heartbeat("99")
        |> expect.to_equal(frame.encode_heartbeat("99"))

        roost.encode_reply(
          join_ref: Some("1"),
          ref: "1",
          topic: "room:lobby",
          status: frame.StatusOk,
          response: json.object([]),
        )
        |> expect.to_equal(
          "[\"1\",\"1\",\"room:lobby\",\"phx_reply\",{\"status\":\"ok\",\"response\":{}}]",
        )

        roost.is_system_event(frame.reply_event) |> expect.to_equal(True)
      }),
      it("forwards encode and decode", fn() {
        let encoded =
          roost.encode(
            join_ref: None,
            ref: Some("8"),
            topic: frame.heartbeat_topic,
            event: frame.heartbeat_event,
            payload: json.object([]),
          )

        let assert Ok(decoded) = roost.decode(encoded)
        decoded.topic |> expect.to_equal(frame.heartbeat_topic)
        decoded.event |> expect.to_equal(frame.heartbeat_event)
      }),
    ]),
  ])
}

fn expect_encoded_frames(cases: List(fixtures.FrameCase)) {
  cases
  |> list.each(fn(case_) {
    frame.encode(
      join_ref: case_.join_ref,
      ref: case_.ref,
      topic: case_.topic,
      event: case_.event,
      payload: case_.payload,
    )
    |> expect.to_equal(case_.encoded)
  })
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
