# Product

## Register

brand

## Users

Gleam developers already building Phoenix or WebSocket apps on the BEAM. They
arrive knowing the Phoenix channel wire protocol exists and are evaluating
whether `roost` is the right small dependency for encoding and decoding frames.
Their context is a quick, focused evaluation visit: they want to know what this
library is, what it does, and — just as importantly — what it deliberately does
not do, so they can decide in under a minute whether it fits their stack.

## Product Purpose

`roost` is a pure Gleam package that encodes and decodes the Phoenix channel
wire protocol (`[join_ref, ref, topic, event, payload]`). It is runtime-neutral
and protocol-only: it owns no sockets, channel processes, refs, reconnects, or
heartbeat actors. The landing page exists to let a qualified visitor
self-qualify fast — to clearly communicate the scope (what it does AND what it
intentionally leaves to the caller), make clear that Hex publication waits for
1.0, and route them to Git dependency instructions and source/docs. Success is a
visitor who, within a minute, knows exactly whether roost belongs in their
project and feels confident in the craft behind it.

## Brand Personality

Playful and warm, but precise. The bird-in-a-nest motif (a roost is where birds
rest) is the brand's emotional center — friendly, a little whimsical, inviting —
without ever undercutting technical credibility. Voice is honest and confident
about scope: roost is proud of being small and doing one thing well. Three
words: warm, honest, precise. The interface should feel like a well-made small
tool from someone who cares — approachable, not corporate; crafted, not cute.

## Anti-references

- Generic SaaS-cream landing pages: warm-tinted near-white body backgrounds,
  identical feature-card grids, big-number hero metrics, gradient accents. This
  is the explicit anti-reference.
- Dark terminal/hacker dev-tool cliché used as costume for "technical."
- Editorial-magazine serif/italic affectation; this isn't a magazine.
- Corporate/enterprise stiffness.

## Design Principles

- **Scope is the pitch.** Make "what it does / what it doesn't do" a first-class,
  honest centerpiece — not fine print. The boundary is a feature.
- **Warmth with a backbone.** Lean into the bird/nest motif for personality, but
  never at the expense of clarity or technical trust.
- **Self-qualify in a glance.** Every fold should help the visitor decide
  faster; remove anything that doesn't aid that decision.
- **Show the code.** A real Gleam snippet earns more trust than adjectives.
- **Small, on purpose.** The design should feel as intentionally minimal and
  well-crafted as the library itself.

## Accessibility & Inclusion

Target WCAG 2.1 AA. Body text ≥4.5:1 contrast, large text ≥3:1. Full
`prefers-reduced-motion` support: every animation needs a crossfade or instant
fallback. Keyboard-navigable, semantic markup, visible focus states.
