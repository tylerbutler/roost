# Codec benchmarks

Measure Roost's Phoenix codec with [Glychee](https://hexdocs.pm/glychee/),
which wraps Elixir's Benchee. This optional Erlang-only package depends on the
local Roost checkout. Normal Erlang/JavaScript tests, CI, and Git-only releases
do not include it or its dependencies.

## Run

Install the root mise tools first, then run from the repository root:

```sh
just bench-codec-deps
just bench-codec-check
just bench-codec
```

Without shell activation, prefix each command with `mise exec --`.
Inspect and trust `benchmarks/codec/.mise.toml` if mise requests it.
`bench-codec-deps` installs optional Elixir 1.18.4 for the root's OTP 27,
ensures Hex exists, and downloads this package's dependencies. It does not
change the root dependency manifests.

`bench-codec-check` checks formatting, builds with warnings as errors, and
runs four Unitest fixture checks without timing. `bench-codec` prints the
commit, working-tree changes, and tool versions, validates the fixtures,
then measures codec calls in Gleam's development mode.

## Measurements

Each successful operation uses prebuilt payloads of **128 B, 4 KiB, and
64 KiB**. JSON payloads contain a `body` string; binary payloads contain
repeated bytes `0, 255, 128, 1`, including invalid UTF-8. Labels include
direction, body bytes, and complete wire bytes.

| Frame | Direction | Measured calls |
| --- | --- | --- |
| Text push | Client to server | `roost.encode`, `roost.decode` |
| Text reply | Server to client | `roost.encode`, `roost.decode` |
| Text broadcast | Server to client | `roost.encode`, `roost.decode` |
| Binary push | Client to server | `roost.encode`, `roost.decode` |
| Binary push | Server to client | `roost.encode`, `roost.decode` |
| Binary reply | Server to client | `roost.encode`, `roost.decode` |
| Binary broadcast | Server to client | `roost.encode`, `roost.decode` |

Separate rejection measurements cover malformed JSON, incorrect array length,
a non-string topic, truncated binary metadata, unknown binary kind, invalid
UTF-8 metadata, and binary encoding with a 256-byte topic.

The runner uses one worker, a 1-second warmup, a 3-second timing phase,
a 1-second memory phase, and a 1-second reduction phase per case. Benchee
chooses the sample count within those phases. The full matrix contains 42
successful operation/input combinations and seven rejections.

Measured closures return completed encode/decode results. Fixture creation,
expected-value construction, validation, and printing happen outside them.
No socket or actor runs as part of these measurements.

## Correctness and reproduction

Preflight checks exact text and independently assembled binary wire layouts,
decoded fields, and complete payloads before timing starts. Failures include
the operation/direction/size label and failed contract, and stop the process
before Glychee runs. Unitest runs the same checks.

Checks account for Roost's normalization: text broadcasts decode as pushes,
empty optional binary refs decode as `None`, server binary pushes omit `ref`,
and `ok`/`error` status strings decode to canonical status constructors.
Untimed cases cover empty payloads/refs, multibyte metadata, the 255/256-byte
metadata boundary, and custom statuses. Text push decoding also runs in both
directions during preflight.

Fixtures are deterministic; there is no generator seed or randomized input
count. Unitest's seed reproduces **test ordering**, not Benchee sampling.
To reproduce a fixture failure with native runner filters:

```sh
cd benchmarks/codec
mise exec -- gleam test -- --seed 123
mise exec -- gleam test -- --test roost_codec_bench_test.binary_fixtures_test
mise exec -- gleam test -- test/roost_codec_bench_test.gleam
```

Roost has no explicit Beryl-style JSON depth limit. These fixtures make no
depth-limit rejection assertion and do not treat shorter opaque binary
payloads as malformed.

## Compare results

Retain the printed commit, dirty state, tool versions, and warnings with each
result. Also record hardware and scheduler flags such as `ERL_FLAGS`; use the
same execution mode and a quiet host. Repeat each comparison at least three
times and compare medians and spread, rather than the best sample. Redirect
stdout/stderr to a local file if you want to retain results.

Compare matching operations and input labels across revisions. Text and
binary encoding perform different work; their timings do not establish an
equivalent-work speedup. Benchee's memory measurements do not measure total
RSS, retained memory, or off-heap binary allocation, and cannot prove that
payloads were not copied. Reductions apply to the measured process.
These results say nothing about network latency or server capacity.

Retain any Elixir protocol-consolidation warnings with the results. Setup
failures are not benchmark results; resolve them before measuring. Do not
disable TLS certificate verification to work around dependency download errors.
