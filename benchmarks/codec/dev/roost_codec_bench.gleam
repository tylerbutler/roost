import gleam/io
import gleam/list
import glychee/benchmark
import glychee/configuration
import roost
import roost/frame
import roost_codec_bench/fixture

pub fn main() -> Nil {
  let inputs = fixture.all()
  let assert Ok(Nil) = fixture.preflight(inputs)
  io.println("Codec preflight passed; target=erlang mode=dev parallel=1")

  configuration.initialize()
  let assert True = configuration.set_pair(configuration.Parallel, 1)
  let assert True = configuration.set_pair(configuration.Warmup, 1)
  let assert True = configuration.set_pair(configuration.Time, 3)
  let assert True = configuration.set_pair(configuration.MemoryTime, 1)
  let assert True = configuration.set_pair(configuration.ReductionTime, 1)

  let data = list.map(inputs, fn(input) { benchmark.Data(input.label, input) })
  benchmark.run(
    [
      benchmark.Function("roost.encode", fn(input: fixture.Fixture) {
        let outgoing = input.outgoing
        let direction = input.direction
        fn() { roost.encode(outgoing, direction) }
      }),
    ],
    data,
  )
  benchmark.run(
    [
      benchmark.Function("roost.decode", fn(input: fixture.Fixture) {
        let wire = input.wire
        let direction = input.direction
        fn() { roost.decode(wire, direction) }
      }),
    ],
    data,
  )
  benchmark.run(
    [
      benchmark.Function("roost.decode/reject", fn(input: fixture.Rejection) {
        let wire = input.wire
        let direction = input.direction
        fn() { roost.decode(wire, direction) }
      }),
    ],
    list.map(fixture.rejections(), fn(input) {
      benchmark.Data(input.label, input)
    }),
  )
  benchmark.run(
    [
      benchmark.Function("roost.encode/reject", fn(outgoing) {
        fn() { roost.encode(outgoing, frame.ClientToServer) }
      }),
    ],
    [
      benchmark.Data(
        "binary/reject/topic_bytes=256/client_to_server",
        fixture.oversized_topic(),
      ),
    ],
  )
}
