import gleam/option.{None, Some}
import roost/frame
import startest.{describe, it}
import startest/expect

pub fn binary_frame_tests() {
  describe("binary frame", [
    describe("encode", [
      it("encodes a client push", fn() {
        binary_push()
        |> frame.encode(direction: frame.ClientToServer)
        |> expect.to_equal(
          Ok(
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
          ),
        )
      }),
      it("encodes a server push", fn() {
        frame.Push(
          join_ref: Some("12"),
          ref: None,
          topic: "topic",
          event: "event",
          payload: frame.BinaryPayload(<<101, 102, 103>>),
        )
        |> frame.encode(direction: frame.ServerToClient)
        |> expect.to_equal(
          Ok(
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
          ),
        )
      }),
      it("encodes a server reply", fn() {
        frame.Reply(
          join_ref: Some("12"),
          ref: "123",
          topic: "topic",
          status: frame.StatusOk,
          response: frame.BinaryPayload(<<101, 102, 103>>),
        )
        |> frame.encode(direction: frame.ServerToClient)
        |> expect.to_equal(
          Ok(
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
          ),
        )
      }),
      it("encodes a server broadcast", fn() {
        frame.Broadcast(
          topic: "topic",
          event: "event",
          payload: frame.BinaryPayload(<<101, 102, 103>>),
        )
        |> frame.encode(direction: frame.ServerToClient)
        |> expect.to_equal(
          Ok(
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
          ),
        )
      }),
      it("counts UTF-8 bytes in metadata lengths", fn() {
        frame.Push(
          join_ref: None,
          ref: None,
          topic: "café",
          event: "é",
          payload: frame.BinaryPayload(<<>>),
        )
        |> frame.encode(direction: frame.ClientToServer)
        |> expect.to_equal(
          Ok(frame.BinaryData(<<0, 0, 0, 5, 2, "café":utf8, "é":utf8>>)),
        )
      }),
      it("accepts 255-byte metadata and rejects 256 bytes", fn() {
        frame.Push(
          join_ref: None,
          ref: None,
          topic: repeat("a", 255),
          event: "e",
          payload: frame.BinaryPayload(<<>>),
        )
        |> frame.encode(direction: frame.ClientToServer)
        |> expect.to_be_ok()

        frame.Push(
          join_ref: None,
          ref: None,
          topic: repeat("a", 256),
          event: "e",
          payload: frame.BinaryPayload(<<>>),
        )
        |> frame.encode(direction: frame.ClientToServer)
        |> expect.to_equal(Error(frame.MetadataTooLong("topic", 256)))
      }),
      it("rejects non-byte-aligned payloads", fn() {
        frame.Push(
          join_ref: None,
          ref: None,
          topic: "topic",
          event: "event",
          payload: frame.BinaryPayload(<<1:size(1)>>),
        )
        |> frame.encode(direction: frame.ClientToServer)
        |> expect.to_equal(Error(frame.InvalidBinaryPayload))
      }),
    ]),
    describe("decode", [
      it("decodes a client push", fn() {
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
      }),
      it("decodes a server push", fn() {
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
      }),
      it("decodes a server reply", fn() {
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

        frame.matches_join_reply(reply, "123") |> expect.to_equal(True)
        frame.reply_status(reply) |> expect.to_equal(Ok(Nil))
      }),
      it("decodes a server broadcast", fn() {
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
      }),
      it("maps empty refs to None", fn() {
        let assert Ok(frame.Push(join_ref: None, ref: None, ..)) =
          frame.decode(
            frame.BinaryData(<<0, 0, 0, 1, 1, "t":utf8, "e":utf8>>),
            direction: frame.ClientToServer,
          )
        Nil
      }),
      it("rejects unknown and directionally invalid kinds", fn() {
        frame.decode(frame.BinaryData(<<9>>), direction: frame.ServerToClient)
        |> expect.to_be_error()

        frame.decode(
          frame.BinaryData(<<1, 0, 0, 0, 0>>),
          direction: frame.ClientToServer,
        )
        |> expect.to_be_error()
        Nil
      }),
      it("rejects truncated metadata", fn() {
        frame.decode(
          frame.BinaryData(<<0, 2, 5, 5, "12":utf8, "top":utf8>>),
          direction: frame.ServerToClient,
        )
        |> expect.to_be_error()
        Nil
      }),
      it("rejects invalid UTF-8 metadata", fn() {
        frame.decode(
          frame.BinaryData(<<0, 1, 1, 1, 255, "t":utf8, "e":utf8>>),
          direction: frame.ServerToClient,
        )
        |> expect.to_be_error()
        Nil
      }),
      it("rejects non-byte-aligned wire data", fn() {
        frame.decode(
          frame.BinaryData(<<0:size(1)>>),
          direction: frame.ServerToClient,
        )
        |> expect.to_equal(
          Error(frame.InvalidBinary(
            "Expected binary wire data to contain whole bytes",
          )),
        )
      }),
    ]),
  ])
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
