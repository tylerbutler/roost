//// Monotonic ref counter for Phoenix wire frames.
////
//// Phoenix refs are strings. This module wraps a small actor that produces
//// monotonically increasing integers serialised as strings (`"1"`, `"2"`,
//// ...). Used internally by `roost/channel` to assign refs to outbound
//// messages.

import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/otp/actor

pub opaque type Counter {
  Counter(subject: Subject(Message))
}

pub opaque type Message {
  Next(reply_to: Subject(String))
}

/// Start a new ref counter actor. The first `next` call returns `"1"`.
pub fn start() -> Result(Counter, actor.StartError) {
  case
    actor.new(0)
    |> actor.on_message(handle)
    |> actor.start
  {
    Ok(started) -> Ok(Counter(subject: started.data))
    Error(err) -> Error(err)
  }
}

/// Pull the next ref from the counter.
pub fn next(counter: Counter) -> String {
  actor.call(counter.subject, 5000, Next)
}

fn handle(state: Int, msg: Message) -> actor.Next(Int, Message) {
  case msg {
    Next(reply_to) -> {
      let next = state + 1
      process.send(reply_to, int.to_string(next))
      actor.continue(next)
    }
  }
}
