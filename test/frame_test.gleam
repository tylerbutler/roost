import gleam/json
import gleam/option.{None, Some}
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
        frame.is_system_event("phx_join") |> expect.to_equal(True)
      }),
      it("recognises heartbeat", fn() {
        frame.is_system_event("heartbeat") |> expect.to_equal(True)
      }),
      it("rejects user events", fn() {
        frame.is_system_event("new_msg") |> expect.to_equal(False)
      }),
    ]),
  ])
}
