# roost

Phoenix channel wire protocol helpers for Gleam.

> **Status:** pre-1.0. API unstable. Git-only distribution.

## Availability

Install `roost` from Git. Stable versions and release candidates use Git tags
and [GitHub Releases](https://github.com/tylerbutler/roost/releases), not Hex.

Add a Git dependency in `gleam.toml`. Pin `ref` to a commit or a release tag
that matches the API you need. Use `main` only when you want unreleased changes.

```toml
[dependencies]
roost = { git = "https://github.com/tylerbutler/roost.git", ref = "main" }
```

## Quick start

```gleam
import gleam/json
import gleam/option.{Some}
import roost
import roost/frame

pub fn join_message() {
  let message = frame.Push(
    join_ref: Some("1"),
    ref: Some("1"),
    topic: "room:lobby",
    event: "phx_join",
    payload: frame.JsonPayload(
      json.object([#("name", json.string("alice"))]),
    ),
  )

  roost.encode(message, direction: frame.ClientToServer)
}
```

## What it does

- Encodes and decodes Phoenix text frames using
  `[join_ref, ref, topic, event, payload]`.
- Encodes and decodes Phoenix binary client pushes, server pushes, replies,
  and broadcasts.
- Represents transport data explicitly as `TextData(String)` or
  `BinaryData(BitArray)`.
- Represents JSON and binary payloads with one typed `Payload(json)` model.
- Requires `ClientToServer` or `ServerToClient` direction because Phoenix's
  binary kind `0` layout differs by direction.
- Provides constants for Phoenix reserved events and heartbeat topic.
- Provides helpers for heartbeat frames, reply correlation, and reply status.

## Binary payloads

Use `BinaryPayload` to select Phoenix's binary serializer. roost validates the
one-byte metadata lengths and returns an `EncodeError` instead of truncating
oversized fields.

```gleam
let message = frame.Push(
  join_ref: Some("1"),
  ref: Some("2"),
  topic: "room:lobby",
  event: "upload",
  payload: frame.BinaryPayload(<<1, 2, 3>>),
)

roost.encode(message, direction: frame.ClientToServer)
// Ok(frame.BinaryData(...))
```

## What it doesn't do

- Open WebSocket connections.
- Choose WebSocket text or binary opcodes for your transport.
- Manage channel processes, refs, reconnects, or heartbeats.
- Depend on Gluegun, Beryl, Mist, OTP, or any transport runtime.

## Target support

`roost` supports both Erlang and JavaScript targets. Its protocol API is the
same on each target; callers provide the transport and wrap socket data as
`TextData` or `BinaryData`.

For a full browser or Node.js Phoenix client, prefer the official Phoenix
JavaScript client. It already handles WebSocket lifecycle, channel state,
refs, push replies, timeouts, heartbeats, reconnects, rejoins, and Presence.
Use `roost` on JavaScript when you specifically need the protocol codec without
those client responsibilities.

## Development

Install the development tools with [mise](https://mise.jdx.dev/). Use
`mise.toml` for tool versions in local development and CI.

```sh
mise install       # Install development tools
mise exec -- just deps # Download dependencies with mise tools
just deps          # Download dependencies
just build         # Build the project
just test          # Run Unitest on Erlang and JavaScript
just check         # Type check
just format        # Format source
just ci            # Code checks, release checks, and Trellis doctor
just docs          # Build docs
just change --kind Fixed --body "Describe the fix" # Add a change fragment
just changelog-preview # Plan versions without writes
just trellis-doctor # Validate release configuration
just test-release  # Check release workflow safety offline
```

The `just` commands require mise activation in your shell. Without activation,
use `mise exec -- just ...`.

Tests use [Unitest](https://hexdocs.pm/unitest/) and native Gleam assertions.
Public zero-argument functions ending in `_test` under `test/` are discovered
automatically. Unitest randomizes execution order; use `--seed` to reproduce it:

```sh
gleam test -- --seed 123
gleam test -- test/frame_test.gleam
gleam test -- --test frame_test.text_encode_client_outbound_fixtures_test
gleam test --target javascript -- --seed 123
```

### Website deployment

The Astro website deploys to Cloudflare Workers as static assets. No Worker
code or server-side adapter is needed.

After this change is merged, connect `tylerbutler/roost` in Cloudflare Workers
and use these build settings:

| Setting | Value |
| --- | --- |
| Worker name | `roost-website` (matches `website/wrangler.jsonc`) |
| Production branch | `main` |
| Root directory | `website` |
| Build command | `pnpm build` |
| Deploy command | `pnpm run deploy` |
| Preview command | `pnpm run deploy:preview` |
| Branch control | Enable Preview Builds |

Preview builds run the same Astro build for non-production branches, then
deploy a Worker Preview without changing production. The Preview name defaults
to the Git branch. Cloudflare's GitHub integration posts Preview URLs on pull
requests. The empty `previews` block is sufficient for this static site, which
has no runtime variables, secrets, or bindings. The deploy scripts pin Wrangler
to a version that supports Worker Previews.

Cloudflare installs dependencies from `website/pnpm-lock.yaml`. The build uses
the reference pages committed under `website/src/pages/reference`; it does not
need Gleam or Erlang. When the API changes, run `just site-reference` locally
and commit the updated pages before deployment.

Keep development tool versions in `mise.toml`, not `.tool-versions`.
Cloudflare detects `.tool-versions` and attempts to install the BEAM tools
before the website build.

To build and deploy locally, run `pnpm install --frozen-lockfile`, `pnpm build`,
and `pnpm run deploy` from `website`. Local deployment requires Cloudflare
authentication. Set the custom domain in Cloudflare, then update `site` in
`website/astro.config.mjs` to the final public URL.

Use `mise exec -- pnpm ...` if you have not activated mise in your shell.

For a local Preview deployment, build the site and run
`pnpm run deploy:preview`. The existing `pnpm preview` command only serves the
Astro build locally; it does not deploy to Cloudflare.

Remove the old Netlify GitHub connection after the Cloudflare site is live.
This repository does not create or connect the Cloudflare site automatically.

## Releases

Use Trellis 1.3.0 from `mise.toml` (`mise install`, then `mise exec -- just ...`).
The workspace contains only the root Gleam package; the website is not a release
package. Add fragments for user-facing changes with `just change`. Trellis
prepares versions and release notes in a `release/pending` PR on pushes to
`main`. It keeps the pending request's version targets and release mode, skips
unchanged release content, and continues committed candidates without promoting
them to stable. Promotion can regenerate the final rollup when it resumes.

To choose a release mode, run **Trellis Release** from the Actions page with
**main** selected:

| `pre` | `version` | Request |
| --- | --- | --- |
| empty | optional target | Prepare stable, or retain the current pending/candidate mode |
| `rc` | optional target, such as `1.0.0` | Start or continue a release candidate cycle |
| `none` | usually empty | Promote the current candidate to stable |

Trellis validates the version input. An explicit target changes that target;
omitted fields retain pending intent. To promote an active candidate, use
`none`, not an empty input.

Review and merge the release PR through normal branch protection. **Auto-tag
release** accepts only merged, same-repository `release/pending` PRs targeting
`main`. It checks out that PR's merge commit and creates immutable `v{version}`
tags and GitHub Releases with the matching changelog notes. RC releases remain
prereleases. Tag pushes run the existing Erlang and JavaScript CI. Preparation
and tagging share a queue and do not cancel active release writes.

If tagging fails, rerun the original merge-event job to retry the same approved
commit, even if `main` has advanced. Manual **Auto-tag release** dispatch is also
available on **main**, but selects its current HEAD. Review that revision first;
use the original job rerun for recovery of an older release. Trellis reconciles
existing tags and releases and rejects conflicting immutable tag objects.

### Release credentials and adoption

A maintainer must install a release GitHub App on this repository and configure
`RELEASE_APP_ID` and `RELEASE_APP_PRIVATE_KEY` repository secrets. Give the App
**Contents: read/write** and **Pull requests: read/write**. Its token allows
generated PRs and tags to trigger CI. Ordinary CI uses read-only repository
permissions and needs no release secrets. No Hex token or publication step is
part of this workflow. Keep required checks and approvals on release PRs;
the workflow does not bypass them.

Roost has no historical releases to migrate. Add release fragments or choose a
target version before the first release; this setup does not create an initial
tag. Trellis 1.3.0 archives candidate fragments under
`.changes/roost/v<prerelease>.toml` and records pending intent in
`.changes/release.toml`. Keep those files in release commits so stable promotion
can collect the candidate notes. Invalid or stale state stops preparation.
