//// Phoenix-channel WebSocket client for Gleam, built on Gluegun.
////
//// This module is the public facade. It re-exports the common channel
//// lifecycle functions from `roost/channel`.
////
//// ## Quick start
////
//// ```gleam
//// import gleam/io
//// import gleam/json
//// import roost
////
//// pub fn main() {
////   let assert Ok(channel) =
////     roost.connect(
////       host: "localhost",
////       port: 4000,
////       path: "/socket/websocket",
////       topic: "room:lobby",
////       payload: json.object([]),
////     )
////
////   let assert Ok(_) = roost.push(channel, "ping", json.object([]))
////
////   case roost.receive(channel) {
////     Ok(frame) -> io.debug(frame)
////     Error(_) -> io.println("receive failed")
////   }
////
////   let assert Ok(_) = roost.close(channel)
//// }
//// ```

import gleam/json
import roost/channel.{type Channel}
import roost/error.{type RoostError}
import roost/frame.{type Incoming}

/// Re-export of [`channel.connect`](roost/channel.html#connect).
pub fn connect(
  host host: String,
  port port: Int,
  path path: String,
  topic topic: String,
  payload payload: json.Json,
) -> Result(Channel, RoostError) {
  channel.connect(host:, port:, path:, topic:, payload:)
}

/// Re-export of [`channel.push`](roost/channel.html#push).
pub fn push(
  channel: Channel,
  event: String,
  payload: json.Json,
) -> Result(Nil, RoostError) {
  channel.push(channel, event, payload)
}

/// Re-export of [`channel.receive`](roost/channel.html#receive).
pub fn receive(channel: Channel) -> Result(Incoming, RoostError) {
  channel.receive(channel)
}

/// Re-export of [`channel.close`](roost/channel.html#close).
pub fn close(channel: Channel) -> Result(Nil, RoostError) {
  channel.close(channel)
}
