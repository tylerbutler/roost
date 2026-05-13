import gleam/json
import gleam/option.{None, Some}
import roost
import roost/frame
import startest.{describe, it}
import startest/expect

pub fn frame_tests() {
  describe("frame", [
    describe("encode", [
      it("encodes a phx_join with refs and payload", fn() {
        frame.encode(
          join_ref: Some("1"),
          ref: Some("1"),
          topic: "room:lobby",
          event: "phx_join",
          payload: json.object([#("name", json.string("alice"))]),
        )
        |> expect.to_equal(
          "[\"1\",\"1\",\"room:lobby\",\"phx_join\",{\"name\":\"alice\"}]",
        )
      }),
      it("encodes null refs as JSON null", fn() {
        frame.encode(
          join_ref: None,
          ref: None,
          topic: "room:lobby",
          event: "broadcast",
          payload: json.object([]),
        )
        |> expect.to_equal("[null,null,\"room:lobby\",\"broadcast\",{}]")
      }),
    ]),
    describe("encode_heartbeat", [
      it("uses the phoenix topic with heartbeat event", fn() {
        frame.encode_heartbeat("42")
        |> expect.to_equal("[null,\"42\",\"phoenix\",\"heartbeat\",{}]")
      }),
    ]),
    describe("encode_reply", [
      it("encodes a phx_reply with ok status", fn() {
        frame.encode_reply(
          join_ref: Some("1"),
          ref: "1",
          topic: "room:lobby",
          status: frame.StatusOk,
          response: json.object([#("welcome", json.bool(True))]),
        )
        |> expect.to_equal(
          "[\"1\",\"1\",\"room:lobby\",\"phx_reply\",{\"status\":\"ok\",\"response\":{\"welcome\":true}}]",
        )
      }),
      it("encodes a phx_reply with error status", fn() {
        frame.encode_reply(
          join_ref: None,
          ref: "2",
          topic: "room:lobby",
          status: frame.StatusError,
          response: json.object([#("reason", json.string("unauthorized"))]),
        )
        |> expect.to_equal(
          "[null,\"2\",\"room:lobby\",\"phx_reply\",{\"status\":\"error\",\"response\":{\"reason\":\"unauthorized\"}}]",
        )
      }),
    ]),
    describe("decode", [
      it("decodes a phx_reply with both refs", fn() {
        let assert Ok(f) =
          frame.decode(
            "[\"1\",\"7\",\"room:lobby\",\"phx_reply\",{\"status\":\"ok\",\"response\":{}}]",
          )
        f.join_ref |> expect.to_equal(Some("1"))
        f.ref |> expect.to_equal(Some("7"))
        f.topic |> expect.to_equal("room:lobby")
        f.event |> expect.to_equal("phx_reply")
      }),
      it("decodes a server push with null refs", fn() {
        let assert Ok(f) =
          frame.decode(
            "[null,null,\"room:lobby\",\"new_msg\",{\"body\":\"hi\"}]",
          )
        f.join_ref |> expect.to_equal(None)
        f.ref |> expect.to_equal(None)
        f.event |> expect.to_equal("new_msg")
      }),
      it("returns InvalidJson on malformed input", fn() {
        let assert Error(frame.InvalidJson(_)) = frame.decode("{not json")
        Nil
      }),
      it("returns InvalidFormat on wrong array shape", fn() {
        let assert Error(frame.InvalidFormat(_)) = frame.decode("[1,2,3]")
        Nil
      }),
      it("returns InvalidFormat when array has extra elements", fn() {
        let assert Error(frame.InvalidFormat(_)) =
          frame.decode("[null,null,\"topic\",\"event\",{},\"extra\"]")
        Nil
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
          status: roost.StatusOk,
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
