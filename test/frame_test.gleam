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
    describe("text encode", [
      it("encodes client outbound fixtures", fn() {
        fixtures.client_outbound()
        |> list.each(fn(case_) {
          frame.Push(
            join_ref: case_.join_ref,
            ref: case_.ref,
            topic: case_.topic,
            event: case_.event,
            payload: frame.JsonPayload(case_.payload),
          )
          |> frame.encode(direction: frame.ClientToServer)
          |> expect.to_equal(Ok(frame.TextData(case_.encoded)))
        })
      }),
      it("encodes server outbound fixtures", fn() {
        fixtures.server_outbound()
        |> list.each(fn(case_) {
          frame.Push(
            join_ref: case_.join_ref,
            ref: case_.ref,
            topic: case_.topic,
            event: case_.event,
            payload: frame.JsonPayload(case_.payload),
          )
          |> frame.encode(direction: frame.ServerToClient)
          |> expect.to_equal(Ok(frame.TextData(case_.encoded)))
        })
      }),
      it("encodes reply fixtures", fn() {
        fixtures.replies()
        |> list.each(fn(case_) {
          frame.Reply(
            join_ref: case_.join_ref,
            ref: case_.ref,
            topic: case_.topic,
            status: reply_status(case_.status),
            response: frame.JsonPayload(case_.response),
          )
          |> frame.encode(direction: frame.ServerToClient)
          |> expect.to_equal(Ok(frame.TextData(case_.encoded)))
        })
      }),
      it("encodes broadcasts as the common JSON array", fn() {
        frame.Broadcast(
          topic: "room:lobby",
          event: "tick",
          payload: frame.JsonPayload(
            json.object([
              #("n", json.int(42)),
            ]),
          ),
        )
        |> frame.encode(direction: frame.ServerToClient)
        |> expect.to_equal(
          Ok(frame.TextData("[null,null,\"room:lobby\",\"tick\",{\"n\":42}]")),
        )
      }),
      it("rejects client reply and broadcast frames", fn() {
        frame.Reply(
          join_ref: None,
          ref: "1",
          topic: "room:lobby",
          status: frame.StatusOk,
          response: frame.JsonPayload(json.object([])),
        )
        |> frame.encode(direction: frame.ClientToServer)
        |> expect.to_be_error()

        frame.Broadcast(
          topic: "room:lobby",
          event: "tick",
          payload: frame.JsonPayload(json.object([])),
        )
        |> frame.encode(direction: frame.ClientToServer)
        |> expect.to_be_error()
        Nil
      }),
    ]),
    describe("text decode", [
      it("decodes client outbound fixtures", fn() {
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

          join_ref |> expect.to_equal(case_.join_ref)
          ref |> expect.to_equal(case_.ref)
          topic |> expect.to_equal(case_.topic)
          event |> expect.to_equal(case_.event)
          payload |> expect.to_equal(fixture_payload(case_.payload))
        })
      }),
      it("decodes server pushes as Push frames", fn() {
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

          join_ref |> expect.to_equal(case_.join_ref)
          ref |> expect.to_equal(case_.ref)
          topic |> expect.to_equal(case_.topic)
          event |> expect.to_equal(case_.event)
          payload |> expect.to_equal(fixture_payload(case_.payload))
        })
      }),
      it("normalises text phx_reply frames", fn() {
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

          join_ref |> expect.to_equal(case_.join_ref)
          ref |> expect.to_equal(case_.ref)
          topic |> expect.to_equal(case_.topic)
          status |> expect.to_equal(reply_status(case_.status))
          response |> expect.to_equal(fixture_payload(case_.response))
        })
      }),
      it("classifies invalid frame fixtures", fn() {
        fixtures.invalid_frames()
        |> list.each(fn(case_) {
          let assert Error(reason) =
            frame.decode(
              frame.TextData(case_.encoded),
              direction: frame.ClientToServer,
            )
          decode_reason_matches(case_.reason, reason) |> expect.to_equal(True)
        })
      }),
      it("round-trips a JSON push", fn() {
        let outgoing =
          frame.Push(
            join_ref: Some("3"),
            ref: Some("5"),
            topic: "doc:abc",
            event: "update",
            payload: frame.JsonPayload(
              json.object([
                #("delta", json.string("text")),
              ]),
            ),
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
      }),
    ]),
    describe("heartbeat", [
      it("builds the Phoenix heartbeat frame", fn() {
        frame.heartbeat("42")
        |> frame.encode(direction: frame.ClientToServer)
        |> expect.to_equal(
          Ok(frame.TextData("[null,\"42\",\"phoenix\",\"heartbeat\",{}]")),
        )
      }),
    ]),
    describe("reply helpers", [
      it("matches a reply with the join ref", fn() {
        let assert Ok(reply) =
          frame.decode(
            frame.TextData(
              "[\"1\",\"1\",\"room:lobby\",\"phx_reply\",{\"status\":\"ok\",\"response\":{}}]",
            ),
            direction: frame.ServerToClient,
          )
        frame.matches_join_reply(reply, "1") |> expect.to_equal(True)
        frame.matches_join_reply(reply, "2") |> expect.to_equal(False)
      }),
      it("rejects non-reply frames", fn() {
        let assert Ok(push) =
          frame.decode(
            frame.TextData("[\"1\",\"1\",\"room:lobby\",\"new_msg\",{}]"),
            direction: frame.ClientToServer,
          )
        frame.matches_join_reply(push, "1") |> expect.to_equal(False)
      }),
      it("returns Ok for successful replies", fn() {
        let assert Ok(reply) =
          frame.decode(
            frame.TextData(
              "[\"1\",\"1\",\"room:lobby\",\"phx_reply\",{\"status\":\"ok\",\"response\":{}}]",
            ),
            direction: frame.ServerToClient,
          )
        frame.reply_status(reply) |> expect.to_equal(Ok(Nil))
      }),
      it("uses response.reason for JSON errors", fn() {
        let assert Ok(reply) =
          frame.decode(
            frame.TextData(
              "[\"1\",\"1\",\"room:lobby\",\"phx_reply\",{\"status\":\"error\",\"response\":{\"reason\":\"unauthorized\"}}]",
            ),
            direction: frame.ServerToClient,
          )
        frame.reply_status(reply) |> expect.to_equal(Error("unauthorized"))
      }),
      it("preserves custom reply status strings", fn() {
        let assert Ok(reply) =
          frame.decode(
            frame.TextData(
              "[\"1\",\"1\",\"room:lobby\",\"phx_reply\",{\"status\":\"timeout\",\"response\":{}}]",
            ),
            direction: frame.ServerToClient,
          )
        frame.reply_status(reply) |> expect.to_equal(Error("timeout"))
      }),
    ]),
    describe("system events", [
      it("recognises all reserved events", fn() {
        [
          frame.join_event,
          frame.leave_event,
          frame.reply_event,
          frame.error_event,
          frame.close_event,
          frame.heartbeat_event,
        ]
        |> list.each(fn(event) {
          frame.is_system_event(event) |> expect.to_equal(True)
        })
      }),
      it("rejects user events", fn() {
        frame.is_system_event("new_msg") |> expect.to_equal(False)
      }),
    ]),
    describe("roost facade", [
      it("forwards encode, decode, and helpers", fn() {
        let outgoing = roost.heartbeat("99")
        let assert Ok(encoded) =
          roost.encode(outgoing, direction: frame.ClientToServer)
        encoded
        |> expect.to_equal(frame.TextData(
          "[null,\"99\",\"phoenix\",\"heartbeat\",{}]",
        ))

        let assert Ok(decoded) =
          roost.decode(encoded, direction: frame.ClientToServer)
        let assert frame.Push(topic: "phoenix", event: "heartbeat", ..) =
          decoded

        roost.is_system_event(frame.reply_event) |> expect.to_equal(True)
      }),
    ]),
  ])
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
