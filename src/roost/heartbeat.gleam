//// Background heartbeat actor.
////
//// Phoenix channels require periodic `heartbeat` frames on the reserved
//// `"phoenix"` topic to keep the connection alive. This module runs a small
//// actor that, on each tick, pulls a fresh ref from a `ref.Counter`, encodes
//// a heartbeat frame, and hands it to a caller-provided `send_fn`.

import gleam/erlang/process.{type Subject}
import gleam/otp/actor
import roost/frame
import roost/ref

pub opaque type Heartbeat {
  Heartbeat(subject: Subject(Message))
}

pub opaque type Message {
  Tick
  Stop
}

type State {
  State(
    self: Subject(Message),
    send_fn: fn(String) -> Nil,
    interval_ms: Int,
    counter: ref.Counter,
  )
}

/// Start a heartbeat actor. The first heartbeat fires after `interval_ms`.
///
/// `send_fn` is called from the actor's process and must not block — typical
/// implementations forward the frame to a WebSocket socket actor.
pub fn start(
  send_fn send_fn: fn(String) -> Nil,
  interval_ms interval_ms: Int,
  counter counter: ref.Counter,
) -> Result(Heartbeat, actor.StartError) {
  let result =
    actor.new_with_initialiser(5000, fn(self) {
      let _ = process.send_after(self, interval_ms, Tick)
      let state =
        State(
          self: self,
          send_fn: send_fn,
          interval_ms: interval_ms,
          counter: counter,
        )
      actor.initialised(state)
      |> actor.returning(self)
      |> Ok
    })
    |> actor.on_message(handle)
    |> actor.start

  case result {
    Ok(started) -> Ok(Heartbeat(subject: started.data))
    Error(err) -> Error(err)
  }
}

/// Stop the heartbeat actor. Idempotent — sending `Stop` to an already-stopped
/// actor is a no-op from the caller's perspective.
pub fn stop(hb: Heartbeat) -> Nil {
  process.send(hb.subject, Stop)
}

fn handle(state: State, msg: Message) -> actor.Next(State, Message) {
  case msg {
    Tick -> {
      let ref = ref.next(state.counter)
      let _ = state.send_fn(frame.encode_heartbeat(ref))
      let _ = process.send_after(state.self, state.interval_ms, Tick)
      actor.continue(state)
    }
    Stop -> actor.stop()
  }
}
