//// Phoenix channel client lifecycle.
////
//// A `Channel` wraps a Gluegun WebSocket socket joined to a single Phoenix
//// topic, plus the ref counter and background heartbeat needed to keep the
//// channel healthy.
////
//// ## Process ownership
////
//// The socket is owned by the process that called [`connect`](#connect).
//// Only that process may call [`receive`](#receive). [`push`](#push) and
//// [`close`](#close) are safe to call from any process, since Gun's
//// `ws_send` is fire-and-forget.

import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/json
import gleam/option.{Some}
import gleam/result
import gluegun/message
import gluegun/websocket
import roost/error.{type RoostError}
import roost/frame.{type Incoming}
import roost/heartbeat
import roost/ref

/// Default heartbeat interval, matching the Phoenix JS client.
const default_heartbeat_ms: Int = 30_000

pub opaque type Channel {
  Channel(
    socket: websocket.Socket,
    topic: String,
    join_ref: String,
    counter: ref.Counter,
    heartbeat: heartbeat.Heartbeat,
  )
}

/// Open a WebSocket to a Phoenix-compatible server, join the given topic
/// with the supplied payload, and return a `Channel` ready for use.
///
/// Blocks until either a `phx_reply` matching the join arrives, or a
/// transport error / non-ok status is observed.
pub fn connect(
  host host: String,
  port port: Int,
  path path: String,
  topic topic: String,
  payload payload: json.Json,
) -> Result(Channel, RoostError) {
  use socket <- result.try(
    websocket.connect(host:, port:, path:, options: websocket.options())
    |> result.map_error(error.from_gluegun),
  )

  use counter <- result.try(
    ref.start()
    |> result.replace_error(error.ReplyTimeout),
  )

  let join_ref = ref.next(counter)
  let join_frame =
    frame.encode(
      join_ref: Some(join_ref),
      ref: Some(join_ref),
      topic: topic,
      event: "phx_join",
      payload: payload,
    )

  use _ <- result.try(
    websocket.send_text(socket, join_frame)
    |> result.map_error(error.from_gluegun),
  )

  use _ <- result.try(await_join_reply(socket, join_ref))

  // Send queue + receive happen in the caller's process. The heartbeat
  // actor runs separately and only sends, which Gluegun allows from any
  // process.
  let send_fn = fn(text: String) -> Nil {
    let _ = websocket.send_text(socket, text)
    Nil
  }

  use hb <- result.try(
    heartbeat.start(send_fn, default_heartbeat_ms, counter)
    |> result.replace_error(error.ReplyTimeout),
  )

  Ok(Channel(
    socket: socket,
    topic: topic,
    join_ref: join_ref,
    counter: counter,
    heartbeat: hb,
  ))
}

/// Push an event into the channel. Refs are assigned automatically.
///
/// Returns `Ok(Nil)` once the frame is handed to Gun. This does **not** wait
/// for a `phx_reply` — callers that need correlated replies should match on
/// the returned ref using [`receive`](#receive).
pub fn push(
  channel: Channel,
  event: String,
  payload: json.Json,
) -> Result(Nil, RoostError) {
  let ref = ref.next(channel.counter)
  let text =
    frame.encode(
      join_ref: Some(channel.join_ref),
      ref: Some(ref),
      topic: channel.topic,
      event: event,
      payload: payload,
    )
  websocket.send_text(channel.socket, text)
  |> result.map_error(error.from_gluegun)
}

/// Receive the next inbound frame on the channel.
///
/// Skips Phoenix heartbeat replies so the caller only sees real channel
/// activity. Returns `Error(ChannelClosed)` if the server sent `phx_close`
/// or `phx_error`, or the socket itself closed.
pub fn receive(channel: Channel) -> Result(Incoming, RoostError) {
  do_receive(channel)
}

fn do_receive(channel: Channel) -> Result(Incoming, RoostError) {
  use raw <- result.try(
    websocket.receive_app_frame(channel.socket)
    |> result.map_error(error.from_gluegun),
  )

  case raw {
    message.Text(text) ->
      case frame.decode(text) {
        Ok(incoming) -> handle_incoming(channel, incoming)
        Error(err) -> Error(error.DecodeFailed(err))
      }
    message.Binary(_) -> do_receive(channel)
    message.Close | message.CloseWithReason(_, _) -> Error(error.ChannelClosed)
    message.Ping(_) | message.Pong(_) -> do_receive(channel)
  }
}

fn handle_incoming(
  channel: Channel,
  incoming: Incoming,
) -> Result(Incoming, RoostError) {
  case incoming.event {
    "phx_close" | "phx_error" -> Error(error.ChannelClosed)
    "phx_reply" if incoming.topic == "phoenix" -> do_receive(channel)
    _ -> Ok(incoming)
  }
}

/// Close the channel and underlying WebSocket. The heartbeat actor is
/// stopped first.
pub fn close(channel: Channel) -> Result(Nil, RoostError) {
  heartbeat.stop(channel.heartbeat)
  websocket.close(channel.socket)
  |> result.map_error(error.from_gluegun)
}

fn await_join_reply(
  socket: websocket.Socket,
  join_ref: String,
) -> Result(Nil, RoostError) {
  use raw <- result.try(
    websocket.receive_app_frame(socket)
    |> result.map_error(error.from_gluegun),
  )

  case raw {
    message.Text(text) ->
      case frame.decode(text) {
        Ok(incoming) -> match_join_reply(socket, join_ref, incoming)
        Error(err) -> Error(error.DecodeFailed(err))
      }
    message.Close | message.CloseWithReason(_, _) -> Error(error.ChannelClosed)
    _ -> await_join_reply(socket, join_ref)
  }
}

fn match_join_reply(
  socket: websocket.Socket,
  join_ref: String,
  incoming: Incoming,
) -> Result(Nil, RoostError) {
  case incoming.event, incoming.ref {
    "phx_reply", Some(reply_ref) if reply_ref == join_ref ->
      case decode_reply_status(incoming.payload) {
        Ok("ok") -> Ok(Nil)
        Ok(other) -> Error(error.JoinRejected(other))
        Error(_) -> Error(error.JoinRejected("malformed reply"))
      }
    _, _ -> await_join_reply(socket, join_ref)
  }
}

fn decode_reply_status(payload: Dynamic) -> Result(String, Nil) {
  let decoder = {
    use status <- decode.field("status", decode.string)
    decode.success(status)
  }
  decode.run(payload, decoder)
  |> result.map_error(fn(_) { Nil })
}
