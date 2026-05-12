//// Typed error surface for roost.
////
//// All public operations return `Result(_, RoostError)`. Transport-level
//// failures from Gluegun are wrapped in `Transport`; Phoenix-specific
//// failures get their own variants.

import gluegun/error as gluegun
import roost/frame

pub type RoostError {
  /// Underlying WebSocket transport failure from Gluegun (connect, send,
  /// receive, close).
  Transport(gluegun.GluegunError)
  /// The server rejected `phx_join` with the given reason.
  JoinRejected(reason: String)
  /// The server closed the channel (sent `phx_close` or `phx_error`).
  ChannelClosed
  /// An inbound wire frame could not be decoded.
  DecodeFailed(frame.DecodeError)
  /// Waited for a `phx_reply` matching an outbound ref but it never arrived
  /// within the configured timeout.
  ReplyTimeout
}

/// Lift a Gluegun error into a `RoostError`.
pub fn from_gluegun(err: gluegun.GluegunError) -> RoostError {
  Transport(err)
}
